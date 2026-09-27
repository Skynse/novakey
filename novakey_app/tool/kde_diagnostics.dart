// Manual KDE integration diagnostic. No device or saved profiles are touched.
// flutter run -d linux -t tool/kde_diagnostics.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:novakey_app/services/application_monitor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'NovaKey KDE integration check\nCloses automatically after receiving a KWin event.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
  final monitor = ApplicationMonitor();
  final event = Completer<FocusedApplication>();
  try {
    await monitor.start((app) {
      debugPrint(
        'KWIN_EVENT desktop=${app.desktopFile} class=${app.resourceClass}',
      );
      if (!event.isCompleted) event.complete(app);
    });
    await event.future.timeout(const Duration(seconds: 8));
    await monitor.stop();
    debugPrint(
      'KWIN_BRIDGE_OK: received a real focus event and unloaded the script.',
    );
    exit(0);
  } catch (e) {
    debugPrint('KWIN_BRIDGE_ERROR: $e');
    try {
      await monitor.stop();
    } catch (_) {}
    exit(1);
  }
}
