/// Small painters: sleep clock (sleepClockSVG), pain figure (painSVG with the
/// FRONT/BACK regions), mood faces (faceSVG) and the medication list clock.
library;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../core/contract/fields.dart';

int _toMin(String t) {
  final p = t.split(':');
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

/// planned window vs actual sleep on a 24h strip
class SleepClock extends StatelessWidget {
  final String planBed, planUp, bed, up;
  const SleepClock({
    super.key,
    required this.planBed,
    required this.planUp,
    required this.bed,
    required this.up,
  });

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return LayoutBuilder(
      builder: (context, box) {
        final W = box.maxWidth;
        const H = 62.0;
        double x(double m) => m / 1440 * W;
        return SizedBox(
          width: W,
          height: H,
          child: CustomPaint(
            painter: _SleepClockPainter(
              plan: _segs(_toMin(planBed), _toMin(planUp)),
              actual: _segs(_toMin(bed), _toMin(up)),
              x: x,
              W: W,
              palette: p,
            ),
          ),
        );
      },
    );
  }

  static List<(double, double)> _segs(int a, int b) {
    a = ((a % 1440) + 1440) % 1440;
    b = ((b % 1440) + 1440) % 1440;
    if (b >= a) return [(a.toDouble(), b.toDouble())];
    return [(a.toDouble(), 1440), (0, b.toDouble())];
  }
}

