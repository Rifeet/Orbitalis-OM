/// Holographic body map - CustomPaint port of the design's buildBody() SVG:
/// figure paths, skin gradient, floor glow + rotating ring, scanning band,
/// and the seven organ hotspots with lead lines, tags and status icons.
/// Tap targets are positioned analytically over the painted coordinates.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/contract/fields.dart';
import 'status_icon.dart';

const double kVbW = 460;
const double kVbH = 650;

const String _dHead =
    'M150 18 C130 18 122 34 122 52 C122 70 134 86 150 86 C166 86 178 70 178 52 C178 34 170 18 150 18Z';
const String _dTorso =
    'M100 126 C116 108 135 106 150 106 C165 106 184 108 200 126 L197 200 C195 240 199 280 192 308 L108 308 C101 280 105 240 103 200 Z';
const String _dArm =
    'M98 128 C82 134 76 158 72 192 L60 300 L50 380 L66 384 L80 308 L98 204Z';
const String _dLeg =
    'M108 308 L150 308 L146 440 L142 540 L147 604 L118 604 L121 540 L112 440Z';

class _OrganSpot {
  final String organId;
  final double cx, cy, ly;
  final String side;
  final List<Path> shapes; // filled shapes
  final List<Path> lineShapes; // line-only shapes
  const _OrganSpot(this.organId, this.cx, this.cy, this.ly, this.side,
      {required this.shapes, this.lineShapes = const []});
}

List<_OrganSpot> _spots() {
  Path p(String d) => _pathFromSvg(d);
  return [
    _OrganSpot('brain', 150, 40, 40, 'L',
        shapes: [
          p('M130 44 C128 28 142 20 150 24 C158 20 172 28 170 44 C170 54 160 58 150 56 C140 58 130 54 130 44Z'),
        ],
        lineShapes: [
          p('M138 38 q6 -7 12 0 t12 0 M138 48 q6 -6 12 0 t12 0'),
        ]),
    _OrganSpot('immune', 150, 96, 96, 'R', shapes: [
      Path()..addOval(Rect.fromCircle(center: Offset(150, 96), radius: 6)),
      Path()..addOval(Rect.fromCircle(center: Offset(139, 101), radius: 3.4)),
      Path()..addOval(Rect.fromCircle(center: Offset(161, 101), radius: 3.4)),
    ]),
    _OrganSpot('lungs', 140, 168, 150, 'L', shapes: [
      p('M145 138 C130 134 114 148 112 178 C111 196 126 202 145 194Z'),
      p('M155 138 C170 134 186 148 188 178 C189 196 174 202 155 194Z'),
    ]),
    _OrganSpot('heart', 160, 172, 178, 'R', shapes: [
      p('M160 188 C140 174 145 158 155 160 C158 161 160 164 160 164 C160 164 162 161 165 160 C175 158 180 174 160 188Z'),
    ]),
    _OrganSpot('metab', 150, 245, 246, 'L',
        shapes: [
          p('M132 238 C132 226 150 224 164 232 C176 238 170 258 154 258 C140 258 132 250 132 238Z'),
        ],
        lineShapes: [
          p('M126 270 q8 -8 16 0 t16 0 t16 0'),
        ]),
    _OrganSpot('bones', 150, 304, 306, 'R', shapes: [
      p('M112 296 C120 286 140 290 150 300 C160 290 180 286 188 296 L184 314 C170 318 160 312 150 322 C140 312 130 318 116 314Z'),
    ]),
    _OrganSpot('muscle', 130, 400, 410, 'L', shapes: [
      Path()..addOval(Rect.fromCenter(center: Offset(130, 400), width: 28, height: 92)),
      Path()..addOval(Rect.fromCenter(center: Offset(170, 400), width: 28, height: 92)),
    ]),
  ];
}

