#pragma once
#include <flutter_linux/flutter_linux.h>
struct NovaKeyKWinBridge;
NovaKeyKWinBridge* novakey_kwin_bridge_new(FlBinaryMessenger* messenger);
void novakey_kwin_bridge_free(NovaKeyKWinBridge* bridge);
