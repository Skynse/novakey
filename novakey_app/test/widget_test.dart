import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novakey_app/main.dart';

void main() {
  testWidgets('shows the NovaKey configuration studio', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const NovaKeyApp());

    expect(find.text('NOVAKEY'), findsOneWidget);
    expect(find.text('Illustration'), findsWidgets);
    expect(find.text('Key 01'), findsOneWidget);
    expect(find.text('Undo'), findsWidgets);
  });
}
