/// AstroVitals design tokens - ported 1:1 from the team's reference design
/// (AstroVitals_fixed_8.html, :root variables + night / EVA mode overrides).
library;

import 'package:flutter/material.dart';
import 'core/data/app_state.dart';

class AVPalette {
  final Color bg;
  final Color bgGlow;
  final Color panel;
  final Color panelSolid;
  final Color raise;
  final Color line;
  final Color lineSoft;
  final Color fg;
  final Color muted;
  final Color blue;
  final Color blueD;
  final Color holo;

  /// soft surfaces (design "soft redesign" pass: --surf / --surf2)
  final Color surf;
  final Color surf2;

  /// six-tier status colours (body) and their text variants
  final List<Color> tier;
  final List<Color> tierText;

  /// pain scale (yellow / orange / red)
  final Color p1, p1s, p2, p2s, p3, p3s;

  final bool evaTargets;

  const AVPalette({
    required this.bg,
    required this.bgGlow,
    required this.panel,
    required this.panelSolid,
    required this.raise,
    required this.line,
    required this.lineSoft,
    required this.fg,
    required this.muted,
    required this.blue,
    required this.blueD,
    required this.holo,
    required this.surf,
    required this.surf2,
    required this.tier,
    required this.tierText,
    required this.p1,
    required this.p1s,
    required this.p2,
    required this.p2s,
    required this.p3,
    required this.p3s,
    this.evaTargets = false,
  });

  Color tierC(int l) => tier[l.clamp(0, 5)];
  Color tierT(int l) => tierText[l.clamp(0, 5)];

  /// color-mix equivalent: [c] at [pct] over transparent-ish base
  Color mix(Color base, Color c, double pct) => Color.lerp(base, c, pct)!;

  Color tierFill(int l, double pct) => mixColors(tierC(l), pct);
  Color mixColors(Color c, double pct) => c.withValues(alpha: pct);

  static const AVPalette normal = AVPalette(
    bg: Color(0xFF060F19),
    bgGlow: Color(0xFF11283F),
    panel: Color(0xB90E2032),
    panelSolid: Color(0xFF0D1F32),
    raise: Color(0xFF15304B),
    line: Color(0x426EB4EB),
    lineSoft: Color(0x1FA0C8EB),
    fg: Color(0xFFE8F0F6),
    muted: Color(0xFFA3BBD0),
    blue: Color(0xFF5AAEE8),
    blueD: Color(0xFF2F78B0),
    holo: Color(0xFF8CC6EE),
    surf: Color(0x0BFFFFFF),
    surf2: Color(0x14FFFFFF),
    tier: [
      Color(0xFF2E7D32), // 0 Normal
      Color(0xFF8BC34A), // 1 Monitor
      Color(0xFFFFA000), // 2 Advisory
      Color(0xFFFB8C00), // 3 Action soon
      Color(0xFFC62828), // 4 Act now
      Color(0xFF7F0000), // 5 Emergency
    ],
    tierText: [
      Color(0xFF74D67C),
      Color(0xFFB6E47C),
      Color(0xFFFFC34F),
      Color(0xFFFFA953),
      Color(0xFFFF918A),
      Color(0xFFFF918A),
    ],
    p1: Color(0xFFF4D03F), p1s: Color(0xFFFFF3B0),
    p2: Color(0xFFF07F13), p2s: Color(0xFFFFC48A),
    p3: Color(0xFFD62828), p3s: Color(0xFFFF9A9A),
  );

  /// night: final warm palette from the design's "round 2 fixes" pass
  static const AVPalette night = AVPalette(
    bg: Color(0xFF070504),
    bgGlow: Color(0xFF140D08),
    panel: Color(0xCC18100B),
    panelSolid: Color(0xFF161009),
    raise: Color(0xFF211710),
    line: Color(0x38C89664),
    lineSoft: Color(0x1FC89664),
    fg: Color(0xFFC9B49B),
    muted: Color(0xFF94806B),
    blue: Color(0xFFB07A48),
    blueD: Color(0xFF2F78B0),
    holo: Color(0xFF8F6A4A),
    surf: Color(0x09FFDCB4),
    surf2: Color(0x12FFDCB4),
    tier: [
      Color(0xFF2E7D32), Color(0xFF8BC34A), Color(0xFFFFA000),
      Color(0xFFFB8C00), Color(0xFF7A2A22), Color(0xFF7F0000),
    ],
    tierText: [
      Color(0xFF6AA86F), Color(0xFF98B86E), Color(0xFFC9A14E),
      Color(0xFFC98A4E), Color(0xFFFF918A), Color(0xFFFF918A),
    ],
    p1: Color(0xFFF4D03F), p1s: Color(0xFFFFF3B0),
    p2: Color(0xFFF07F13), p2s: Color(0xFFFFC48A),
    p3: Color(0xFFD62828), p3s: Color(0xFFFF9A9A),
  );

