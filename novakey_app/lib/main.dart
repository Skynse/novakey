import 'package:flutter/widgets.dart';

import 'hud/studio_windows.dart';
export 'hud/studio_windows.dart' show NovaKeyApp;

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  runWidget(NovaKeyApp(showHud: args.contains('--hud')));
}
