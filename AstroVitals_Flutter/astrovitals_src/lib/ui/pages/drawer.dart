/// Detail drawer - port of detailHTML()/indDrawer(): opens as a right-side
/// panel at every width, shows the tapped indicator or organ.
library;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/contract/fields.dart';
import '../../core/contract/models.dart';
import '../../core/contract/zones.dart';
import '../../core/data/app_state.dart';
import '../../core/engine/engine.dart';
import '../../core/engine/levels_text.dart' show observationText;
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/sparkline.dart';
import '../widgets/status_icon.dart';

class DetailDrawer extends StatelessWidget {
  final AppState st;
  final VoidCallback rebuild;
  const DetailDrawer({super.key, required this.st, required this.rebuild});

  @override
  Widget build(BuildContext context) {
    if (st.sel.isNone) return const SizedBox.shrink();
    final close = AVButton('Close', small: true, ghost: true, onPressed: st.clearSelection);

    // indicator drawer
    if (st.sel.t == 'ind') {
      return _IndDrawer(id: st.sel.id, close: close, st: st);
    }

    // organ drawer
    final o = organDef(st.sel.id);
    final l = st.organLevels[o.id] ?? 0;
    if (o.ind.length == 1) {
      return _IndDrawer(id: o.ind[0], close: close, st: st, titleOverride: o.name);
    }
    final p = avp(context);
    final why = <Widget>[];
    final acts = <String>[];
    for (final id in o.ind) {
      final jj = st.evaluate().isEmpty
          ? lv(st.makeCtx(), id)
          : lv(st.makeCtx(), id);
      if (jj > 0) {
        why.add(Text(observationText(id, st.makeCtx()), style: AVText.bodyStyle(15, color: p.fg)));
        final actsList = kInfo[id]!.act[jj <= 2 ? 1 : 2]!;
        acts.addAll(actsList.take(2));
      }
    }
    return DrawerScaffold(
      children: [
        Row(
          children: [
            Expanded(child: Text(o.name, style: AVText.displayStyle(18, w: FontWeight.w600, color: p.fg))),
            TierChip(l),
            const SizedBox(width: 8),
            close,
          ],
        ),
        SectionTitle('Your numbers'),
        for (final id in o.ind)
          _IndicatorBlock(id: id, st: st),
        if (why.isNotEmpty) ...[
          SectionTitle('Why'),
          ...why,
          SectionTitle('What to do'),
          for (final a in acts.toSet()) _StepLi(a),
        ] else ...[
          SectionTitle('Suggested step'),
          Text(o.prev, style: AVText.bodyStyle(15, color: p.fg)),
        ],
        Accordion('Learn more', children: [
          Text('What it does', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg)),
          Text(o.fn, style: AVText.bodyStyle(14, color: p.muted)),
          const SizedBox(height: 8),
          Text('Spaceflight hazard', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg)),
          Text(o.haz, style: AVText.bodyStyle(14, color: p.muted)),
        ]),
      ],
    );
  }
}

/// right-side drawer scaffold (matches the design's .drawer)
class DrawerScaffold extends StatelessWidget {
  final List<Widget> children;
  const DrawerScaffold({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => AVStore.of(context).clearSelection(),
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: p.panelSolid,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
            child: Container(
              width: mathMin2(380.0, MediaQuery.of(context).size.width * 0.92),
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String t;
  const SectionTitle(this.t, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(t, style: AVText.displayStyle(15, w: FontWeight.w600, color: p.holo)),
    );
  }
}

class _StepLi extends StatelessWidget {
  final String a;
  const _StepLi(this.a);
  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('· ', style: AVText.bodyStyle(15, color: p.muted)),
          Expanded(child: Text(a, style: AVText.bodyStyle(15, color: p.fg))),
        ],
      ),
    );
  }
}

double mathMin2(double a, double b) => a <= b ? a : b;

