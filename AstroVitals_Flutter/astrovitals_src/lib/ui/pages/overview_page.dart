/// Today page (overview) - port of overviewView(): frame line, body map stage,
/// status hero with alerts, today's check-in tasks and the "other pages"
/// numbers panel.
library;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/contract/fields.dart';
import '../../core/contract/models.dart';
import '../../core/contract/zones.dart' show kBase;
import '../../core/data/app_state.dart';
import '../../core/engine/engine.dart';
import '../widgets/body_map.dart';
import '../widgets/common.dart';
import '../widgets/status_icon.dart';
import 'data_page.dart' show mathMinInt;

class OverviewPage extends StatelessWidget {
  final AppState st;
  final VoidCallback rebuild;
  const OverviewPage({super.key, required this.st, required this.rebuild});

  @override
  Widget build(BuildContext context) {
    final all = st.evaluate();
    final vis = st.visibleAlerts;
    final wc = st.welcomed || st.mode != DisplayMode.normal ? null : _welcome(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wc != null) wc else _frameLine(context),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 900;
            final bodyW = wide ? mathMin2(480.0, box.maxWidth * 0.42) : box.maxWidth;
            final bodyMap = _bodyStage(context, bodyW);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: bodyW + 24),
                    child: bodyMap,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        HeroPanel(st: st, all: all, vis: vis),
                        const SizedBox(height: 14),
                        CheckinPanel(st: st, rebuild: rebuild),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                bodyMap,
                const SizedBox(height: 14),
                HeroPanel(st: st, all: all, vis: vis),
                const SizedBox(height: 14),
                CheckinPanel(st: st, rebuild: rebuild),
              ],
            );
          }),
          const SizedBox(height: 14),
          NumbersPanel(st: st),
        ],
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    final p = avp(context);
    final initials = st.profileName
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        // .welcome{background:color-mix(in srgb,var(--blue) 12%,var(--panel-solid))}
        color: Color.lerp(p.panelSolid, p.blue, 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFF5AAEE8), shape: BoxShape.circle),
            child: Text(initials,
                style: AVText.displayStyle(22, w: FontWeight.w600, color: const Color(0xFF06121D))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome to AstroVitals, ${st.profileName.split(' ').first}',
                    style: AVText.displayStyle(20, w: FontWeight.w600, color: p.fg)),
                const SizedBox(height: 4),
                Text(
                    'Your profile is set up, and 14 days of readings from your crew devices (demo data) are loaded, so your usual ranges are ready from today.',
                    style: AVText.bodyStyle(15, color: p.muted)),
                const SizedBox(height: 6),
                Text(
                    'Your usual: heart rate ${kBase['hr']!.round()} bpm · blood oxygen ${kBase['spo2']!.round()}% · sleep ${kBase['sleep']!.round().toString()} h',
                    style: AVText.bodyStyle(14, color: p.fg)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AVButton('Get started', small: true, onPressed: st.welcomeOk),
        ],
      ),
    );
  }

  Widget _frameLine(BuildContext context) {
    final p = avp(context);
    final e = st.env;
    final d = e.delayMin;
    final nm = e.n.replaceFirstMapped(RegExp(r'^(Space|Lunar|Transit)'),
        (m) => m.group(0)!.toLowerCase());
    final text = d < 1
        ? 'The ground team is a call away on the $nm. AstroVitals still turns every reading into a clear next step.'
        : '${e.delayLabel()} from the nearest doctor. On $nm, messages to the ground take ${e.delayLabel()} each way, so AstroVitals turns your readings into the next step: act first, then report with clear facts.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: p.mixColors(Colors.white, 0.045),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _frameRich(context, text),
    );
  }

  Widget _frameRich(BuildContext context, String text) {
    final p = avp(context);
    // bold the first sentence
    final dot = text.indexOf('. ');
    if (dot > 0) {
      return Text.rich(TextSpan(children: [
        TextSpan(text: text.substring(0, dot + 1),
            style: AVText.bodyStyle(15, w: FontWeight.w600, color: p.fg)),
        TextSpan(text: text.substring(dot + 1), style: AVText.bodyStyle(15, color: p.muted)),
      ]));
    }
    return Text(text, style: AVText.bodyStyle(15, color: p.muted));
  }

  Widget _bodyStage(BuildContext context, double width) {
    final p = avp(context);
    final levels = st.organLevels;
    final s = st.cur;
    final values = <String, String>{
      'heart': '${s['hr'].round()} bpm',
      'brain': '${s['sleep'].toStringAsFixed(1)} h sleep',
      'lungs': '${s['spo2'].round()}% SpO₂',
      'metab': '${s['glu'].round()} mg/dL',
      'bones': '${s['ex'].round()} min load',
      'muscle':
          '${mv(st.makeCtx(), 'mass') >= 0 ? '+' : ''}${mv(st.makeCtx(), 'mass').toStringAsFixed(1)}% mass',
      'immune': '${s['temp'].toStringAsFixed(1)} °C',
    };
    return Column(
      children: [
        Panel(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BodyMap(
              levels: levels,
              values: values,
              selected: st.sel.t == 'organ' ? st.sel.id : '',
              onSelect: (id) => st.select(Selection.organ(id)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Tap a body system to see its numbers and what to do.',
            textAlign: TextAlign.center,
            style: AVText.bodyStyle(14, color: p.muted),
          ),
        ),
      ],
    );
  }
}

