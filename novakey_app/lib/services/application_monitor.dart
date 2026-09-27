import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class FocusedApplication {
  const FocusedApplication(
    this.desktopFile,
    this.resourceClass,
    this.resourceName,
  );
  final String desktopFile, resourceClass, resourceName;
  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .split('/')
      .last
      .replaceFirst(RegExp(r'\.desktop$'), '');
  String get id => desktopFile.isNotEmpty
      ? normalize(desktopFile)
      : normalize(resourceClass);
  bool matches(String link) {
    final candidate = normalize(link);
    return candidate.isNotEmpty &&
        [
          desktopFile,
          resourceClass,
          resourceName,
        ].map(normalize).contains(candidate);
  }
}

/// A session-scoped Plasma 6 KWin script reports focus over native D-Bus.
class ApplicationMonitor {
  static const _channel = MethodChannel('novakey/kwin');
  static bool get supported =>
      Platform.isLinux &&
      (Platform.environment['XDG_CURRENT_DESKTOP'] ?? '')
          .split(':')
          .any((v) => v.toUpperCase() == 'KDE');
  bool _active = false;
  Future<void> start(void Function(FocusedApplication) onApplication) async {
    if (!supported) {
      throw StateError(
        'KDE Plasma is required for automatic profile switching.',
      );
    }
    _active = true;
    _channel.setMethodCallHandler((call) async {
      if (!_active || call.method != 'activeApplication') return;
      final data = Map<String, dynamic>.from(call.arguments as Map);
      onApplication(
        FocusedApplication(
          data['desktopFile'] as String? ?? '',
          data['resourceClass'] as String? ?? '',
          data['resourceName'] as String? ?? '',
        ),
      );
    });
    try {
      await _channel.invokeMethod<void>(
        'start',
        await rootBundle.loadString('assets/kwin_focus.js'),
      );
    } catch (_) {
      _active = false;
      _channel.setMethodCallHandler(null);
      rethrow;
    }
  }

  Future<void> stop() async {
    _active = false;
    _channel.setMethodCallHandler(null);
    if (supported) await _channel.invokeMethod<void>('stop');
  }
}