/// minimal svg path parser for the absolute/relative commands used here
Path _pathFromSvg(String d) {
  final path = Path();
  final re = RegExp(
      r'([MmLlCcQqTtVvHhSsZz])|(-?\d*\.?\d+(?:e-?\d+)?)',
      caseSensitive: false);
  final tokens = re.allMatches(d).map((m) => m.group(0)!).toList();
  double cx = 0, cy = 0;
  double px = 0, py = 0; // previous control point (for q/t)
  String cmd = '';
  final nums = <double>[];
  void consume(String c, List<double> a) {
    switch (c) {
      case 'M':
        for (var i = 0; i + 1 < a.length + 1 && i < a.length; i += 2) {
          cx = a[i]; cy = a[i + 1];
          if (i == 0) {
            path.moveTo(cx, cy);
          } else {
            path.lineTo(cx, cy);
          }
        }
        break;
      case 'm':
        for (var i = 0; i < a.length; i += 2) {
          cx += a[i]; cy += a[i + 1];
          if (i == 0) {
            path.moveTo(cx, cy);
          } else {
            path.lineTo(cx, cy);
          }
        }
        break;
      case 'L':
        for (var i = 0; i + 1 < a.length; i += 2) {
          cx = a[i]; cy = a[i + 1];
          path.lineTo(cx, cy);
        }
        break;
      case 'l':
        for (var i = 0; i + 1 < a.length; i += 2) {
          cx += a[i]; cy += a[i + 1];
          path.lineTo(cx, cy);
        }
        break;
      case 'H':
        for (var i = 0; i < a.length; i++) {
          cx = a[i];
          path.lineTo(cx, cy);
        }
        break;
      case 'h':
        for (var i = 0; i < a.length; i++) {
          cx += a[i];
          path.lineTo(cx, cy);
        }
        break;
      case 'V':
        for (var i = 0; i < a.length; i++) {
          cy = a[i];
          path.lineTo(cx, cy);
        }
        break;
      case 'v':
        for (var i = 0; i < a.length; i++) {
          cy += a[i];
          path.lineTo(cx, cy);
        }
        break;
      case 'C':
        for (var i = 0; i + 5 < a.length; i += 6) {
          path.cubicTo(a[i], a[i + 1], a[i + 2], a[i + 3], a[i + 4], a[i + 5]);
          px = a[i + 2]; py = a[i + 3];
          cx = a[i + 4]; cy = a[i + 5];
        }
        break;
      case 'c':
        for (var i = 0; i + 5 < a.length; i += 6) {
          path.cubicTo(cx + a[i], cy + a[i + 1], cx + a[i + 2], cy + a[i + 3],
              cx + a[i + 4], cy + a[i + 5]);
          px = cx + a[i + 2]; py = cy + a[i + 3];
          cx += a[i + 4]; cy += a[i + 5];
        }
        break;
      case 'S':
        for (var i = 0; i + 3 < a.length; i += 4) {
          final rx = 2 * cx - px, ry = 2 * cy - py;
          path.cubicTo(rx, ry, a[i], a[i + 1], a[i + 2], a[i + 3]);
          px = a[i]; py = a[i + 1];
          cx = a[i + 2]; cy = a[i + 3];
        }
        break;
      case 's':
        for (var i = 0; i + 3 < a.length; i += 4) {
          final rx = 2 * cx - px, ry = 2 * cy - py;
          path.cubicTo(rx, ry, cx + a[i], cy + a[i + 1], cx + a[i + 2], cy + a[i + 3]);
          px = cx + a[i]; py = cy + a[i + 1];
          cx += a[i + 2]; cy += a[i + 3];
        }
        break;
      case 'Q':
        for (var i = 0; i + 3 < a.length; i += 4) {
          path.quadraticBezierTo(a[i], a[i + 1], a[i + 2], a[i + 3]);
          px = a[i]; py = a[i + 1];
          cx = a[i + 2]; cy = a[i + 3];
        }
        break;
      case 'q':
        for (var i = 0; i + 3 < a.length; i += 4) {
          path.quadraticBezierTo(cx + a[i], cy + a[i + 1], cx + a[i + 2], cy + a[i + 3]);
          px = cx + a[i]; py = cy + a[i + 1];
          cx += a[i + 2]; cy += a[i + 3];
        }
        break;
      case 'T':
        for (var i = 0; i + 1 < a.length; i += 2) {
          final rx = 2 * cx - px, ry = 2 * cy - py;
          path.quadraticBezierTo(rx, ry, a[i], a[i + 1]);
          px = rx; py = ry;
          cx = a[i]; cy = a[i + 1];
        }
        break;
      case 't':
        for (var i = 0; i + 1 < a.length; i += 2) {
          final rx = 2 * cx - px, ry = 2 * cy - py;
          path.quadraticBezierTo(rx, ry, cx + a[i], cy + a[i + 1]);
          px = rx; py = ry;
          cx += a[i]; cy += a[i + 1];
        }
        break;
      case 'Z':
      case 'z':
        path.close();
        break;
    }
  }

  for (final t in tokens) {
    final isCmd = RegExp(r'^[A-Za-z]$').hasMatch(t);
    if (isCmd) {
      if (cmd.isNotEmpty) {
        consume(cmd, nums);
        nums.clear();
      }
      cmd = t;
    } else {
      nums.add(double.parse(t));
    }
  }
  if (cmd.isNotEmpty && nums.isNotEmpty) consume(cmd, nums);
  return path;
}