double mathMin2(double a, double b) => a <= b ? a : b;

/// hero status panel (heroPanel port)
class HeroPanel extends StatelessWidget {
  final AppState st;
  final List<AlertItem> all;
  final List<AlertItem> vis;
  const HeroPanel({super.key, required this.st, required this.all, required this.vis});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final ix = st.healthIndex;
    int lvl;
    String t, sub = '';
    if (vis.isNotEmpty) {
      lvl = vis.map((a) => a.lvl).reduce((a, b) => a > b ? a : b);
      t = vis.length == 1 ? '1 thing needs a look' : '${vis.length} things need a look';
    } else if (all.isNotEmpty) {
      lvl = 1;
      t = 'Nothing urgent';
      sub = 'Smaller items are saved for your morning summary.';
    } else {
      lvl = 0;
      t = 'All good today';
      sub = 'Everything you logged is within your usual range.';
    }
    final neutral = lvl == 1;
    final heroColor = Color.lerp(p.panelSolid, p.tierC(lvl), 0.14)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: neutral ? p.mixColors(p.blue, 0.10) : heroColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StatusIcon(lvl, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t, style: AVText.displayStyle(24, w: FontWeight.w600, color: p.fg)),
                    if (sub.isNotEmpty)
                      Text(sub, style: AVText.bodyStyle(15.5, color: p.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$ix', style: AVText.num(28, color: p.fg)),
                  Text('Health index', style: AVText.bodyStyle(12.5, color: p.muted)),
                  Text('out of 100', style: AVText.bodyStyle(11.5, color: p.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Accordion('How the health index and alerts work', children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: 'How alerts reach you. ', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg)),
              TextSpan(
                  text: 'Emergency opens a full screen you must confirm step by step. Act now and Action soon open a pop-up once. Advisory and Monitor wait on this card; in Night and EVA modes they wait for your summary.',
                  style: AVText.bodyStyle(14, color: p.muted)),
            ])),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Health index. ', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg)),
              TextSpan(
                  text: 'Each reading scores 100 when it is in your usual range, then less at each alert level (Monitor 85, Advisory 65, Action soon 40, Act now 20, Emergency 0). The index is the average, capped by your worst alert: an Emergency caps it at 34, so one serious reading is never hidden by good ones.',
                  style: AVText.bodyStyle(14, color: p.muted)),
            ])),
          ]),
          const SizedBox(height: 12),
          AlertsPanel(st: st),
        ],
      ),
    );
  }
}

