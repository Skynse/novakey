import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'studio/studio_screen.dart';
import 'theme/novakey_theme.dart';

class NovaKeyApp extends StatelessWidget {
  const NovaKeyApp({super.key});

  @override
  Widget build(BuildContext context) => ShadApp(
    debugShowCheckedModeBanner: false,
    title: 'NovaKey Studio',
    themeMode: ThemeMode.dark,
    darkTheme: novaKeyTheme(),
    home: Theme(data: novaKeyMaterialTheme(), child: const StudioScreen()),
  );
}

void main() {
  runApp(NovaKeyApp());
}