class _SleepClockPainter extends CustomPainter {
  final List<(double, double)> plan, actual;
  final double Function(double) x;
  final double W;
  final AVPalette palette;
  _SleepClockPainter({
    required this.plan,
    required this.actual,
    required this.x,
    required this.W,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final trackRect = Rect.fromLTWH(0, 22, W, 18);
    canvas.drawRect(
      trackRect,
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
    for (final (a, b) in plan) {
      final r = Rect.fromLTWH(x(a), 22, mathMax(2, x(b) - x(a)), 18);
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..color = p.holo
        ..strokeWidth = 1.5;
      _dashedRect(canvas, r, dash);
    }
    for (final (a, b) in actual) {
      canvas.drawRect(
        Rect.fromLTWH(x(a), 22, mathMax(2, x(b) - x(a)), 18),
        Paint()..color = p.blue.withValues(alpha: 0.85),
      );
    }
    for (final h in [0, 6, 12, 18, 24]) {
      _text(
        canvas,
        '${h.toString().padLeft(2, '0')}:00',
        x(h * 60.0),
        56,
        10,
        p.muted,
        align: h == 0
            ? TextAlign.left
            : h == 24
            ? TextAlign.right
            : TextAlign.center,
      );
    }
    _text(canvas, 'Dashed: planned', 0, 14, 10, p.holo);
    _text(
      canvas,
      'Solid: your sleep',
      W,
      14,
      10,
      p.blue,
      align: TextAlign.right,
    );
  }

  void _dashedRect(Canvas canvas, Rect r, Paint dash) {
    final path = Path()..addRect(r);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, mathMin(d + 4, m.length)), dash);
        d += 7;
      }
    }
  }

  void _text(
    Canvas canvas,
    String s,
    double px,
    double py,
    double size,
    Color color, {
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: AVText.displayStyle(size, color: color),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    Offset o;
    if (align == TextAlign.right) {
      o = Offset(px - tp.width, py - tp.height);
    } else if (align == TextAlign.center) {
      o = Offset(px - tp.width / 2, py - tp.height);
    } else {
      o = Offset(px, py - tp.height);
    }
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(_SleepClockPainter old) =>
      old.plan != plan ||
      old.actual != actual ||
      old.W != W ||
      old.palette != palette;
}

double mathMax(double a, double b) => a >= b ? a : b;
double mathMin(double a, double b) => a <= b ? a : b;

/// pain figure: front or back view with tap-to-cycle regions
class PainFigure extends StatelessWidget {
  final Map<String, int> pain;
  final String selected;
  final bool back;
  final ValueChanged<String> onTap;
  const PainFigure({
    super.key,
    required this.pain,
    required this.selected,
    required this.back,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = w * 246 / 110;
        return SizedBox(
          width: w,
          height: h,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (d) {
              final scale = w / 110;
              final pos = d.localPosition / scale;
              final regions = back ? kBackRegions : kFrontRegions;
              for (final r in regions) {
                final id = r[0] as String;
                final shape = r[1] as String;
                final cx = (r[2] as num).toDouble();
                final cy = (r[3] as num).toDouble();
                final a = (r[4] as num).toDouble();
                final b = (r[5] as num).toDouble();
                bool hit = false;
                if (shape == 'c') {
                  hit = (pos.dx - cx).abs() <= a && (pos.dy - cy).abs() <= a;
                } else if (shape == 'e') {
                  final nx = (pos.dx - cx) / a;
                  final ny = (pos.dy - cy) / b;
                  hit = nx * nx + ny * ny <= 1;
                } else {
                  // rect data is x/y/w/h (top-left origin), same as the design's painSVG
                  hit =
                      pos.dx >= cx &&
                      pos.dx <= cx + a &&
                      pos.dy >= cy &&
                      pos.dy <= cy + b;
                }
                if (hit) {
                  onTap(id);
                  return;
                }
              }
            },
            child: CustomPaint(
              painter: _PainPainter(
                palette: p,
                regions: back ? kBackRegions : kFrontRegions,
                pain: pain,
                selected: selected,
                back: back,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PainPainter extends CustomPainter {
  final AVPalette palette;
  final List<List<dynamic>> regions;
  final Map<String, int> pain;
  final String selected;
  final bool back;
  _PainPainter({
    required this.palette,
    required this.regions,
    required this.pain,
    required this.selected,
    required this.back,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final sc = size.width / 110;
    canvas.scale(sc, sc);

    // faint body outline for the back view
    if (back) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..color = p.line
        ..strokeWidth = 1;
      canvas.drawCircle(const Offset(55, 20), 15, outline);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(14, 60, 12, 52),
          topLeft: const Radius.circular(6),
          bottomLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
          bottomRight: const Radius.circular(6),
        ),
        outline,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(84, 60, 12, 52),
          topLeft: const Radius.circular(6),
          bottomLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
          bottomRight: const Radius.circular(6),
        ),
        outline,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(30, 52), width: 24, height: 18),
        outline,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(80, 52), width: 24, height: 18),
        outline,
      );
    }

    for (final r in regions) {
      final id = r[0] as String;
      final shape = r[1] as String;
      final cx = (r[2] as num).toDouble();
      final cy = (r[3] as num).toDouble();
      final a = (r[4] as num).toDouble();
      final b = (r[5] as num).toDouble();
      final lvl = pain[id] ?? 0;
      // .reg .rs{fill:rgba(140,190,235,.08);stroke:var(--line);stroke-width:1}
      // marked shape (inline in painSVG): fill var(--pN); stroke var(--pNs); width 1.5
      final fill = Paint()
        ..color = lvl > 0
            ? [p.p1, p.p2, p.p3][lvl - 1]
            : const Color(0x148CBEEB);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lvl > 0 ? 1.5 : 1.0
        ..color = lvl > 0 ? [p.p1s, p.p2s, p.p3s][lvl - 1] : p.line;
      if (shape == 'c') {
        canvas.drawCircle(Offset(cx, cy), a, fill);
        canvas.drawCircle(Offset(cx, cy), a, stroke);
        if (selected == id) canvas.drawCircle(Offset(cx, cy), a, _selStroke(p));
      } else if (shape == 'e') {
        final rect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: a * 2,
          height: b * 2,
        );
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
        if (selected == id) canvas.drawOval(rect, _selStroke(p));
      } else {
        // region data keeps the design's x/y/w/h (top-left origin), like painSVG
        final rect = Rect.fromLTWH(cx, cy, a, b);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, stroke);
        if (selected == id) canvas.drawRRect(rr, _selStroke(p));
      }
    }

    final tp = TextPainter(
      text: TextSpan(
        text: back ? 'BACK' : 'FRONT',
        style: AVText.displayStyle(10, color: p.muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(55 - tp.width / 2, 236));
  }

  // .reg.sel .rs{stroke:var(--fg);stroke-width:2.5}
  Paint _selStroke(AVPalette p) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = p.fg;

  @override
  bool shouldRepaint(_PainPainter old) =>
      old.pain != pain ||
      old.selected != selected ||
      old.back != back ||
      old.palette != palette;
}

/// mood face icon (faceSVG port)
class FaceIcon extends StatelessWidget {
  final int n;
  final Color? color;
  final double size;
  const FaceIcon(this.n, {super.key, this.color, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _FacePainter(n, color ?? p.fg),
    );
  }
}

class _FacePainter extends CustomPainter {
  final int n;
  final Color color;
  _FacePainter(this.n, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    double sx(double v) => v / 20 * s;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = sx(1.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(Offset(sx(10), sx(10)), sx(8.2), stroke);
    canvas.drawLine(Offset(sx(7.2), sx(7.6)), Offset(sx(7.3), sx(7.7)), stroke);
    canvas.drawLine(
      Offset(sx(12.8), sx(7.6)),
      Offset(sx(12.9), sx(7.7)),
      stroke,
    );
    final mouth = switch (n) {
      1 => 'M7 14.2Q10 10.6 13 14.2',
      2 => 'M7 13.6Q10 11.8 13 13.6',
      3 => 'M7 13H13',
      4 => 'M7 12Q10 14.6 13 12',
      _ => 'M6.4 11.4Q10 16.6 13.6 11.4',
    };
    final path = Path();
    // parse the simple M/Q/H commands
    final re = RegExp(r'([MQHq])|(-?\d*\.?\d+)');
    final tokens = re.allMatches(mouth).map((m) => m.group(0)!).toList();
    String cmd = '';
    final nums = <double>[];
    for (final t in tokens) {
      if (t.length == 1 && RegExp(r'[A-Za-z]').hasMatch(t)) {
        _consume(canvas, path, cmd, nums, sx);
        nums.clear();
        cmd = t;
      } else {
        nums.add(double.parse(t));
      }
    }
    _consume(canvas, path, cmd, nums, sx);
    canvas.drawPath(path, stroke);
  }

  void _consume(
    Canvas canvas,
    Path path,
    String cmd,
    List<double> a,
    double Function(double) sx,
  ) {
    switch (cmd) {
      case 'M':
        if (a.length >= 2) path.moveTo(sx(a[0]), sx(a[1]));
        break;
      case 'Q':
        for (var i = 0; i + 3 < a.length; i += 4) {
          path.quadraticBezierTo(
            sx(a[i]),
            sx(a[i + 1]),
            sx(a[i + 2]),
            sx(a[i + 3]),
          );
        }
        break;
      case 'H':
        path.lineTo(sx(a[0]), path.getBounds().center.dy);
        break;
    }
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.n != n || old.color != color;
}
