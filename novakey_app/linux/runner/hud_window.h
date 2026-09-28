#pragma once
#include <flutter_linux/flutter_linux.h>
struct NovaKeyHudWindow;
NovaKeyHudWindow* novakey_hud_window_new(FlEngine* engine);
void novakey_hud_window_free(NovaKeyHudWindow* hud);