/// indDrawer port
class _IndDrawer extends StatelessWidget {
  final String id;
  final Widget close;
  final AppState st;
  final String? titleOverride;
  const _IndDrawer({required this.id, required this.close, required this.st, this.titleOverride});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final jj = lv(st.makeCtx(), id);
    final def = metricDef(id);
    final usual = usualText(st, id);
    final info = kInfo[id]!;
    return DrawerScaffold(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(titleOverride ?? def.name,
                  style: AVText.displayStyle(18, w: FontWeight.w600, color: p.fg)),
            ),
            TierChip(jj),
            const SizedBox(width: 8),
            close,
          ],
        ),
        SectionTitle('Your numbers'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(fmtVal(st, id),
                style: AVText.num(34, w: FontWeight.w600, color: p.tierT(jj))),
            const Spacer(),
            Sparkline(
              st.seriesFor(id),
              jj,
              baseline: kBase[def.key],
              big: true,
            ),
          ],
        ),
        if (usual.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(usual, style: AVText.bodyStyle(13.5, color: p.muted)),
          ),
        RangeBar(metricId: id, value: _rangeValue(st, id), level: jj),
        SectionTitle('Last 14 days'),
        _StatTiles(id: id, st: st),
        if (jj > 0) ...[
          SectionTitle('Why'),
          Text(observationText(id, st.makeCtx()), style: AVText.bodyStyle(15, color: p.fg)),
          const SizedBox(height: 4),
          Text(info.space, style: AVText.bodyStyle(14, color: p.muted)),
          SectionTitle('What to do'),
          for (final a in info.act[jj <= 2 ? 1 : 2]!) _StepLi(a),
        ] else ...[
          SectionTitle('Suggested step'),
          Text(kTips[id] ?? '', style: AVText.bodyStyle(15, color: p.fg)),
        ],
        Accordion('Learn more', children: [
          Text('Why we measure it', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg)),
          Text(info.why, style: AVText.bodyStyle(14, color: p.muted)),
          const SizedBox(height: 8),
          Text('How to measure', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg)),
          for (final h in info.how) _StepLi(h),
          const SizedBox(height: 8),
          Text('Talk to the flight surgeon if', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg)),
          Text(info.esc, style: AVText.bodyStyle(14, color: p.muted)),
        ]),
      ],
    );
  }
}

double _rangeValue(AppState st, String id) {
  if (id == 'bp') return st.cur['sys'];
  if (id == 'rad') return st.cur['radTotal'] / st.env.limit * 100;
  if (id == 'mass') {
    return (st.cur['mass'] - (kBase['mass'] ?? 74)) / (kBase['mass'] ?? 74) * 100;
  }
  return st.cur[metricDef(id).key];
}

class _IndicatorBlock extends StatelessWidget {
  final String id;
  final AppState st;
  const _IndicatorBlock({required this.id, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final jj = lv(st.makeCtx(), id);
    final def = metricDef(id);
    final statsAvg = st.seriesFor(id).isEmpty
        ? null
        : st.seriesFor(id).fold<double>(0, (t, v) => t + v) / st.seriesFor(id).length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.lineSoft))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusIcon(jj, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(def.name, style: AVText.bodyStyle(14.5, w: FontWeight.w500, color: p.fg))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(fmtVal(st, id),
                  style: AVText.num(28, w: FontWeight.w600, color: p.tierT(jj))),
              const Spacer(),
              Sparkline(st.seriesFor(id), jj, big: false, width: 120, height: 44),
            ],
          ),
          Text(
              '${usualText(st, id)}${statsAvg != null ? ' · Average ${svVal(st, id, statsAvg)}' : ''}',
              style: AVText.bodyStyle(13.5, color: p.muted)),
        ],
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  final String id;
  final AppState st;
  const _StatTiles({required this.id, required this.st});

  @override
  Widget build(BuildContext context) {
    final a = st.seriesFor(id);
    if (a.length < 2) return const SizedBox.shrink();
    final avg = a.fold<double>(0, (t, v) => t + v) / a.length;
    final mn = a.reduce((x, y) => x < y ? x : y);
    final mx = a.reduce((x, y) => x > y ? x : y);
    return Row(
      children: [
        Expanded(child: _tile(context, 'Average', svVal(st, id, avg))),
        const SizedBox(width: 8),
        Expanded(child: _tile(context, 'Lowest', svVal(st, id, mn))),
        const SizedBox(width: 8),
        Expanded(child: _tile(context, 'Highest', svVal(st, id, mx))),
      ],
    );
  }

  Widget _tile(BuildContext context, String label, String value) {
    final p = avp(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(label, style: AVText.bodyStyle(12.5, color: p.muted)),
          Text(value, style: AVText.num(17, color: p.fg)),
        ],
      ),
    );
  }
}
