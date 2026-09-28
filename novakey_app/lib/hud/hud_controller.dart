import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HudController extends ChangeNotifier {
  HudController({required this.onError});
  final void Function(String) onError;
  static const _channel = MethodChannel('novakey/hud');
  int? viewId;
  bool _pinned = false, _disposed = false;
  int _peeks = 0;
  Future<void> _updates = Future.value();
  bool get visible => _pinned || _peeks > 0;

  void toggle() {
    _pinned = !_pinned;
    _update();
  }

  void action(String behavior, bool down) {
    if (behavior == 'peek') {
      _peeks = (_peeks + (down ? 1 : -1)).clamp(0, 100);
      _update();
    } else if (down) {
      toggle();
    }
  }

  void releasePeeks() {
    _peeks = 0;
    _update();
  }

  void hide() {
    _peeks = 0;
    _pinned = false;
    _update();
  }

  void _update() {
    if (_disposed) return;
    notifyListeners();
    _updates = _updates
        .then((_) async {
          if (_disposed) return;
          if (visible && viewId == null) {
            if (!Platform.isLinux) {
              throw UnsupportedError(
                'The HUD currently requires KDE on Linux.',
              );
            }
            final script = (await rootBundle.loadString('assets/kwin_hud.js'))
                .replaceAll('@PID@', '$pid');
            viewId = await _channel.invokeMethod<int>('create', script);
            if (_disposed) return;
            notifyListeners();
          }
          if (viewId != null) {
            await _channel.invokeMethod<void>('visible', visible && !_disposed);
          }
        })
        .catchError((Object error) {
          if (_disposed) return;
          _pinned = false;
          _peeks = 0;
          notifyListeners();
          onError('Bindings HUD: $error');
        });
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(
      _channel.invokeMethod<void>('visible', false).catchError((Object _) {}),
    );
    super.dispose();
  }
}