/// alertsPanel port
class AlertsPanel extends StatelessWidget {
  final AppState st;
  const AlertsPanel({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final vis = st.visibleAlerts;
    final q = st.queuedAlerts;
    if (vis.isEmpty && q.isEmpty) return const SizedBox.shrink();
    final top = vis.where((a) => a.tier >= 2).toList();
    final low = vis.where((a) => a.tier == 1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        for (final a in top) AlertCard(a: a, compact: true),
        if (low.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final a in low.take(top.isEmpty ? 2 : 0)) _lowRow(context, a),
          if (low.length > (top.isEmpty ? 2 : 0))
            Accordion(
              top.isEmpty
                  ? '${low.length} smaller item${low.length > 1 ? 's' : ''} to keep an eye on'
                  : 'Show ${low.length} more',
              children: [
                for (final a in low.skip(top.isEmpty ? 2 : 0)) _lowRow(context, a),
              ],
            ),
        ],
        if (q.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
              '${q.length} lower-priority item${q.length > 1 ? 's are' : ' is'} held for your morning briefing. Urgent items always come through.',
              style: AVText.bodyStyle(14, color: p.muted)),
          const SizedBox(height: 6),
          AVButton(st.showQueued ? 'Hide' : 'Show now', small: true, ghost: true,
              onPressed: st.showQueuedToggle),
          if (st.showQueued)
            Column(
              children: [
                for (final a in q)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusIcon(a.lvl, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${a.title}. ${a.obs}',
                              style: AVText.bodyStyle(14, color: p.fg)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _lowRow(BuildContext context, AlertItem a) {
    final p = avp(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusIcon(1, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${a.title}. ', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg)),
              TextSpan(text: '${a.obs} ', style: AVText.bodyStyle(14, color: p.fg)),
              TextSpan(
                  text: a.metric != null
                      ? (kInfo[metricUiId(a.metric!)]?.act[1]?.first ?? a.acts.first)
                      : a.acts.first,
                  style: AVText.bodyStyle(14, color: p.muted)),
            ])),
          ),
        ],
      ),
    );
  }
}

String metricUiId(String api) {
  for (final m in kMetrics) {
    if (m.api == api) return m.id;
  }
  return api;
}

/// alert card (alertCard port) with ack / start / override / talk actions
class AlertCard extends StatelessWidget {
  final AlertItem a;
  final bool compact;
  final bool modal;
  const AlertCard({super.key, required this.a, this.compact = false, this.modal = false});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final st = AVStore.of(context);
    final acked = st.ack[a.id] == true;
    final children = <Widget>[];

    children.add(Row(
      children: [
        Expanded(
          child: Text(a.title, style: AVText.displayStyle(14, w: FontWeight.w600, color: p.fg)),
        ),
        TierChip(a.lvl),
      ],
    ));
    children.add(Text(a.obs, style: AVText.bodyStyle(14, color: p.fg)));

