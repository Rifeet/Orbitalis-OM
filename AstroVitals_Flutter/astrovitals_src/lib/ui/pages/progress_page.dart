/// Progress page - port of progressView(): journey rail, health log streak,
/// mission badges, hazards accordion and the 14-day health index chart.
library;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/contract/fields.dart';
import '../../core/contract/models.dart' show EnvProfile;
import '../../core/data/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/status_icon.dart';

class ProgressPage extends StatelessWidget {
  final AppState st;
  const ProgressPage({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final e = st.env;
    final sd = st.streakDays;
    final r = (st.day / e.total * 100).round();

    const badges = [
      ['Sleep Logger', 'Keeps the sleep record complete', 'Sleep logged 7 nights in a row', 5, 7, 'nights'],
      ['Morning Vitals', 'Keeps the flight surgeon’s baseline current', 'Morning heart rate and blood pressure recorded for 30 days', 22, 30, 'days'],
      ['Mood Mapper', 'Awareness of mental health', 'Mood logged for 60 days', 38, 60, 'days'],
      ['Hydration Log', 'Keeps the fluid record complete', 'Drinks logged every day for 14 days', 9, 14, 'days'],
      ['Radiation Aware', 'Awareness of exposure', 'Dose tracked daily for 90 days', -2, 90, 'days'],
      ['Mission Halfway', 'Reached the middle of the mission', 'Check-in done on 80% of days, first half of the mission', -3, -1, 'days'],
      ['Full Mission', 'The whole journey', 'Check-in done on 90% of days, whole mission', -4, -5, 'days'],
    ];

    int cur(int idx) {
      final b = badges[idx];
      if (idx == 4) return st.day < 90 ? st.day : 90;
      if (idx == 5) return st.day < (e.total / 2).ceil() ? st.day : (e.total / 2).ceil();
      if (idx == 6) return st.day;
      return b[3] as int;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 900;
            final journey = _journeyPanel(context, r);
            final streak = _streakPanel(context, sd);
            return Column(
              children: [
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: journey),
                      const SizedBox(width: 14),
                      Expanded(child: streak),
                    ],
                  )
                else ...[journey, const SizedBox(height: 14), streak],
              ],
            );
          }),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelHead('Mission badges', small: 'Earned by logging, never by your numbers'),
                Text(
                    'A worrying reading never costs you progress. Report it honestly: that is what keeps you safe.',
                    style: AVText.bodyStyle(14, color: p.muted)),
                const SizedBox(height: 10),
                for (var i = 0; i < badges.length; i++)
                  _badgeRow(context, badges[i], cur(i)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelHead('Spaceflight hazards', small: 'What your log protects against'),
                for (final z in kHazards)
                  _hazard(context, z),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            child: HealthBarsChart(st.indexSeries),
          ),
        ],
      ),
    );
  }

  Widget _journeyPanel(BuildContext context, int r) {
    final p = avp(context);
    final e = st.env;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHead('Journey', small: e.n),
          TrajRail(r: r, env: e, day: st.day),
          const SizedBox(height: 10),
          Text(
              'The marker shows the real mission clock: day ${st.day} of ${e.total}. Your logging streak is tracked separately, so a missed check-in never moves the vehicle.',
              style: AVText.bodyStyle(14, color: p.muted)),
        ],
      ),
    );
  }

  Widget _streakPanel(BuildContext context, int sd) {
    final p = avp(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHead('Health log streak', small: '$sd days'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < 13; i++)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 6 ? Colors.transparent : p.blue,
                    border: Border.all(
                        color: i == 6 ? p.muted : p.blue,
                        width: 2,
                      ),
                    ),
                ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: st.todayDone ? p.blue : p.holo,
                      width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('A missed day pauses the streak. It never resets. We follow consistency, not perfection.',
              style: AVText.bodyStyle(14, color: p.muted)),
        ],
      ),
    );
  }

  Widget _badgeRow(BuildContext context, List<dynamic> b, int cur) {
    final p = avp(context);
    final target = b[4] as int;
    final done = cur >= target;
    final pct = (cur / target * 100).round().clamp(0, 100);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.lineSoft))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b[0] as String,
                    style: AVText.displayStyle(14, w: FontWeight.w600, color: p.fg)),
                Text(b[1] as String, style: AVText.bodyStyle(12, color: p.muted)),
              ],
            ),
          ),
          Expanded(
            flex: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b[2] as String, style: AVText.bodyStyle(12, color: p.muted)),
                const SizedBox(height: 6),
                AVMeter(pct.toDouble()),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(done ? 'Earned' : '$cur of $target',
                    style: AVText.num(14,
                        color: done ? p.tierT(0) : p.fg)),
                if (!done) Text(b[5] as String, style: AVText.bodyStyle(12, color: p.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hazard(BuildContext context, HazardDef z) {
    final l = st.hzLevelOf(z.id);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        iconColor: p_(context).muted,
        collapsedIconColor: p_(context).muted,
        title: Row(
          children: [
            StatusIcon(l, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(z.n, style: AVText.bodyStyle(15, w: FontWeight.w500, color: p_(context).fg))),
          ],
        ),
        children: [
          Text(z.blurb, style: AVText.bodyStyle(14, color: p_(context).muted)),
          const SizedBox(height: 8),
          Text('How we reduce this risk', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p_(context).fg)),
          for (final c in z.cut)
            Text('· $c', style: AVText.bodyStyle(14, color: p_(context).muted)),
        ],
      ),
    );
  }
}

AVPalette p_(BuildContext c) => avp(c);

/// journey rail (trajInner port)
class TrajRail extends StatelessWidget {
  final int r;
  final EnvProfile env;
  final int day;
  const TrajRail({super.key, required this.r, required this.env, required this.day});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(env.endA, style: AVText.displayStyle(13, w: FontWeight.w500, color: p.muted)),
            const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final railW = box.maxWidth;
                return SizedBox(
                  height: 20,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(height: 6, color: Colors.white.withValues(alpha: 0.1)),
                      FractionallySizedBox(
                        widthFactor: r / 100,
                        child: Container(height: 6, color: p.blue),
                      ),
                      Positioned(
                        left: (railW * r / 100 - 8).clamp(0.0, railW - 16),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.bg,
                            border: Border.all(color: p.holo, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(width: 12),
            Text(env.endB, style: AVText.displayStyle(13, w: FontWeight.w500, color: p.muted)),
          ],
        ),
        const SizedBox(height: 6),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Day ', style: AVText.bodyStyle(12, color: p.muted)),
          TextSpan(text: '$day/${env.total}', style: AVText.num(12, color: p.fg)),
        ])),
      ],
    );
  }
}