  static const AVPalette eva = AVPalette(
    bg: Color(0xFF02060B),
    bgGlow: Color(0xFF0B1D2E),
    panel: Color(0xC7091623),
    panelSolid: Color(0xFF0D1F32),
    raise: Color(0xFF15304B),
    line: Color(0x427CC4F5),
    lineSoft: Color(0x1FA0C8EB),
    fg: Color(0xFFFFFFFF),
    muted: Color(0xFFC7D3DD),
    blue: Color(0xFF7CC4F5),
    blueD: Color(0xFF2F78B0),
    holo: Color(0xFF7CC4F5),
    surf: Color(0x0BFFFFFF),
    surf2: Color(0x14FFFFFF),
    tier: [
      Color(0xFF2E7D32), Color(0xFF8BC34A), Color(0xFFFFA000),
      Color(0xFFFB8C00), Color(0xFFC62828), Color(0xFF7F0000),
    ],
    tierText: [
      Color(0xFF8EF096), Color(0xFFC9F08F), Color(0xFFFFD27A),
      Color(0xFFFFB870), Color(0xFFFFA59E), Color(0xFFFFA59E),
    ],
    p1: Color(0xFFF4D03F), p1s: Color(0xFFFFF3B0),
    p2: Color(0xFFF07F13), p2s: Color(0xFFFFC48A),
    p3: Color(0xFFD62828), p3s: Color(0xFFFF9A9A),
    evaTargets: true,
  );

  static AVPalette of(DisplayMode mode) {
    switch (mode) {
      case DisplayMode.night: return night;
      case DisplayMode.eva: return eva;
      case DisplayMode.normal: return normal;
    }
  }
}

class AVText {
  /// 'Chakra Petch' - display font for numbers, headers, buttons
  static const String display = 'ChakraPetch';
  /// 'IBM Plex Sans' - body font
  static const String body = 'IBMPlexSans';

  static TextStyle displayStyle(
    double size, {
    FontWeight w = FontWeight.w500,
    Color? color,
    double ls = 0,
    double? height,
  }) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: w,
        color: color,
        letterSpacing: ls,
        height: height,
        // canvaskit can inherit a stray decoration from the ambient style
        decoration: TextDecoration.none,
      );

  static TextStyle bodyStyle(double size,
      {FontWeight w = FontWeight.w400, Color? color, double? height}) =>
      TextStyle(
        fontFamily: body,
        fontSize: size,
        fontWeight: w,
        color: color,
        height: height ?? 1.6,
        decoration: TextDecoration.none,
      );

  /// tabular numbers for readouts
  static TextStyle num(double size,
      {FontWeight w = FontWeight.w600, Color? color, double? height}) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: w,
        color: color,
        height: height ?? 1.1,
        decoration: TextDecoration.none,
      );
}

class AVTheme {
  static ThemeData theme(DisplayMode mode) {
    final p = AVPalette.of(mode);
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: p.bg,
      colorScheme: ColorScheme.dark(
        primary: p.blue,
        secondary: p.holo,
        surface: p.panelSolid,
        error: p.tierText[4],
      ),
      fontFamily: AVText.body,
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: base.textTheme.copyWith(
        bodyMedium: AVText.bodyStyle(15, color: p.fg),
        bodySmall: AVText.bodyStyle(13, color: p.muted),
      ),
      dividerTheme: DividerThemeData(color: p.lineSoft, thickness: 1),
    );
  }
}

/// Palette lookup helper
AVPalette avp(BuildContext c) =>
    c.dependOnInheritedWidgetOfExactType<_AVPaletteMarker>()!.palette;

class _AVPaletteMarker extends InheritedWidget {
  final AVPalette palette;
  const _AVPaletteMarker({required this.palette, required super.child});
  @override
  bool updateShouldNotify(_AVPaletteMarker oldWidget) =>
      oldWidget.palette != palette;
}

/// Wrap content so custom painters/widgets can reach the palette without ThemeExtension lookups.
class AVScope extends StatelessWidget {
  final AVPalette palette;
  final Widget child;
  const AVScope({super.key, required this.palette, required this.child});

  @override
  Widget build(BuildContext context) =>
      _AVPaletteMarker(palette: palette, child: child);
}

/// store scope: subscribe to AppState changes without extra packages
class AVStore extends InheritedNotifier<AppState> {
  const AVStore({super.key, required AppState state, required super.child})
      : super(notifier: state);
  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AVStore>()!.notifier!;
}
