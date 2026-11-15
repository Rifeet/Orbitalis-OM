import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'core/data/app_state.dart';
import 'ui/auth/auth_pages.dart';
import 'ui/pages/shell.dart';

void main() {
  runApp(const AstroVitalsApp());
}

class AstroVitalsApp extends StatelessWidget {
  const AstroVitalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState();
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return AVScope(
          palette: AVPalette.of(state.mode),
          child: AVStore(
            state: state,
            child: MaterialApp(
            title: 'AstroVitals',
            debugShowCheckedModeBanner: false,
            theme: AVTheme.theme(state.mode),
            builder: (context, child) {
              // EVA: bigger type + targets (design: body[data-mode=eva])
              if (state.mode == DisplayMode.eva) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.15),
                  ),
                  child: child!,
                );
              }
              return child!;
            },
            // entry gate: sign in / sign up before the console (sign out
            // lives in the profile dialog)
            home: state.signedIn
                ? Shell(st: state)
                : AuthGate(st: state),
            ),
          ),
        );
      },
    );
  }
}
