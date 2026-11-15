/// Status shapes - port of shapeInner(): circle+check, hollow circle, triangle,
/// diamond, octagon, hexagon. Also the tier chip.
library;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/engine/engine.dart' show kTierNames;

class StatusIcon extends StatelessWidget {
  final int l;
  final double size;
  const StatusIcon(this.l, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _StatusShapePainter(l, p, p.tierC(l)),
    );
  }
}

class _StatusShapePainter extends CustomPainter {
  final int l;
  final AVPalette p;
  final Color color;
  _StatusShapePainter(this.l, this.p, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    paintStatusShape(canvas, Offset(size.width / 2, size.height / 2), size.width, l, p);
  }

  @override
  bool shouldRepaint(_StatusShapePainter old) =>
      old.l != l || old.color != color || old.p != p;
}

/// paints the six-tier status shape centred at [center]; shared with the
/// body-map painter.
void paintStatusShape(
    Canvas canvas, Offset center, double size, int l, AVPalette p) {
  final s = size;
  double sx(double v) => v / 20 * s;
  Offset o(double x, double y) => Offset(center.dx + (x - 10) / 20 * s, center.dy + (y - 10) / 20 * s);
  final color = p.tierC(l);
  final paint = Paint()..color = color;
  final dark = Paint()
    ..color = const Color(0xFF1A1208)
    ..style = PaintingStyle.stroke
    ..strokeWidth = sx(1.8)
    ..strokeCap = StrokeCap.round;
  final white = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = sx(2)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Path path;
  switch (l) {
    case 0:
      canvas.drawCircle(center, sx(8.5), paint);
      path = Path()
        ..moveTo(o(5.8, 10.4).dx, o(5.8, 10.4).dy)
        ..lineTo(o(8.7, 13.3).dx, o(8.7, 13.3).dy)
        ..lineTo(o(14.3, 7.3).dx, o(14.3, 7.3).dy);
      canvas.drawPath(path, white);
      return;
    case 1:
      canvas.drawCircle(center, sx(7.5),
          Paint()..style = PaintingStyle.stroke..color = p.tier[1]..strokeWidth = sx(2));
      canvas.drawCircle(center, sx(2.4), paint);
      return;
    case 2:
      path = Path()
        ..moveTo(o(10, 2).dx, o(10, 2).dy)
        ..lineTo(o(18.6, 17.4).dx, o(18.6, 17.4).dy)
        ..lineTo(o(1.4, 17.4).dx, o(1.4, 17.4).dy)
        ..close();
      canvas.drawPath(path, paint);
      path = Path()
        ..moveTo(o(10, 7.6).dx, o(10, 7.6).dy)
        ..lineTo(o(10, 12.6).dx, o(10, 12.6).dy);
      canvas.drawPath(path, dark);
      canvas.drawLine(o(10, 14.3), o(10, 14.4), dark);
      return;
    case 3:
      path = Path()
        ..moveTo(o(10, 1.4).dx, o(10, 1.4).dy)
        ..lineTo(o(18.6, 10).dx, o(18.6, 10).dy)
        ..lineTo(o(10, 18.6).dx, o(10, 18.6).dy)
        ..lineTo(o(1.4, 10).dx, o(1.4, 10).dy)
        ..close();
      canvas.drawPath(path, paint);
      path = Path()
        ..moveTo(o(10, 6.4).dx, o(10, 6.4).dy)
        ..lineTo(o(10, 11).dx, o(10, 11).dy);
      canvas.drawPath(path, dark);
      canvas.drawLine(o(10, 13.3), o(10, 13.4), dark);
      return;
    case 4:
      path = Path()
        ..moveTo(o(6.4, 1.6).dx, o(6.4, 1.6).dy)
        ..lineTo(o(13.6, 1.6).dx, o(13.6, 1.6).dy)
        ..lineTo(o(18.4, 6.4).dx, o(18.4, 6.4).dy)
        ..lineTo(o(18.4, 13.6).dx, o(18.4, 13.6).dy)
        ..lineTo(o(13.6, 18.4).dx, o(13.6, 18.4).dy)
        ..lineTo(o(6.4, 18.4).dx, o(6.4, 18.4).dy)
        ..lineTo(o(1.6, 13.6).dx, o(1.6, 13.6).dy)
        ..lineTo(o(1.6, 6.4).dx, o(1.6, 6.4).dy)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawLine(o(7, 7), o(13, 13), white);
      canvas.drawLine(o(13, 7), o(7, 13), white);
      return;
    default:
      path = Path()
        ..moveTo(o(10, 1.6).dx, o(10, 1.6).dy)
        ..lineTo(o(17.8, 6.1).dx, o(17.8, 6.1).dy)
        ..lineTo(o(17.8, 14.9).dx, o(17.8, 14.9).dy)
        ..lineTo(o(10, 19.4).dx, o(10, 19.4).dy)
        ..lineTo(o(2.2, 14.9).dx, o(2.2, 14.9).dy)
        ..lineTo(o(2.2, 6.1).dx, o(2.2, 6.1).dy)
        ..close();
      canvas.drawPath(path, Paint()..color = p.tier[5]);
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFE57373)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sx(1));
      path = Path()
        ..moveTo(o(10, 6.2).dx, o(10, 6.2).dy)
        ..lineTo(o(10, 11.4).dx, o(10, 11.4).dy);
      canvas.drawPath(path, white);
      canvas.drawLine(o(10, 13.7), o(10, 13.8), white);
      return;
  }
}

/// chip(l) port: status pill with icon + name
class TierChip extends StatelessWidget {
  final int l;
  const TierChip(this.l, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 12, 3),
      decoration: ShapeDecoration(
        color: p.tierT(l).withValues(alpha: 0.18),
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusIcon(l, size: 14),
          const SizedBox(width: 6),
          Text(kTierNames[l],
              style: AVText.displayStyle(12, w: FontWeight.w600, color: p.tierT(l))),
        ],
      ),
    );
  }
}
