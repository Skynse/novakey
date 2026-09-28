#include "hud_window.h"
#include <gio/gio.h>
#include <glib/gstdio.h>
#include <cstring>
#include <unistd.h>

struct NovaKeyHudWindow {
  FlEngine* engine;
  FlMethodChannel* channel = nullptr;
  GtkWidget* window = nullptr;
  FlView* view = nullptr;
  bool visible = false;
  bool rendered = false;
  GDBusConnection* bus = nullptr;
  gchar* script_path = nullptr;
  gchar* plugin = nullptr;
};

static GVariant* kwin_call(NovaKeyHudWindow* h, const char* path,
    const char* iface, const char* method, GVariant* args, GError** error) {
  return g_dbus_connection_call_sync(h->bus, "org.kde.KWin", path, iface,
      method, args, nullptr, G_DBUS_CALL_FLAGS_NONE, 2000, nullptr, error);
}

static bool setup_kwin(NovaKeyHudWindow* h, const char* source, GError** error) {
  h->bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, error);
  if (!h->bus) return false;
  h->plugin = g_strdup_printf("novakey-hud-%d", getpid());
  h->script_path = g_strdup_printf("%s/novakey-hud-%d.js", g_get_user_runtime_dir(), getpid());
  if (!g_file_set_contents(h->script_path, source, -1, error)) return false;
  g_autoptr(GVariant) loaded = kwin_call(h, "/Scripting", "org.kde.kwin.Scripting",
      "loadScript", g_variant_new("(ss)", h->script_path, h->plugin), error);
  if (!loaded) return false;
  gint32 id;
  g_variant_get(loaded, "(i)", &id);
  if (id < 0) {
    g_set_error_literal(error, G_IO_ERROR, G_IO_ERROR_FAILED, "Could not load HUD placement script.");
    return false;
  }
  g_autofree gchar* path = g_strdup_printf("/Scripting/Script%d", id);
  g_autoptr(GVariant) started = kwin_call(h, path, "org.kde.kwin.Script", "run", nullptr, error);
  return started != nullptr;
}

static void cleanup_kwin(NovaKeyHudWindow* h) {
  if (h->bus && h->plugin) {
    g_autoptr(GVariant) result = kwin_call(h, "/Scripting", "org.kde.kwin.Scripting",
        "unloadScript", g_variant_new("(s)", h->plugin), nullptr);
  }
  if (h->script_path) g_unlink(h->script_path);
  g_clear_pointer(&h->script_path, g_free);
  g_clear_pointer(&h->plugin, g_free);
  g_clear_object(&h->bus);
}

static void first_frame(FlView*, gpointer data) {
  auto* h = static_cast<NovaKeyHudWindow*>(data);
  h->rendered = true;
  if (h->visible) gtk_widget_show(h->window);
}

static void method_call(FlMethodChannel*, FlMethodCall* call, gpointer data) {
  auto* h = static_cast<NovaKeyHudWindow*>(data);
  const char* name = fl_method_call_get_name(call);
  if (strcmp(name, "create") == 0) {
    if (!h->window) {
      FlValue* args = fl_method_call_get_args(call);
      if (fl_value_get_type(args) != FL_VALUE_TYPE_STRING) {
        fl_method_call_respond_error(call, "arguments", "Missing HUD placement script", nullptr, nullptr);
        return;
      }
      g_autoptr(GError) error = nullptr;
      if (!setup_kwin(h, fl_value_get_string(args), &error)) {
        cleanup_kwin(h);
        fl_method_call_respond_error(call, "kwin", error ? error->message : "KDE HUD setup failed", nullptr, nullptr);
        return;
      }
      h->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
      auto* window = GTK_WINDOW(h->window);
      g_autofree gchar* title = g_strdup_printf("NovaKey Bindings HUD %d", getpid());
      gtk_window_set_title(window, title);
      gtk_window_set_decorated(window, FALSE);
      gtk_window_set_resizable(window, FALSE);
      gtk_window_set_default_size(window, 880, 680);
      gtk_window_set_accept_focus(window, FALSE);
      gtk_window_set_focus_on_map(window, FALSE);
      gtk_window_set_skip_taskbar_hint(window, TRUE);
      gtk_window_set_skip_pager_hint(window, TRUE);
      gtk_window_set_keep_above(window, TRUE);
      GdkVisual* visual = gdk_screen_get_rgba_visual(gtk_widget_get_screen(h->window));
      if (visual) gtk_widget_set_visual(h->window, visual);
      gtk_widget_set_app_paintable(h->window, TRUE);
      // Native Flutter multi-view: shares the main engine and Dart isolate.
      h->view = fl_view_new_for_engine(h->engine);
      const GdkRGBA transparent = {0, 0, 0, 0};
      fl_view_set_background_color(h->view, &transparent);
      gtk_container_add(GTK_CONTAINER(h->window), GTK_WIDGET(h->view));
      g_signal_connect(h->view, "first-frame", G_CALLBACK(first_frame), h);
      gtk_widget_show(GTK_WIDGET(h->view));
      gtk_widget_realize(h->window);
      gtk_widget_realize(GTK_WIDGET(h->view));
    }
    g_autoptr(FlValue) id = fl_value_new_int(fl_view_get_id(h->view));
    fl_method_call_respond_success(call, id, nullptr);
  } else if (strcmp(name, "visible") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    h->visible = fl_value_get_type(args) == FL_VALUE_TYPE_BOOL && fl_value_get_bool(args);
    if (h->window) {
      if (h->visible && h->rendered) gtk_widget_show(h->window);
      else gtk_widget_hide(h->window);
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

NovaKeyHudWindow* novakey_hud_window_new(FlEngine* engine) {
  auto* h = new NovaKeyHudWindow();
  h->engine = engine;
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  h->channel = fl_method_channel_new(fl_engine_get_binary_messenger(engine),
      "novakey/hud", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(h->channel, method_call, h, nullptr);
  return h;
}

void novakey_hud_window_free(NovaKeyHudWindow* h) {
  if (!h) return;
  fl_method_channel_set_method_call_handler(h->channel, nullptr, nullptr, nullptr);
  if (h->window) gtk_widget_destroy(h->window);
  cleanup_kwin(h);
  g_clear_object(&h->channel);
  delete h;
}
