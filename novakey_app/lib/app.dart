import 'package:flutter/material.dart';

import 'theme/palette.dart';
import 'studio/studio_screen.dart';

class NovaKeyApp extends StatelessWidget {
  const NovaKeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NovaKey Studio',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(
          primary: signal,
          secondary: orange,
          surface: panel,
          onSurface: paper,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: paper,
          displayColor: paper,
          fontFamily: 'sans-serif',
        ),
        dividerColor: line,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panelRaised,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: signal),
          ),
        ),
      ),
      home: const StudioScreen(),
    );
  }
}
