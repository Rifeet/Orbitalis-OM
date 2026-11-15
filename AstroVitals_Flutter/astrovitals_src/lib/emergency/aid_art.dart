/// Line-art first-aid illustrations for the three procedures that are not in
/// emergency.docx (Severe bleeding / Hard to breathe / Solar storm) - port of
/// the design's SC scene functions as CustomPaint primitives.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../app_theme.dart';

enum PrimKind { line, circle, rect, polyline, path, text }

class Prim {
  final PrimKind kind;
  final List<double> xy;
  final String cls; // p patient | r rescuer | a action | f frame | h head | tx text
  final String text;
  final bool fillShape;
  Prim(this.kind, this.xy, this.cls, {this.text = '', this.fillShape = false});
  factory Prim.line(List<double> xy, String cls, {String text = '', bool fillShape = false}) =>
      Prim(PrimKind.line, xy, cls, text: text, fillShape: fillShape);
  factory Prim.circle(double cx, double cy, double r, String cls) =>
      Prim(PrimKind.circle, [cx, cy, r], cls);
  factory Prim.rect(double x, double y, double w, double h, String cls, {double rx = 3}) =>
      Prim(PrimKind.rect, [x, y, w, h, rx], cls);
  factory Prim.polyline(List<double> pts, String cls) =>
      Prim(PrimKind.polyline, pts, cls);
  factory Prim.text(String text, double x, double y, String cls) =>
      Prim(PrimKind.text, [x, y], cls, text: text);
}

typedef Scene = List<Prim>;

const double vbW = 160, vbH = 110;

// ---------- primitive builders (port of ln/hd/pl/arr/floor/lying/standing) ----------
Prim _ln(double a, double b, double c, double d, [String k = 'p']) => Prim.line([a, b, c, d], k);
Prim _hd(double x, double y, [String k = 'p']) => Prim.circle(x, y, 7, 'h$k');
Prim _pl(List<double> pts, [String k = 'p']) => Prim.polyline(pts, k);
Prim _floor() => _ln(8, 92, 152, 92, 'f');

List<Prim> _arrow(double a, double b, double c, double d) {
  final ang = math.atan2(d - b, c - a);
  const s = 6.0;
  return [
    _ln(a, b, c, d, 'a'),
    _pl([
      c - s * math.cos(ang - .5), d - s * math.sin(ang - .5),
      c, d,
      c - s * math.cos(ang + .5), d - s * math.sin(ang + .5),
    ], 'a'),
  ];
}

List<Prim> _lying({bool legsUp = false}) {
  final s = <Prim>[_hd(30, 84), _ln(38, 86, 86, 86)];
  if (legsUp) {
    s.add(_ln(86, 86, 104, 62));
    s.add(_ln(86, 86, 108, 70));
    s.add(Prim.rect(102, 76, 16, 16, 'f'));
  } else {
    s.add(_ln(86, 86, 124, 86));
    s.add(_ln(86, 86, 124, 89));
  }
  s.add(_ln(46, 86, 60, 92));
  s.add(_floor());
  return s;
}

List<Prim> _standing(double x, [String k = 'p']) => [
      _hd(x, 26, k),
      _ln(x, 33, x, 64, k),
      _ln(x, 64, x - 9, 92, k),
      _ln(x, 64, x + 9, 92, k),
    ];

// ---------- scenes ----------
List<Prim> scCheck() => [
      ..._lying(),
      _hd(26, 48, 'r'),
      _ln(33, 52, 52, 66, 'r'),
      ..._arrow(40, 40, 32, 76),
      _pl([18, 62, 14, 66, 18, 70], 'a'),
      _pl([10, 60, 4, 66, 10, 72], 'a'),
      Prim.text('Look · listen · feel', 100, 40, 'tx'),
    ];

