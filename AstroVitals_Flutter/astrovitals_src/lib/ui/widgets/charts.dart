/// Health index chart over 14 days - port of healthBars(): coloured level
/// bands, axis labels, index line, per-day dots and the highlighted today
/// marker. CustomPaint per the team's decision (no chart libraries).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/engine/engine.dart' show kTierNames;

class HealthBarsChart extends StatelessWidget {
  final List<int> values; // 14 index values
  const HealthBarsChart(this.values, {super.key});

  @override
  Widget build(BuildContext context) {
    final last = values.last;
    final d14 = last - values.first;
    final d1 = last - values[values.length - 2];
    final trend = d1 <= -10
        ? 'down ${-d1} points since yesterday'
        : d14.abs() < 3
            ? 'steady over 14 days'
            : '${d14 > 0 ? 'up' : 'down'} ${d14.abs()} points over 14 days';
    final title = '$last today, $trend';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Health index: $title',
            style: AVText.displayStyle(19, w: FontWeight.w600, color: avp(context).fg)),
        const SizedBox(height: 6),
        Text(
          'One score out of 100 for all your readings. 100 means every reading is in your usual range; your worst alert caps it, so a single serious reading always shows. The coloured bands are the six alert levels.',
          style: AVText.bodyStyle(14, color: avp(context).muted),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final sm = box.maxWidth < 640;
          return SizedBox(
            width: double.infinity,
            height: sm ? 220 : 236,
            child: CustomPaint(
              painter: _HealthBarsPainter(values: values, p: avp(context), sm: sm),
            ),
          );
        }),
      ],
    );
  }
}

class _HealthBarsPainter extends CustomPainter {
  final List<int> values;
  final AVPalette p;
  final bool sm;
  _HealthBarsPainter({required this.values, required this.p, required this.sm});

  static const N = 14;
  static const List<List<double>> bands = [
    [90, 100, 0],
    [80, 90, 1],
    [65, 80, 2],
    [50, 65, 3],
    [35, 50, 4],
    [0, 35, 5],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    const pt = 14.0, pb = 34.0;
    final pl = sm ? 28.0 : 40.0;
    final pr = sm ? 82.0 : 112.0;
    final cw = W - pl - pr;
    final ch = H - pt - pb;
    double X(int i) => pl + i * cw / (N - 1);
    double Y(double v) => pt + (100 - v) / 100 * ch;
    final fs = sm ? 11.0 : 12.0;
    final last = values.last;
    final lvl = idxLevelOf(last);

    for (final b in bands) {
      final y0 = Y(b[1]), y1 = Y(b[0]);
      canvas.drawRect(
          Rect.fromLTWH(pl, y0, cw, y1 - y0),
          Paint()..color = p.tierC(b[2].round()).withValues(alpha: 0.1));
      _text(canvas, kTierNames[b[2].round()], W - pr + 10, (y0 + y1) / 2 + 4,
          AVText.bodyStyle(fs, w: FontWeight.w500, color: p.tierT(b[2].round())));
    }
    for (final g in [0.0, 50.0, 100.0]) {
      _text(canvas, g.round().toString(), pl - 8, Y(g) + 4,
          AVText.bodyStyle(fs, color: p.muted), align: TextAlign.right);
    }
    canvas.drawLine(
        Offset(pl, pt + ch), Offset(W - pr, pt + ch), Paint()..color = p.line);

    final xs = sm
        ? [[0, '13 days ago'], [N - 1, 'Today']]
        : [[0, '13 days ago'], [6, '7 days ago'], [N - 1, 'Today']];
    for (final t in xs) {
      final i = t[0] as int;
      _text(canvas, t[1] as String, X(i), H - 10, AVText.bodyStyle(fs, color: p.muted),
          align: i == 0
              ? TextAlign.left
              : i == N - 1
                  ? TextAlign.right
                  : TextAlign.center);
    }

    final line = Path()..moveTo(X(0), Y(values[0].toDouble()));
    for (var i = 1; i < N; i++) {
      line.lineTo(X(i), Y(values[i].toDouble()));
    }
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = p.fg.withValues(alpha: 0.85)
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);

    for (var i = 0; i < N - 1; i++) {
      canvas.drawCircle(Offset(X(i), Y(values[i].toDouble())), 3.5,
          Paint()..color = p.tierT(idxLevelOf(values[i])));
    }

    final lx = X(N - 1), ly = Y(last.toDouble());
    canvas.drawCircle(Offset(lx, ly), 7, Paint()..color = p.tierT(lvl));
    canvas.drawCircle(
        Offset(lx, ly),
        7,
        Paint()
          ..color = p.panelSolid
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    _text(canvas, last.toString(), lx - 12, ly < pt + 24 ? ly + 22 : ly - 12,
        AVText.num(15, color: p.fg), align: TextAlign.right);
  }

  static int idxLevelOf(int v) =>
      v >= 90 ? 0 : v >= 80 ? 1 : v >= 65 ? 2 : v >= 50 ? 3 : v >= 35 ? 4 : 5;

  void _text(Canvas canvas, String s, double x, double y, TextStyle style,
      {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    Offset o;
    switch (align) {
      case TextAlign.right:
        o = Offset(x - tp.width, y - tp.height / 2);
        break;
      case TextAlign.center:
        o = Offset(x - tp.width / 2, y - tp.height / 2);
        break;
      default:
        o = Offset(x, y - tp.height / 2);
    }
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(_HealthBarsPainter old) =>
      old.values != values || old.p != p || old.sm != sm;
}

// imported math for future clamps
// ignore: unused_element
double _clamp01(double v) => math.min(1, math.max(0, v));