    if (compact && a.tier == 2 && !modal) {
      children.add(Text.rich(TextSpan(children: [
        TextSpan(text: 'Next step: ', style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg)),
        TextSpan(text: a.acts.first, style: AVText.bodyStyle(14, color: p.fg)),
      ])));
    } else if (a.tier >= 2 || modal) {
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < a.acts.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('${a.tier >= 3 ? '${i + 1}. ' : '· '}${a.acts[i]}',
                    style: AVText.bodyStyle(14, color: p.fg)),
              ),
          ],
        ),
      );
      children.add(Text(a.contact, style: AVText.bodyStyle(13, color: p.muted)));
    }

    if (acked) {
      final note = st.over[a.id] != null
          ? 'Overridden: ${st.over[a.id]}'
          : st.started[a.id] == true
              ? _startedLabel(context, a)
              : 'Acknowledged';
      children.add(Row(
        children: [
          Expanded(child: Text(note, style: AVText.bodyStyle(13, color: p.muted))),
          AVButton('Undo', small: true, ghost: true, onPressed: () => st.unackAlert(a.id)),
        ],
      ));
    } else if (st.overOpen == a.id) {
      children.add(_OverrideForm(a: a));
    } else if (a.tier >= 3) {
      children.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AVButton(_actLabel(a), small: true, onPressed: () => st.startAlert(a.id)),
          AVButton('Talk to flight surgeon', small: true, ghost: true, onPressed: st.talkToFlightSurgeon),
          if (a.metric == 'dose_rate' || a.metric == 'cumulative_dose')
            AVButton('Solar storm steps', small: true, ghost: true, onPressed: () => st.gotoAid('storm'))
          else
            AVButton('Re-measure', small: true, ghost: true, onPressed: () => st.gotoField(a.field)),
          AVLink('Override…', onPressed: () => st.openOverride(a.id)),
        ],
      ));
    } else if (a.tier == 2) {
      children.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AVButton('Acknowledge', small: true, onPressed: () => st.ackAlert(a.id)),
          if (a.metric != null)
            AVButton('View trend', small: true, ghost: true,
                onPressed: () => st.select(Selection.ind(metricUiId(a.metric!))))
          else
            AVButton('Open', small: true, ghost: true, onPressed: () => st.gotoField(a.field)),
          AVButton('Talk to flight surgeon', small: true, ghost: true, onPressed: st.talkToFlightSurgeon),
        ],
      ));
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.lerp(p.panelSolid, p.tierC(a.lvl), 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Opacity(
        opacity: acked ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  String _actLabel(AlertItem a) {
    const actl = {
      'spo2': 'O₂ procedure started',
      'cumulative_dose': 'In storm shelter',
      'dose_rate': 'In storm shelter',
      'co2': 'Moved to ventilated module',
      'temp': 'Resting and monitoring',
      'hr': 'Resting now',
      'blood_pressure': 'Resting now',
      'resp': 'Resting now',
      'blood_glucose': 'Eaten or treated',
      'cabin_temperature': 'Moved to a comfortable module',
      'cabin_humidity': 'Humidity control checked',
      'cabin_noise': 'Hearing protection on',
    };
    return (a.metric != null && actl.containsKey(a.metric)) ? actl[a.metric]! : 'Step 1 done';
  }

  String _startedLabel(BuildContext context, AlertItem a) {
    const actl = {
      'spo2': ['O₂ procedure started', 'Re-measure in 5 minutes.'],
      'cumulative_dose': ['In storm shelter', 'Stay until mission control clears you.'],
      'dose_rate': ['In storm shelter', 'Stay until mission control clears you.'],
      'co2': ['Moved to ventilated module', 'Re-check cabin CO₂ in 10 minutes.'],
      'temp': ['Resting and monitoring', 'Re-measure in an hour.'],
      'hr': ['Resting now', 'Re-measure in 15 minutes.'],
      'blood_pressure': ['Resting now', 'Re-measure in 15 minutes.'],
      'resp': ['Resting now', 'Re-measure in 5 minutes.'],
      'blood_glucose': ['Eaten or treated', 'Re-measure in 15 minutes.'],
      'cabin_temperature': ['Moved to a comfortable module', 'Re-check in 30 minutes.'],
      'cabin_humidity': ['Humidity control checked', 'Re-check in an hour.'],
      'cabin_noise': ['Hearing protection on', 'Re-check in an hour.'],
    };
    if (a.metric != null && actl.containsKey(a.metric)) {
      return '${actl[a.metric]![0]}. ${actl[a.metric]![1]}';
    }
    return 'Step 1 done. Follow the remaining steps, then re-check.';
  }
}

class _OverrideForm extends StatefulWidget {
  final AlertItem a;
  const _OverrideForm({required this.a});
  @override
  State<_OverrideForm> createState() => _OverrideFormState();
}

class _OverrideFormState extends State<_OverrideForm> {
  String _reason = 'Already re-measured';
  @override
  Widget build(BuildContext context) {
    final reasons = ['Already re-measured', 'Sensor looks wrong', 'Just finished exercise', 'Other'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AVSelect<String>(
          value: _reason,
          items: [for (final r in reasons) (r, r)],
          onChanged: (v) => setState(() => _reason = v ?? _reason),
        ),
        const SizedBox(height: 8),
        AVButton('Save reason', small: true,
            onPressed: () => AVStore.of(context).saveOverride(widget.a.id, _reason)),
      ],
    );
  }
}