List<Prim> scCall() => [
      ..._standing(60, 'r'),
      _ln(60, 42, 84, 34, 'r'),
      _ln(60, 42, 44, 56, 'r'),
      Prim.rect(82, 22, 16, 26, 'a'),
      _pl([104, 28, 110, 35, 104, 42], 'a'),
      _pl([110, 22, 120, 35, 110, 48], 'a'),
      Prim.text('Call', 132, 75, 'tx'),
      _floor(),
    ];

List<Prim> scSit() => [
      _hd(56, 30),
      _ln(58, 38, 68, 70),
      _pl([68, 70, 100, 70, 104, 92]),
      _ln(68, 70, 56, 92),
      _ln(62, 50, 82, 60),
      _ln(62, 50, 48, 62),
      Prim.rect(40, 70, 40, 6, 'f'),
      _floor(),
      Prim.text('Rest', 124, 40, 'tx'),
    ];

List<Prim> scClock() => [
      Prim.circle(80, 52, 30, 'a'),
      _ln(80, 52, 80, 34, 'a'),
      _ln(80, 52, 94, 58, 'a'),
      Prim.text('Track every few minutes', 80, 102, 'tx'),
    ];

List<Prim> scCompress() => [
      ..._lying(),
      _hd(40, 34, 'r'),
      _ln(44, 42, 56, 62, 'r'),
      _ln(56, 62, 56, 80, 'r'),
      _ln(52, 52, 60, 78, 'r'),
      ..._arrow(60, 40, 60, 66),
      Prim.text('100–120 / min', 110, 40, 'tx'),
    ];

List<Prim> scBreath() => [
      ..._lying(),
      _hd(26, 56, 'r'),
      _pl([34, 62, 32, 76], 'r'),
      _pl([18, 66, 12, 70, 18, 74], 'a'),
      ..._arrow(8, 56, 14, 56),
      Prim.text('Tilt head · 2 breaths', 100, 40, 'tx'),
    ];

List<Prim> scAed() => [
      Prim.rect(44, 30, 72, 50, 'a', rx: 6),
      _pl([68, 56, 76, 44, 82, 66, 90, 52, 96, 56], 'a'),
      Prim.circle(62, 68, 4, 'a'),
      Prim.circle(98, 68, 4, 'a'),
      Prim.text('Follow the voice prompts', 80, 102, 'tx'),
    ];

List<Prim> scChoke() => [
      ..._standing(70),
      _hd(94, 26, 'r'),
      _ln(94, 33, 94, 64, 'r'),
      _ln(94, 64, 100, 92, 'r'),
      _ln(94, 64, 88, 92, 'r'),
      _ln(90, 44, 72, 54, 'r'),
      _ln(90, 44, 72, 52, 'r'),
      Prim.circle(72, 52, 4, 'a'),
      ..._arrow(78, 66, 64, 56),
      _floor(),
    ];

List<Prim> scBack() => [
      _hd(60, 32),
      _ln(62, 40, 76, 66),
      _ln(76, 66, 66, 92),
      _ln(76, 66, 86, 92),
      _ln(66, 48, 52, 60),
      _hd(98, 26, 'r'),
      _ln(98, 33, 98, 64, 'r'),
      _ln(98, 64, 92, 92, 'r'),
      _ln(98, 64, 106, 92, 'r'),
      _ln(96, 44, 78, 50, 'r'),
      ..._arrow(84, 34, 76, 48),
      _floor(),
    ];

List<Prim> scBleed() => [
      _ln(14, 70, 146, 70),
      _ln(14, 86, 146, 86),
      Prim.line([80, 56, 72, 66, 72, 72, 80, 72, 88, 72, 88, 66], 'a', fillShape: true),
      Prim.rect(62, 38, 36, 18, 'r'),
      ..._arrow(80, 14, 80, 36),
      Prim.text('Press hard', 130, 30, 'tx'),
    ];

