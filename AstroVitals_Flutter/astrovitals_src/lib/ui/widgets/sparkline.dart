/// Sparklines and the range bar - port of spark(), sparkB() and rangeBar().
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/contract/models.dart';

class Sparkline extends StatelessWidget {
  final List<double> values;
  final int level;
  final double? baseline;
  final double width;
  final double height;
  final bool big;
  const Sparkline(this.values, this.level,
      {super.key, this.baseline, this.width = 84, this.height = 26, this.big = false});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    if (values.length < 2) return SizedBox(width: width, height: height);
    final c = p.tierT(level);
    double mn = math.min(values.reduce(math.min), baseline ?? values.first);
    double mx = math.max(values.reduce(math.max), baseline ?? values.first);
    if (mx == mn) {
      mx += 1;
      mn -= 1;
    }
    final w = big ? 170.0 : width;
    final h = big ? 64.0 : height;
    final padX = big ? 3.0 : 2.0;
    final spanX = w - (big ? 12 : 6);
    double y(double v) =>
        h - (big ? 6 : 3) - ((v - mn) / (mx - mn)) * (h - (big ? 14 : 8));

    final pts = List<(double, double)>.generate(values.length, (i) {
      return (padX + i / (values.length - 1) * spanX, y(values[i]));
    });

    final line = Path()..moveTo(pts[0].$1, pts[0].$2);
    for (final pt in pts.skip(1)) {
      line.lineTo(pt.$1, pt.$2);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.$1, h - 1)
      ..lineTo(pts.first.$1, h - 1)
      ..close();

    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _SparkPainter(
          area: area,
          line: line,
          last: pts.last,
          color: c,
          baseline: baseline != null ? y(baseline!) : null,
          big: big,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final Path area, line;
  final (double, double) last;
  final Color color;
  final double? baseline;
  final bool big;
  _SparkPainter(
      {required this.area, required this.line, required this.last, required this.color, this.baseline, required this.big});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.16));
    if (baseline != null) {
      final bp = Paint()
        ..color = const Color(0xFFBED7F0).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      // dashed baseline
      final dash = Path()
        ..moveTo(2, baseline!)
        ..lineTo(size.width - 2, baseline!);
      final pathMetrics = dash.computeMetrics().toList();
      for (final m in pathMetrics) {
        var d = 0.0;
        while (d < m.length) {
          final seg = m.extractPath(d, math.min(d + 3, m.length));
          canvas.drawPath(seg, bp);
          d += 6;
        }
      }
    }
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color
          ..strokeWidth = big ? 2 : 1.5
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(Offset(last.$1, last.$2), big ? 3.5 : 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.color != color || old.last != last || old.baseline != baseline;
}

/// range bar with zone segments + marker (rangeBar port)
class RangeBar extends StatelessWidget {
  final String metricId;
  final double value;
  final int level;
  const RangeBar({super.key, required this.metricId, required this.value, required this.level});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    // bp uses the systolic zones/bar
    final key = metricId == 'bp' ? 'sys' : metricId;
    final t = kZoneByKey[key]!;
    final zones = t.z;
    final bar = t.bar ?? [zones.first[0], zones.last[1]];
    final span = bar[1] - bar[0];
    final segs = <Widget>[];
    for (final z in zones) {
      final a = math.max(z[0], bar[0]);
      final b = math.min(z[1], bar[1]);
      if (b > a) {
        segs.add(Flexible(
          child: FractionallySizedBox(
            widthFactor: (b - a) / span,
            child: Container(color: p.tierC(z[2].round()).withValues(alpha: 0.8)),
          ),
        ));
      }
    }
    final pos = ((value - bar[0]) / span * 100).clamp(0.0, 100.0);
    return Column(
      children: [
        const SizedBox(height: 18),
        SizedBox(
          height: 10,
          child: Stack(
            children: [
              Row(children: [Expanded(child: Row(children: segs))]),
              Positioned(
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment(pos / 100 * 2 - 1, 0),
                  child: Transform.translate(
                    offset: const Offset(0, -8),
                    child: CustomPaint(size: const Size(12, 9), painter: _MarkerPainter(p.fg)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_num(bar[0]), style: AVText.displayStyle(10, color: p.muted)),
            Text(_num(bar[1]), style: AVText.displayStyle(10, color: p.muted)),
          ],
        ),
      ],
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

class _MarkerPainter extends CustomPainter {
  final Color c;
  _MarkerPainter(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.c != c;
}
