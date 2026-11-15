/// App shell - port of the chrome: `.app` column (max 1500px) with header,
/// demo controls bar, mode bar, then the 218px sidebar + content grid and the
/// footer. Background carries the grid + radial glow of the reference design.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/contract/fields.dart';
import '../../core/data/app_state.dart';
import '../../core/engine/engine.dart';
import '../widgets/common.dart';
import '../widgets/status_icon.dart';
import '../../core/contract/models.dart' show kEnvProfiles;
import 'data_page.dart';
import 'drawer.dart';
import 'emergency_page.dart';
import 'overview_page.dart';
import 'overlays.dart';
import 'progress_page.dart';

class Shell extends StatefulWidget {
  final AppState st;
  const Shell({super.key, required this.st});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Timer? _clock;
  String _clockText = '--:--';

  @override
  void initState() {
    super.initState();
    _tick();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) => _tick());
  }

  void _tick() {
    final d = DateTime.now();
    setState(() {
      _clockText =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final st = widget.st;
    final wide = MediaQuery.of(context).size.width > 900;
    final showTier3 = st.evaluate().any((a) => a.tier == 3 && st.ack[a.id] != true && st.shown[a.id] != true);
    final showTier4 = st.evaluate().any((a) => a.tier == 4 && st.ack[a.id] != true);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          body: AVBackground(
            palette: p,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(context, st, !wide),
                      const SizedBox(height: 14),
                      _demoBar(context, st),
                      if (st.mode != DisplayMode.normal) ...[
                        const SizedBox(height: 14),
                        _modeBar(context, st),
                      ],
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (wide) ...[_sidebar(context, st), const SizedBox(width: 14)],
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!wide) _tabsRow(context, st),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: MediaQuery.of(context).size.height - 200),
                                      child: _view(context, st),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _footer(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!st.sel.isNone) DetailDrawer(st: st, rebuild: () => st.notifyChange()),
        if (showTier3 && st.urgId == null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.78),
              child: AlertModal(st: st),
            ),
          ),
        if (showTier4)
          Positioned.fill(child: UrgentScreen(st: st)),
        if (st.toastMsg != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: _Toast(msg: st.toastMsg!.msg, onUndo: st.toastMsg!.undo != null ? st.runUndo : null),
              ),
            ),
          ),
      ],
    );
  }

  Widget _view(BuildContext context, AppState st) {
    switch (st.tab) {
      case 'overview':
        return OverviewPage(st: st, rebuild: () => st.notifyChange());
      case 'progress':
        return ProgressPage(st: st);
      case 'aid':
        return EmergencyPage(st: st);
      default:
        return DataPage(pageId: st.tab, st: st, rebuild: () => st.notifyChange());
    }
  }

  /// header row: brand | SOS button + clock + profile chip
  Widget _header(BuildContext context, AppState st, bool narrow) {
    final p = avp(context);
    final compact = MediaQuery.of(context).size.width < 640;
    final night = st.mode == DisplayMode.night;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _brandLogo(p),
        const SizedBox(width: 12),
        Flexible(
          child: Text('ASTROVITALS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AVText.displayStyle(22, w: FontWeight.w600, color: p.fg, ls: 2.64)),
        ),
        const Spacer(),
        // SOS: .sosbtn{min-height:46px;padding:0 18px;border-radius:999px;bg:t4;font:600 15px}
        Material(
          color: night ? const Color(0xFF5C211B) : p.tierC(4),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => st.setTab('aid'),
            child: Container(
              height: 46,
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(18, 18),
                    painter: _CrossPainter(night ? const Color(0xFFE8C4B8) : Colors.white),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    Text('Emergency guide',
                        style: AVText.bodyStyle(15,
                            w: FontWeight.w600,
                            color: night ? const Color(0xFFE8C4B8) : Colors.white)),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // clock: b{font:500 24px/1 display} span{12px muted}
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_clockText, style: AVText.displayStyle(24, w: FontWeight.w500, color: p.fg, height: 1)),
                if (!compact)
                  Text('Mission day ${st.day} of ${st.env.total} · ${st.env.n}',
                      softWrap: false,
                      maxLines: 1,
                      style: AVText.bodyStyle(12, color: p.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(child: _profileChip(context, st, compact)),
      ],
    );
  }

  Widget _brandLogo(AVPalette p) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: p.blue, width: 1.5),
      ),
      child: CustomPaint(painter: _LogoPainter(p.blue, p.tierT(0))),
    );
  }

  /// profile chip (.pchip): avatar 40 + name/role on a surf2 pill
  Widget _profileChip(BuildContext context, AppState st, bool compact) {
    final p = avp(context);
    return Material(
      color: p.surf2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _profileDialog(context, st),
        child: Container(
          height: 46,
          padding: const EdgeInsets.fromLTRB(3, 3, 14, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFF5AAEE8), shape: BoxShape.circle),
                child: Text(
                  st.profileName
                      .trim()
                      .split(RegExp(r'\s+'))
                      .map((w) => w.isNotEmpty ? w[0] : '')
                      .take(2)
                      .join()
                      .toUpperCase(),
                  style: AVText.displayStyle(16, w: FontWeight.w600, color: const Color(0xFF06121D)),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(st.profileName,
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg, height: 1.2)),
                    Text(st.profileRole,
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AVText.bodyStyle(12, color: p.muted, height: 1.2)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// sidebar (.side, 218px column with .tabs + sync note)
  Widget _sidebar(BuildContext context, AppState st) {
    final p = avp(context);
    return Container(
      width: 218,
      padding: const EdgeInsets.only(top: 0, bottom: 12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._navItems(context, st, vertical: true),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: Text(
                'Saved on this device · ${st.syncPending} waiting to send${st.dnd ? ' · Do not disturb' : ''}',
                style: AVText.bodyStyle(12.5, color: p.muted, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabsRow(BuildContext context, AppState st) {
    return SizedBox(
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: Row(children: _navItems(context, st, vertical: false)),
      ),
    );
  }

  List<Widget> _navItems(BuildContext context, AppState st, {required bool vertical}) {
    final p = avp(context);
    const nav = <(String, String)>[
      ('lbl', 'Every day'),
      ('overview', 'Today'),
      ('checkin', 'Check-in'),
      ('lbl', 'Your data'),
      ('vit', 'Vitals'),
      ('cabin', 'Cabin and mission'),
      ('lbl', 'Records'),
      ('med', 'Medical'),
      ('mind', 'Mind and focus'),
      ('lbl', 'Journey'),
      ('progress', 'Progress'),
    ];
    final items = <Widget>[];
    for (final (kind, label) in nav) {
      if (kind == 'lbl') {
        if (!vertical) continue;
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text(label.toUpperCase(),
              style: AVText.bodyStyle(12.5, w: FontWeight.w500,
                  color: p.muted.withValues(alpha: 0.85), height: 1.2)),
        ));
        continue;
      }
      final selected = st.tab == kind;
      Widget? badge;
      if (kind == 'checkin') {
        badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? const Color(0x661B0E00) : p.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('${st.tasksDone}/${kTasks.length}',
              style: AVText.displayStyle(11, w: FontWeight.w600,
                  color: selected ? const Color(0xFF06121D) : p.holo)),
        );
      } else if (kPages.any((pg) => pg.id == kind)) {
        final pl = st.pageLevelOf(kind);
        if (pl > 0 && !(st.dnd && tierOf(pl) < 3)) {
          badge = StatusIcon(pl, size: 14);
        }
      }
      final icon = switch (kind) {
        'overview' => Icons.grid_view_outlined,
        'checkin' => Icons.checklist_rounded,
        'vit' => Icons.monitor_heart_outlined,
        'cabin' => Icons.airline_seat_individual_suite_outlined,
        'med' => Icons.description_outlined,
        'mind' => Icons.self_improvement_outlined,
        'progress' => Icons.route_outlined,
        _ => Icons.circle_outlined,
      };
      items.add(Padding(
        padding: EdgeInsets.symmetric(vertical: vertical ? 3 : 0, horizontal: vertical ? 8 : 0),
        child: Material(
          color: selected ? p.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => st.setTab(kind),
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: vertical ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Icon(icon, size: 18,
                      color: selected ? const Color(0xFF06121D) : p.muted),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AVText.bodyStyle(16, w: FontWeight.w500,
                            color: selected ? const Color(0xFF06121D) : p.muted)),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    badge,
                  ],
                ],
              ),
            ),
          ),
        ),
      ));
    }
    return items;
  }

  /// demo controls bar (.demobar): blue-tinted card with title + selects
  Widget _demoBar(BuildContext context, AppState st) {
    final p = avp(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: p.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.blue.withValues(alpha: 0.28)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Demo controls', style: AVText.displayStyle(14, w: FontWeight.w600, color: p.fg)),
                Text('Switch the scenario, mission location and display mode',
                    style: AVText.bodyStyle(12.5, color: p.muted, height: 1.35)),
              ],
            ),
          ),
          AVSelect<String>(
            label: 'Location',
            minWidth: 190,
            value: st.envKey,
            items: [for (final e in kEnvProfiles) (e.key, e.n)],
            onChanged: (v) {
              if (v != null) st.setEnv(v);
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Display', style: AVText.bodyStyle(12, w: FontWeight.w500, color: p.muted)),
              const SizedBox(height: 4),
              AVSegment(
                options: const [
                  ('normal', 'Normal'),
                  ('night', 'Night'),
                  ('eva', 'EVA'),
                ],
                value: st.mode.name,
                onChanged: (v) {
                  st.setMode(DisplayMode.values.firstWhere((m) => m.name == v));
                },
              ),
            ],
          ),
          AVSelect<String>(
            label: 'Demo data',
            minWidth: 190,
            value: st.scenKey,
            items: const [
              ('nominal', 'Nominal day'),
              ('sleep', 'Strained week'),
              ('spe', 'Solar storm'),
              ('air', 'Cabin air event (urgent alert)'),
            ],
            onChanged: (v) {
              if (v != null) st.setScen(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _modeBar(BuildContext context, AppState st) {
    final p = avp(context);
    final eva = st.mode == DisplayMode.eva;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: eva ? const Color(0xFFF2F6FA) : p.blue.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: eva ? null : Border.all(color: p.blue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(eva ? 'EVA mode' : 'Night mode',
              style: AVText.displayStyle(16, w: FontWeight.w600,
                  color: eva ? const Color(0xFF06121D) : p.fg)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              eva
                  ? 'Only urgent alerts come through. Bigger targets, fewer panels. Everything else waits for your post-EVA summary.'
                  : 'Dimmed for the sleep period. Smaller items are held for your morning summary. Urgent alerts always come through.',
              style: AVText.bodyStyle(15, color: eva ? const Color(0xFF06121D) : p.fg),
            ),
          ),
          const SizedBox(width: 12),
          AVButton(
            eva ? 'Exit EVA mode' : 'Back to normal',
            small: true,
            ghost: !eva,
            onPressed: () => st.setMode(DisplayMode.normal),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final p = avp(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Text(
          'AstroVitals supports self-checks and does not replace your flight surgeon. Data shown is a demo.',
          style: AVText.bodyStyle(12, color: p.muted),
        ),
      ),
    );
  }

  void _profileDialog(BuildContext context, AppState st) {
    final p = avp(context);
    final nameCtrl = TextEditingController(text: st.profileName);
    final roleCtrl = TextEditingController(text: st.profileRole);
    String? nameError, roleError;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: p.panelSolid,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: p.blue),
          ),
          title: Text('Your profile', style: AVText.displayStyle(20, w: FontWeight.w600, color: p.fg)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name', style: AVText.bodyStyle(12, color: p.muted)),
              AVTextField(
                controller: nameCtrl,
                maxLength: 40,
                error: nameError != null,
                onChanged: (v) => setD(() => nameError = validateNameError(v)),
              ),
              ErrorText(nameError),
              const SizedBox(height: 8),
              Text('Role', style: AVText.bodyStyle(12, color: p.muted)),
              AVTextField(
                controller: roleCtrl,
                maxLength: 40,
                error: roleError != null,
                onChanged: (v) => setD(() => roleError = validateRoleError(v)),
              ),
              ErrorText(roleError),
              Text('Saved on this device. Used to greet you and to sign the messages you send to the flight surgeon.',
                  style: AVText.bodyStyle(12, color: p.muted)),
            ],
          ),
          actions: [
            Row(
              children: [
                AVButton('Sign out', small: true, ghost: true, onPressed: () {
                  Navigator.pop(ctx);
                  st.signOut();
                }),
                const Spacer(),
                AVButton('Cancel', small: true, ghost: true, onPressed: () => Navigator.pop(ctx)),
                const SizedBox(width: 8),
                AVButton('Save', small: true,
                    onPressed: nameError == null && roleError == null && nameCtrl.text.trim().isNotEmpty
                        ? () {
                            st.saveProfile(nameCtrl.text, roleCtrl.text);
                            Navigator.pop(ctx);
                          }
                        : null),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String validateNameError(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Enter your name.';
  if (t.length > 40) return 'Keep the name under 40 characters.';
  return '';
}

String validateRoleError(String v) {
  if (v.trim().length > 40) return 'Keep the role under 40 characters.';
  return '';
}

/// the design's body background: 44px grid lines + radial glow
class AVBackground extends StatelessWidget {
  final AVPalette palette;
  final Widget child;
  const AVBackground({super.key, required this.palette, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: palette.bg),
      child: CustomPaint(
        painter: _AVBackgroundPainter(palette),
        child: child,
      ),
    );
  }
}

class _AVBackgroundPainter extends CustomPainter {
  final AVPalette p;
  _AVBackgroundPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF8CBEEB).withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // radial glow: 1100x760 at 50% 30%
    final center = Offset(size.width * 0.5, size.height * 0.30);
    const radiusBig = 550.0, radiusSmall = 380.0;
    final rect = Rect.fromCenter(center: center, width: radiusBig * 2, height: radiusSmall * 2);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [p.bgGlow.withValues(alpha: 0.85), p.bgGlow.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glow);
    // soften: paint bg over the far edges (72% stop feel)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [Colors.transparent, p.bg],
          stops: const [0.62, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AVBackgroundPainter old) => old.p != p;
}

/// filled medical cross used in the SOS button (design svg: M8 3h4v5h5v4h-5v5H8v-5H3V8h5z)
class _CrossPainter extends CustomPainter {
  final Color color;
  _CrossPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final arm = s * 0.25; // 5/20
    final mid = s / 2;
    final path = Path()
      ..moveTo(mid - arm / 2, s * 0.15)
      ..lineTo(mid + arm / 2, s * 0.15)
      ..lineTo(mid + arm / 2, mid - arm / 2)
      ..lineTo(s * 0.85, mid - arm / 2)
      ..lineTo(s * 0.85, mid + arm / 2)
      ..lineTo(mid + arm / 2, mid + arm / 2)
      ..lineTo(mid + arm / 2, s * 0.85)
      ..lineTo(mid - arm / 2, s * 0.85)
      ..lineTo(mid - arm / 2, mid + arm / 2)
      ..lineTo(s * 0.15, mid + arm / 2)
      ..lineTo(s * 0.15, mid - arm / 2)
      ..lineTo(mid - arm / 2, mid - arm / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color;
}

class _LogoPainter extends CustomPainter {
  final Color ring;
  final Color pulse;
  _LogoPainter(this.ring, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.42,
        Paint()..style = PaintingStyle.stroke..color = ring..strokeWidth = 1.5);
    final path = Path()
      ..moveTo(s * 0.13, s * 0.53)
      ..lineTo(s * 0.34, s * 0.53)
      ..lineTo(s * 0.42, s * 0.35)
      ..lineTo(s * 0.55, s * 0.71)
      ..lineTo(s * 0.63, s * 0.53)
      ..lineTo(s * 0.87, s * 0.53);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = pulse
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.ring != ring || old.pulse != pulse;
}

class _Toast extends StatelessWidget {
  final String msg;
  final VoidCallback? onUndo;
  const _Toast({required this.msg, this.onUndo});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: p.raise,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg, style: AVText.bodyStyle(14, color: p.fg)),
          if (onUndo != null) ...[
            const SizedBox(width: 14),
            GestureDetector(
              onTap: onUndo,
              child: Text('Undo',
                  style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.holo)
                      .copyWith(decoration: TextDecoration.underline)),
            ),
          ],
        ],
      ),
    );
  }
}