/// check-in tasks panel (checkinPanel port)
class CheckinPanel extends StatelessWidget {
  final AppState st;
  final VoidCallback rebuild;
  const CheckinPanel({super.key, required this.st, required this.rebuild});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final n = st.tasksDone;
    const T = 4;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('Today’s check-in',
                    style: AVText.displayStyle(19, w: FontWeight.w600, color: p.fg)),
              ),
              Text('$n of $T done', style: AVText.bodyStyle(13.5, color: p.muted)),
            ],
          ),
          const SizedBox(height: 8),
          AVMeter(n / T * 100),
          const SizedBox(height: 12),
          for (final t in kTasks)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.mixColors(Colors.white, 0.045),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: st.taskIsDone(t.id)
                        ? StatusIcon(0, size: 24)
                        : Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: p.blue, width: 2),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title,
                            style: AVText.displayStyle(16, w: FontWeight.w600,
                                color: st.taskIsDone(t.id) ? p.muted : p.fg)),
                        Text(t.hint, style: AVText.bodyStyle(13.5, color: p.muted)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => st.gotoSection(t.id),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: st.taskIsDone(t.id)
                            ? p.mixColors(Colors.white, 0.08)
                            : p.blue,
                      ),
                      child: Icon(Icons.arrow_forward,
                          size: 22,
                          color: st.taskIsDone(t.id) ? p.fg : const Color(0xFF06121D)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// numbersPanel port - 'Your other pages'
class NumbersPanel extends StatelessWidget {
  final AppState st;
  const NumbersPanel({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    const pages = [
      ['vit', 'Vitals', 'Heart, blood pressure, oxygen, temperature and more'],
      ['cabin', 'Cabin and mission', 'Cabin air, radiation dose and mission day'],
      ['med', 'Medical', 'Medicines, supplies and photos'],
      ['mind', 'Mind and focus', 'Weekly check-in, fatigue check and journal'],
    ];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('Your other pages',
                    style: AVText.displayStyle(19, w: FontWeight.w600, color: p.fg)),
              ),
              Text('Tap one to open it', style: AVText.bodyStyle(13.5, color: p.muted)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 900 ? 4 : box.maxWidth > 640 ? 2 : 1;
            return Column(
              children: [
                for (var i = 0; i < pages.length; i += cols)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var j = i; j < mathMinInt(i + cols, pages.length); j++)
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                  bottom: 8, right: j < i + cols - 1 ? 8 : 0),
                              child: _pageTile(context, pages[j]),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _pageTile(BuildContext context, List<String> x) {
    final p = avp(context);
    final fs = pageFields(x[0]);
    final lvls = [for (final f in fs) st.fieldLevelOf(f)];
    var n = 0;
    var top = 0;
    for (final l in lvls) {
      if (l > 0 && !(st.dnd && tierOf(l) < 3)) n++;
      if (l > top) top = l;
    }
    if (st.dnd && tierOf(top) < 3) top = 0;
    final txt = n > 0
        ? (n == 1 ? '1 thing needs a look' : '$n things need a look')
        : (x[0] == 'vit' || x[0] == 'cabin')
            ? 'All in your usual range'
            : 'Nothing needs a look';
    return Material(
      color: Color.alphaBlend(p.tierC(top).withValues(alpha: 0.10), p.mixColors(Colors.white, 0.08)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => st.setTab(x[0]),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusIcon(top, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(x[1],
                        style: AVText.displayStyle(16, w: FontWeight.w600, color: p.fg)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(txt, style: AVText.bodyStyle(12.5, color: p.tierT(top.clamp(0, 5)))),
              Text(x[2], style: AVText.bodyStyle(12, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
