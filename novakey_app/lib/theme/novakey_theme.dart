import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'palette.dart';

ShadThemeData novaKeyTheme() => ShadThemeData(
  brightness: Brightness.dark,
  colorScheme: const ShadZincColorScheme.dark(),
  radius: const BorderRadius.all(Radius.circular(7)),
  textTheme: ShadTextTheme(family: 'sans-serif'),
);

ThemeData novaKeyMaterialTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ink,
  colorScheme: const ColorScheme.dark(
    primary: signal,
    secondary: signal,
    surface: panel,
    onSurface: paper,
    outline: line,
    outlineVariant: line,
  ),
  textTheme: ThemeData.dark().textTheme.apply(
    bodyColor: paper,
    displayColor: paper,
    fontFamily: 'sans-serif',
  ),
  dividerColor: line,
  dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
);