List<Prim> scWrap() => [
      _ln(14, 56, 146, 56),
      _ln(14, 76, 146, 76),
      Prim.rect(56, 52, 14, 28, 'r'),
      Prim.rect(74, 52, 14, 28, 'r'),
      Prim.rect(92, 52, 14, 28, 'r'),
      ..._arrow(80, 20, 80, 46),
      Prim.text('Add layers, bandage firmly', 80, 102, 'tx'),
    ];

List<Prim> scMask() => [
      _hd(60, 40),
      _ln(60, 47, 60, 80),
      _ln(60, 80, 50, 100),
      _ln(60, 80, 70, 100),
      Prim.rect(64, 40, 14, 9, 'a'),
      _pl([78, 46, 96, 60, 96, 80], 'a'),
      Prim.circle(96, 86, 8, 'a'),
      Prim.text('Oxygen', 122, 30, 'tx'),
    ];

List<Prim> scMove() => [
      Prim.rect(10, 26, 48, 60, 'f', rx: 5),
      Prim.rect(102, 26, 48, 60, 'a', rx: 5),
      ..._arrow(62, 56, 98, 56),
      _hd(34, 50),
      _ln(34, 57, 34, 72),
      Prim.text('Bad air', 34, 100, 'tx'),
      Prim.text('Clean air', 126, 100, 'tx'),
    ];

List<Prim> scShelter() => [
      Prim.rect(48, 30, 64, 56, 'a', rx: 6),
      Prim.rect(54, 36, 52, 44, 'f', rx: 4),
      _hd(80, 52),
      _ln(80, 59, 80, 74),
      ..._arrow(8, 44, 44, 52),
      ..._arrow(8, 66, 44, 64),
      _ln(40, 40, 40, 76, 'a'),
      Prim.text('Shelter', 132, 62, 'tx'),
    ];

List<Prim> scAlarm() => [
      Prim.line([52, 76, 52, 40, 80, 24, 108, 40, 108, 76], 'a', fillShape: true),
      _ln(46, 76, 114, 76, 'a'),
      _ln(80, 24, 80, 32, 'a'),
      _ln(46, 38, 52, 44, 'a'),
      _ln(114, 38, 108, 44, 'a'),
      Prim.text('Stop work', 80, 102, 'tx'),
    ];

List<Prim> scLegs() => [
      ..._lying(legsUp: true),
      ..._arrow(122, 50, 122, 36),
      Prim.text('About 30 cm', 48, 44, 'tx'),
    ];

/// the three design procedures using these scenes
class DesignAid {
  final String id, name, sub;
  final List<(String, String, List<Prim> Function())> steps;
  const DesignAid(this.id, this.name, this.sub, this.steps);
}

const List<DesignAid> kDesignAids = [
  DesignAid('bleed', 'Severe bleeding', 'Blood that will not stop', [
    ('Protect yourself', 'Put on gloves. In microgravity, catch floating blood with absorbent pads.', scCall),
    ('Press directly on the wound', 'Use a clean cloth or gauze. Press firmly and keep pressing.', scBleed),
    ('Do not lift the cloth', 'If blood soaks through, add more layers on top and keep pressing.', scWrap),
    ('Bandage firmly', 'Wrap a pressure bandage over the pads. Raise the limb if you can.', scWrap),
    ('Call and watch for shock', 'Alert the flight surgeon. Pale, cold, fast pulse or confusion means shock. Keep them calm and lying down or restrained.', scLegs),
  ]),
  DesignAid('air', 'Hard to breathe', 'Breathlessness, headache or alarms for air quality', [
    ('Sit upright and stay calm', 'Slow, steady breaths. Stop all effort.', scSit),
    ('Alert the crew', 'Say “air quality” and check the CO₂, smoke and pressure alarms.', scAlarm),
    ('Use oxygen or a mask', 'Put on the emergency mask or oxygen as the procedure says.', scMask),
    ('Move to clean air', 'Go to a module with normal readings. Help anyone who cannot move.', scMove),
    ('Check SpO₂ and report', 'Read SpO₂ and heart rate every few minutes and tell the flight surgeon.', scClock),
  ]),
  DesignAid('storm', 'Solar storm alert', 'Radiation alarm or storm warning', [
    ('Stop work', 'Stop your task and listen for instructions.', scAlarm),
    ('Go to the shelter', 'Move to the shelter area with the most shielding. Bring your dosimeter.', scShelter),
    ('Stay until the all-clear', 'Do not leave until ground control or the commander says it is safe.', scClock),
    ('Check yourself', 'Note nausea, vomiting, headache or skin redness and log them in the symptom task.', scSit),
    ('Report', 'Send your dose reading and symptoms to the ground team.', scCall),
  ]),
];

