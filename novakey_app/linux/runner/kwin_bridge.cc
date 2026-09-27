#include "kwin_bridge.h"
#include <gio/gio.h>
#include <glib/gstdio.h>
#include <cstring>

namespace {
constexpr auto kService = "org.novakey.Studio.Focus";
constexpr auto kPath = "/org/novakey/Studio/Focus";
constexpr auto kPlugin = "novakey-studio-focus";
constexpr auto kXml = R"(<node><interface name="org.novakey.Studio.Focus">
<method name="ActiveApplication"><arg type="s" direction="in" name="desktopFile"/>
<arg type="s" direction="in" name="resourceClass"/>
<arg type="s" direction="in" name="resourceName"/></method>
</interface></node>)";
}
struct NovaKeyKWinBridge {
  FlMethodChannel* channel = nullptr;
  GDBusConnection* bus = nullptr;
  GDBusNodeInfo* info = nullptr;
  guint registration = 0;
  bool owns_name = false;
  bool loaded = false;
  gchar* script_path = nullptr;
  gchar* kwin_owner = nullptr;
};
static GVariant* call(NovaKeyKWinBridge* b, const char* service,
                     const char* path, const char* interface,
                     const char* method, GVariant* args, GError** error) {
  return g_dbus_connection_call_sync(b->bus, service, path, interface, method,
      args, nullptr, G_DBUS_CALL_FLAGS_NONE, 2000, nullptr, error);
}
static void stop(NovaKeyKWinBridge* b) {
  if (b->bus && b->loaded) {
    g_autoptr(GVariant) result = call(b, "org.kde.KWin", "/Scripting",
        "org.kde.kwin.Scripting", "unloadScript", g_variant_new("(s)", kPlugin), nullptr);
  }
  b->loaded = false;
  if (b->bus && b->registration) g_dbus_connection_unregister_object(b->bus, b->registration);
  b->registration = 0;
  if (b->bus && b->owns_name) {
    g_autoptr(GVariant) result = call(b, "org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus", "ReleaseName", g_variant_new("(s)", kService), nullptr);
  }
  b->owns_name = false;
  if (b->script_path) { g_unlink(b->script_path); g_clear_pointer(&b->script_path, g_free); }
  g_clear_pointer(&b->kwin_owner, g_free);
  g_clear_pointer(&b->info, g_dbus_node_info_unref);
  g_clear_object(&b->bus);
}
static void active_application(GDBusConnection*, const gchar* sender, const gchar*,
    const gchar*, const gchar*, GVariant* parameters,
    GDBusMethodInvocation* invocation, gpointer data) {
  auto* b = static_cast<NovaKeyKWinBridge*>(data);
  if (g_strcmp0(sender, b->kwin_owner) != 0) {
    g_dbus_method_invocation_return_dbus_error(invocation,
        "org.novakey.Studio.Focus.InvalidSender", "Only KWin may publish focus events.");
    return;
  }
  const gchar *desktop, *resource_class, *resource_name;
  g_variant_get(parameters, "(&s&s&s)", &desktop, &resource_class, &resource_name);
  g_autoptr(FlValue) value = fl_value_new_map();
  fl_value_set_string_take(value, "desktopFile", fl_value_new_string(desktop));
  fl_value_set_string_take(value, "resourceClass", fl_value_new_string(resource_class));
  fl_value_set_string_take(value, "resourceName", fl_value_new_string(resource_name));
  fl_method_channel_invoke_method(b->channel, "activeApplication", value, nullptr, nullptr, nullptr);
  g_dbus_method_invocation_return_value(invocation, nullptr);
}
static const GDBusInterfaceVTable vtable = {active_application, nullptr, nullptr, {nullptr}};
static bool start(NovaKeyKWinBridge* b, const char* source, GError** error) {
  stop(b);
  b->bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, error);
  if (!b->bus) return false;
  g_autoptr(GVariant) owner = call(b, "org.freedesktop.DBus", "/org/freedesktop/DBus",
      "org.freedesktop.DBus", "GetNameOwner", g_variant_new("(s)", "org.kde.KWin"), error);
  if (!owner) return false;
  const gchar* unique_name;
  g_variant_get(owner, "(&s)", &unique_name);
  b->kwin_owner = g_strdup(unique_name);
  g_autoptr(GVariant) claim = call(b, "org.freedesktop.DBus", "/org/freedesktop/DBus",
      "org.freedesktop.DBus", "RequestName", g_variant_new("(su)", kService, 4u), error);
  if (!claim) return false;
  guint32 result;
  g_variant_get(claim, "(u)", &result);
  if (result != 1 && result != 4) {
    g_set_error_literal(error, G_IO_ERROR, G_IO_ERROR_EXISTS, "Another NovaKey Studio instance owns KDE focus integration.");
    return false;
  }
  b->owns_name = true;
  b->info = g_dbus_node_info_new_for_xml(kXml, error);
  if (!b->info) return false;
  b->registration = g_dbus_connection_register_object(b->bus, kPath, b->info->interfaces[0], &vtable, b, nullptr, error);
  if (!b->registration) return false;
  // Clear our own stale script after an app crash; no other KWin settings change.
  g_autoptr(GVariant) unloaded = call(b, "org.kde.KWin", "/Scripting",
      "org.kde.kwin.Scripting", "unloadScript", g_variant_new("(s)", kPlugin), nullptr);
  b->script_path = g_build_filename(g_get_user_runtime_dir(), "novakey-focus.js", nullptr);
  if (!g_file_set_contents(b->script_path, source, -1, error)) return false;
  g_autoptr(GVariant) loaded = call(b, "org.kde.KWin", "/Scripting",
      "org.kde.kwin.Scripting", "loadScript", g_variant_new("(ss)", b->script_path, kPlugin), error);
  if (!loaded) return false;
  gint32 id;
  g_variant_get(loaded, "(i)", &id);
  if (id < 0) {
    g_set_error_literal(error, G_IO_ERROR, G_IO_ERROR_FAILED, "KWin could not load the NovaKey focus script.");
    return false;
  }
  b->loaded = true;
  g_autofree gchar* path = g_strdup_printf("/Scripting/Script%d", id);
  g_autoptr(GVariant) started = call(b, "org.kde.KWin", path,
      "org.kde.kwin.Script", "run", nullptr, error);
  return started != nullptr;
}
static void method_call(FlMethodChannel*, FlMethodCall* method, gpointer data) {
  auto* b = static_cast<NovaKeyKWinBridge*>(data);
  const auto* name = fl_method_call_get_name(method);
  if (strcmp(name, "stop") == 0) {
    stop(b);
    fl_method_call_respond_success(method, nullptr, nullptr);
  } else if (strcmp(name, "start") == 0) {
    FlValue* args = fl_method_call_get_args(method);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_STRING) {
      fl_method_call_respond_error(method, "arguments", "Missing KWin script.", nullptr, nullptr);
      return;
    }
    g_autoptr(GError) error = nullptr;
    if (!start(b, fl_value_get_string(args), &error)) {
      stop(b);
      fl_method_call_respond_error(method, "kwin", error ? error->message : "KWin integration failed.", nullptr, nullptr);
    } else {
      fl_method_call_respond_success(method, nullptr, nullptr);
    }
  } else { fl_method_call_respond_not_implemented(method, nullptr); }
}
NovaKeyKWinBridge* novakey_kwin_bridge_new(FlBinaryMessenger* messenger) {
  auto* b = new NovaKeyKWinBridge();
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  b->channel = fl_method_channel_new(messenger, "novakey/kwin", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(b->channel, method_call, b, nullptr);
  return b;
}
void novakey_kwin_bridge_free(NovaKeyKWinBridge* b) {
  if (!b) return;
  stop(b);
  fl_method_channel_set_method_call_handler(b->channel, nullptr, nullptr, nullptr);
  g_clear_object(&b->channel);
  delete b;
}
