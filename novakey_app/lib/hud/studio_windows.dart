import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../services/studio_controller.dart';
import '../studio/studio_screen.dart';
import '../theme/novakey_theme.dart';
import 'bindings_hud.dart';

/// Both native windows share this engine, controller and live profile state.
class NovaKeyApp extends StatefulWidget {
  const NovaKeyApp({super.key, this.showHud = false});
  final bool showHud;
  @override
  State<NovaKeyApp> createState() => _NovaKeyAppState();
}

class _NovaKeyAppState extends State<NovaKeyApp> with WidgetsBindingObserver {
  final controller = StudioController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.hud.addListener(_changed);
    unawaited(
      controller.initialize().then((_) {
        if (mounted && widget.showHud) controller.hud.toggle();
      }),
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() => _changed();
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.hud.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    return ViewCollection(
      views: [
        for (final view in dispatcher.views)
          if (view == dispatcher.implicitView)
            View(
              key: ValueKey(view.viewId),
              view: view,
              child: ShadApp(
                debugShowCheckedModeBanner: false,
                title: 'NovaKey Studio',
                themeMode: ThemeMode.dark,
                darkTheme: novaKeyTheme(),
                home: Theme(
                  data: novaKeyMaterialTheme(),
                  child: StudioScreen(controller: controller),
                ),
              ),
            )
          else if (view.viewId == controller.hud.viewId)
            View(
              key: ValueKey(view.viewId),
              view: view,
              child: BindingsHud(controller: controller),
            ),
      ],
    );
  }
}
