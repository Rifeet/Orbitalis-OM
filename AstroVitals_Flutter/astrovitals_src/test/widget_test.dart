import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astrovitals/main.dart';

void main() {
  testWidgets('AstroVitals boots to the sign in gate, then the console', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AstroVitalsApp());
    await tester.pump(const Duration(seconds: 1));

    // entry gate first
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('ASTROVITALS'), findsOneWidget);

    // live validation: invalid email -> error + disabled button
    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.pump();
    expect(find.textContaining('valid email'), findsOneWidget);

    // demo crew fill -> form becomes valid -> sign in opens the shell
    await tester.tap(find.text('Fill the demo crew account'));
    await tester.pump();
    await tester.tap(find.text('Sign in').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Emergency guide'), findsOneWidget);
    expect(find.text('Mission day 47 of 270 · Transit vehicle'), findsOneWidget);

    // let the sign-in toast expire, then unmount so Shell timers are disposed
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
