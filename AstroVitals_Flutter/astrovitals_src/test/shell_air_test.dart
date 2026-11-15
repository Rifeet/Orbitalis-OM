import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astrovitals/app_theme.dart';
import 'package:astrovitals/core/data/app_state.dart';
import 'package:astrovitals/ui/pages/shell.dart';

void main() {
  testWidgets('full shell with air scenario - no exceptions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final st = AppState();
    await tester.pumpWidget(
      AVScope(
        palette: AVPalette.normal,
        child: MaterialApp(
          theme: AVTheme.theme(DisplayMode.normal),
          home: Shell(st: st),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull,
        reason: 'no exception on nominal overview');

    // switch to air scenario (like the demo bar does)
    st.setScen('air');
    await tester.pump(const Duration(milliseconds: 400));
    final ex1 = tester.takeException();
    expect(ex1, isNull, reason: 'no exception after air scenario: $ex1');

    // close the urgent flow through the state
    st.toggleU1();
    await tester.pump(const Duration(milliseconds: 400));
    st.toggleU2();
    await tester.pump(const Duration(milliseconds: 400));
    st.urgentClose();
    await tester.pump(const Duration(milliseconds: 400));
    final ex2 = tester.takeException();
    expect(ex2, isNull, reason: 'no exception after urgent close: $ex2');
    expect(find.text('SpO₂ below safe range'), findsNothing);
  });
}
