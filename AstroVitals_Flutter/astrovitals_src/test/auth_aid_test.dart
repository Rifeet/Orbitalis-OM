import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astrovitals/app_theme.dart';
import 'package:astrovitals/core/data/app_state.dart';
import 'package:astrovitals/ui/pages/emergency_page.dart';
import 'package:astrovitals/ui/auth/auth_pages.dart';

void main() {
  Future<void> pumpAid(WidgetTester tester, AppState st) async {
    tester.view.physicalSize = const Size(1440, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AVScope(
        palette: AVPalette.normal,
        child: MaterialApp(
          theme: AVTheme.theme(DisplayMode.normal),
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: EmergencyPage(st: st),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('sign up form: live validation + account creation signs in', (tester) async {
    final st = AppState();
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AVScope(
        palette: AVPalette.normal,
        child: MaterialApp(
          theme: AVTheme.theme(DisplayMode.normal),
          home: AuthGate(st: st),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('New crew member? Create an account'));
    await tester.pump();
    expect(find.text('Sign up'), findsNWidgets(2)); // form title + submit button

    // invalid email warns per keystroke
    await tester.enterText(find.byType(TextField).at(2), 'bad@@mail');
    await tester.pump();
    expect(find.textContaining('valid email'), findsOneWidget);

    // mismatched confirm warns
    await tester.enterText(find.byType(TextField).at(0), 'Rashed Al Ameri');
    await tester.enterText(find.byType(TextField).at(2), 'rashed@astrovitals.demo');
    await tester.enterText(find.byType(TextField).at(3), 'passw0rd1');
    await tester.enterText(find.byType(TextField).at(4), 'passw0rd2');
    await tester.pump();
    expect(find.textContaining('do not match'), findsOneWidget);

    // fix confirm -> Sign up enabled -> gate opens the shell (name applied)
    await tester.enterText(find.byType(TextField).at(4), 'passw0rd1');
    await tester.pump();
    await tester.tap(find.text('Sign up').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(st.signedIn, isTrue, reason: 'sign up should open the session');
    expect(st.profileName, 'Rashed Al Ameri');

    // let the welcome toast expire so no timer is left pending
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('emergency page: docx steps with illustrations, no extra sections', (tester) async {
    final st = AppState();
    st.welcomed = true;
    await pumpAid(tester, st);

    // the two prototype panels only: guide + procedure
    expect(find.text('First aid guide'), findsOneWidget);
    expect(find.text('Fainting'), findsWidgets); // pill + section title
    expect(find.text('Someone collapses or feels about to'), findsOneWidget);
    expect(find.text('Keep them from falling.'), findsOneWidget);

    // removed sections stay removed
    expect(find.textContaining('Spaceflight adaptations'), findsNothing);
    expect(find.text('References'), findsNothing);
    expect(find.textContaining('Verified against official guidelines'), findsNothing);
    expect(find.textContaining('Space-adapted step'), findsNothing);
    expect(find.textContaining('Sources:'), findsNothing);

    // illustrations are present (20 docx assets across 4 procedures)
    expect(find.byType(Image), findsWidgets);

    // switching to a design procedure keeps the same layout
    st.setAid('storm');
    await tester.pumpWidget(
      AVScope(
        palette: AVPalette.normal,
        child: MaterialApp(
          theme: AVTheme.theme(DisplayMode.normal),
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: EmergencyPage(st: st),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Solar storm alert'), findsWidgets);
    expect(find.text('Stop work'), findsOneWidget);
  });
}