class BodyMap extends StatefulWidget {
  final Map<String, int> levels;
  final Map<String, String> values;
  final String selected;
  final ValueChanged<String> onSelect;
  const BodyMap({
    super.key,
    required this.levels,
    required this.values,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> with TickerProviderStateMixin {
  late final AnimationController _scan =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  late final AnimationController _ring =
      AnimationController(vsync: this, duration: const Duration(seconds: 50))..repeat();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _scan.dispose();
    _ring.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = w * kVbH / kVbW;
      final scale = w / kVbW;
      return SizedBox(
        width: w,
        height: h,
        child: AnimatedBuilder(
          animation: Listenable.merge([_scan, _ring, _pulse]),
          builder: (context, _) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) {
                final pos = d.localPosition / scale;
                for (final s in _spots()) {
                  final dist = math.sqrt(
                      math.pow(pos.dx - (s.cx + 80), 2) + math.pow(pos.dy - s.cy, 2));
                  if (dist <= 26) {
                    widget.onSelect(s.organId);
                    return;
                  }
                }
              },
              child: CustomPaint(
                size: Size(w, h),
                painter: _BodyPainter(
                  palette: p,
                  levels: widget.levels,
                  values: widget.values,
                  selected: widget.selected,
                  scanY: 20 + _scan.value * 540,
                  ringAngle: _ring.value * 2 * math.pi,
                  pulse: _pulse.value,
                  scale: scale,
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _BodyPainter extends CustomPainter {
  final AVPalette palette;
  final Map<String, int> levels;
  final Map<String, String> values;
  final String selected;
  final double scanY, ringAngle, pulse, scale;
  _BodyPainter({
    required this.palette,
    required this.levels,
    required this.values,
    required this.selected,
    required this.scanY,
    required this.ringAngle,
    required this.pulse,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    canvas.save();
    canvas.scale(size.width / kVbW, size.height / kVbH);

    // ---------- floor glow + rings ----------
    final floorRect = Rect.fromCenter(center: Offset(230, 614), width: 300, height: 52);
    canvas.drawOval(
        floorRect,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFF2F78B0).withValues(alpha: 0.55), const Color(0xFF2F78B0).withValues(alpha: 0)],
          ).createShader(floorRect));
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(230, 614), width: 240, height: 40),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF5AAEE8).withValues(alpha: 0.7)
          ..strokeWidth = 1.5);
    canvas.save();
    canvas.translate(230, 614);
    canvas.rotate(ringAngle);
    // dashed ellipse ring
    final ring = Path()..addOval(Rect.fromCenter(center: const Offset(0, 0), width: 296, height: 50));
    final pm = ring.computeMetrics().toList();
    for (final m in pm) {
      var d = 0.0;
      final bp = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF5AAEE8).withValues(alpha: 0.45)
        ..strokeWidth = 1;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 3, m.length)), bp);
        d += 12;
      }
    }
    canvas.restore();
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(230, 614), width: 184, height: 28),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF2F78B0).withValues(alpha: 0.7));

    // ---------- figure ----------
    final dx = 80.0;
    Path mirror(Path src) {
      final m = Path();
      final t = Matrix4.identity()
        ..translateByDouble(300, 0, 0, 1)
        ..scaleByDouble(-1, 1, 1, 1);
      final transformed = src.transform(t.storage);
      m.addPath(transformed, Offset.zero);
      return m;
    }

    final head = _pathFromSvg(_dHead);
    final torso = _pathFromSvg(_dTorso);
    final arm = _pathFromSvg(_dArm);
    final armM = mirror(arm);
    final leg = _pathFromSvg(_dLeg);
    final legM = mirror(leg);

    // body clip (for the scan band)
    final bodyClip = Path()
      ..addPath(head.shift(Offset(dx, 0)), Offset.zero)
      ..addPath(torso.shift(Offset(dx, 0)), Offset.zero)
      ..addPath(arm.shift(Offset(dx, 0)), Offset.zero)
      ..addPath(armM.shift(Offset(dx, 0)), Offset.zero)
      ..addPath(leg.shift(Offset(dx, 0)), Offset.zero)
      ..addPath(legM.shift(Offset(dx, 0)), Offset.zero);

    final skinRect = const Rect.fromLTRB(0, 0, kVbW, kVbH);
    final bodyFill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x4D5AAEE8), Color(0x1A2F78B0)],
      ).createShader(skinRect);
    final bodyStroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF5AAEE8).withValues(alpha: 0.85)
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;

    final shifted = <Path>[
      head.shift(Offset(dx, 0)),
      torso.shift(Offset(dx, 0)),
      arm.shift(Offset(dx, 0)),
      armM.shift(Offset(dx, 0)),
      leg.shift(Offset(dx, 0)),
      legM.shift(Offset(dx, 0)),
    ];
    for (final path in shifted) {
      canvas.drawPath(path, bodyFill);
      canvas.drawPath(path, bodyStroke);
    }
    // neck lines
    canvas.drawLine(Offset(138 + dx, 84), Offset(138 + dx, 108), bodyStroke);
    canvas.drawLine(Offset(162 + dx, 84), Offset(162 + dx, 108), bodyStroke);

    // ---------- inner details ----------
    final showDetails = const bool.fromEnvironment('AV_DETAILS', defaultValue: true);
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFCFE9FA).withValues(alpha: 0.5)
      ..strokeWidth = 1;
    if (!showDetails) {
      // debug build: skip inner details
    } else {
    canvas.drawOval(
        Rect.fromCenter(center: Offset(140 + dx, 54), width: 12, height: 10), detail);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(160 + dx, 54), width: 12, height: 10), detail);
    canvas.drawPath(
        _pathFromSvg('M146 68 L150 64 L154 68 M136 74 Q150 84 164 74').shift(Offset(dx, 0)),
        detail);
    canvas.drawLine(Offset(150 + dx, 108), Offset(150 + dx, 304),
        detail..strokeWidth = 2);
    for (var v = 0; v < 16; v++) {
      final y = 114 + v * 12.0;
      canvas.drawLine(Offset(145 + dx, y), Offset(155 + dx, y), detail);
    }
    for (var r = 0; r < 7; r++) {
      final yy = 124 + r * 11.0;
      canvas.drawPath(
          _pathFromSvg('M150 $yy Q122 ${yy - 8} 108 ${yy + 16}').shift(Offset(dx, 0)), detail);
      canvas.drawPath(
          _pathFromSvg('M150 $yy Q178 ${yy - 8} 192 ${yy + 16}').shift(Offset(dx, 0)), detail);
    }
    canvas.drawPath(_pathFromSvg('M104 128 Q150 112 196 128').shift(Offset(dx, 0)), detail);
    canvas.drawPath(_pathFromSvg('M72 192 L58 300 L52 380 M228 192 L242 300 L248 380').shift(Offset(dx, 0)), detail);
    canvas.drawPath(_pathFromSvg('M128 316 L134 440 L136 540 M172 316 L166 440 L164 540').shift(Offset(dx, 0)), detail);
    canvas.drawLine(Offset(128 + dx, 440), Offset(172 + dx, 440), detail);
    }

    // ---------- scan band (clipped to body) ----------
    canvas.save();
    canvas.clipPath(bodyClip, doAntiAlias: true);
    final scanRect = Rect.fromLTWH(0, scanY, kVbW, 42);
    canvas.drawRect(
        scanRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x005AAEE8),
              Color(0x575AAEE8),
              Color(0xE6A8D6F5),
            ],
            stops: [0, 0.85, 1],
          ).createShader(scanRect));
    canvas.restore();

    // ---------- hotspots ----------
    for (final spot in _spots()) {
      final l = levels[spot.organId] ?? 0;
      final sel = selected == spot.organId;
      final ct = p.tierT(l);
      final fillPct = sel ? 0.5 : 0.26;
      final fill = Paint()..color = Color.lerp(Colors.transparent, ct, fillPct)!;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..color = ct
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round;
      final pulseAlpha = l >= 2 ? 0.2 + 0.25 * pulse : 0.0;

      // lead line
      final x1 = spot.side == 'L'
          ? math.min(spot.cx - 18, 110)
          : math.max(spot.cx + 18, 190);
      final x2 = spot.side == 'L' ? 74.0 : 386.0;
      final ly = spot.ly;
      final lead = Paint()
        ..style = PaintingStyle.stroke
        ..color = ct.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      // dashed lead
      var d = 0.0;
      final leadPath = Path()
        ..moveTo(x1 + dx, ly)
        ..lineTo(x2, ly);
      for (final m in leadPath.computeMetrics()) {
        while (d < m.length) {
          canvas.drawPath(m.extractPath(d, math.min(d + 2, m.length)), lead);
          d += 5;
        }
      }

      // shapes (+ pulse glow for alert levels)
      for (final sh in spot.shapes) {
        final moved = sh.shift(Offset(dx, 0));
        if (pulseAlpha > 0) {
          canvas.drawPath(moved, Paint()..color = ct.withValues(alpha: pulseAlpha));
        }
        canvas.drawPath(moved, fill);
        canvas.drawPath(moved, stroke);
      }
      for (final sh in spot.lineShapes) {
        canvas.drawPath(sh.shift(Offset(dx, 0)), stroke);
      }

      // tag
      final tagx = spot.side == 'L' ? 6.0 : 368.0;
      final tagRect = Rect.fromLTWH(tagx, ly - 17, 92, 34);
      canvas.drawRRect(
          RRect.fromRectAndRadius(tagRect, const Radius.circular(1)),
          Paint()..color = const Color(0xDB060F19));
      canvas.drawRRect(
          RRect.fromRectAndRadius(tagRect, const Radius.circular(1)),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = ct
            ..strokeWidth = 1);
      final name = organDef(spot.organId).name.split(' ')[0];
      _tagText(canvas, name.toUpperCase(), tagx + 8, ly - 3, 10, p.fg);
      _tagText(canvas, values[spot.organId] ?? '', tagx + 8, ly + 12, 14, ct, w: FontWeight.w600);
      paintStatusShape(canvas, Offset(tagx + 79, ly - 5), 14, l, p);
    }

    canvas.restore();
  }

  void _tagText(Canvas canvas, String s, double x, double y, double size, Color color,
      {FontWeight w = FontWeight.w500}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: AVText.displayStyle(size, w: w, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y - tp.height));
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.scanY != scanY ||
      old.ringAngle != ringAngle ||
      old.pulse != pulse ||
      old.selected != selected ||
      old.levels != levels ||
      old.values != values ||
      old.palette != palette;
}