/// painter for one scene
class AidArt extends StatelessWidget {
  final List<Prim> Function() scene;
  final double height;
  const AidArt({super.key, required this.scene, this.height = 110});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = w * vbH / vbW;
      return SizedBox(
        width: w,
        height: math.min(h, height * w / vbW),
        child: CustomPaint(
          painter: _AidArtPainter(prims: scene(), palette: p),
        ),
      );
    });
  }
}

class _AidArtPainter extends CustomPainter {
  final List<Prim> prims;
  final AVPalette palette;
  _AidArtPainter({required this.prims, required this.palette});

  Color _color(String cls) {
    final p = palette;
    if (cls.startsWith('h')) {
      final base = cls.substring(1);
      return base == 'r' ? p.blue : p.holo;
    }
    switch (cls) {
      case 'p':
        return p.holo;
      case 'r':
        return p.blue;
      case 'a':
        return p.tierT(3);
      case 'f':
        return p.line;
      case 'tx':
        return p.fg;
    }
    return p.holo;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sc = size.width / vbW;
    canvas.scale(sc, sc);
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, vbW, vbH),
        Paint()..color = Colors.black.withValues(alpha: 0.22));

    for (final pr in prims) {
      final paint = Paint()
        ..style = pr.fillShape ? PaintingStyle.fill : PaintingStyle.stroke
        ..color = _color(pr.cls)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      switch (pr.kind) {
        case PrimKind.line:
          if (pr.xy.length >= 4) {
            canvas.drawLine(Offset(pr.xy[0], pr.xy[1]), Offset(pr.xy[2], pr.xy[3]), paint);
          }
          break;
        case PrimKind.circle:
          if (pr.cls.startsWith('h')) {
            canvas.drawCircle(Offset(pr.xy[0], pr.xy[1]), pr.xy[2],
                Paint()..color = const Color(0xFF0D1F32));
          }
          canvas.drawCircle(Offset(pr.xy[0], pr.xy[1]), pr.xy[2],
              Paint()
                ..style = PaintingStyle.stroke
                ..color = _color(pr.cls)
                ..strokeWidth = 3.5);
          break;
        case PrimKind.rect:
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(pr.xy[0], pr.xy[1], pr.xy[2], pr.xy[3]),
                  Radius.circular(pr.xy.length > 4 ? pr.xy[4] : 3.0)),
              paint);
          break;
        case PrimKind.polyline:
        case PrimKind.path:
          final path = Path();
          for (var i = 0; i + 1 < pr.xy.length; i += 2) {
            if (i == 0) {
              path.moveTo(pr.xy[0], pr.xy[1]);
            } else {
              path.lineTo(pr.xy[i], pr.xy[i + 1]);
            }
          }
          canvas.drawPath(path, paint);
          break;
        case PrimKind.text:
          final tp = TextPainter(
            text: TextSpan(
                text: pr.text,
                style: AVText.bodyStyle(11, color: _color('tx'))),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          )..layout(maxWidth: 150);
          final anchor = pr.xy[0] > vbW / 2 ? pr.xy[0] - tp.width : pr.xy[0];
          tp.paint(canvas, Offset(anchor.clamp(0.0, 150 - tp.width), pr.xy[1] - 8));
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_AidArtPainter old) => old.prims != prims || old.palette != palette;
}
