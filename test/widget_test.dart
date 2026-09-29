import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adb_studio/main.dart';

void main() {
  testWidgets('ADB Studio App smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const AdbStudioApp());
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('ADB Studio'), findsWidgets);
  });
}
