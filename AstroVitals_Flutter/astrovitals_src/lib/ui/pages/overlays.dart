/// Overlays - tier 3 modal (opens once per alert) and the tier 4 full-screen
/// urgent alert with the step-by-step confirmation checklist (showUrgent port).
library;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/contract/models.dart';
import '../../core/data/app_state.dart';
import '../../core/engine/engine.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/status_icon.dart';
import 'overview_page.dart' show AlertCard, metricUiId;

/// tier 3 modal sheet
class AlertModal extends StatelessWidget {
  final AppState st;
  const AlertModal({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final list = st.evaluate().where((a) => a.tier == 3 && st.ack[a.id] != true).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    final maxLvl = list.map((a) => a.lvl).reduce((a, b) => a > b ? a : b);
    return Material(
      type: MaterialType.transparency,
      child: Center(
      child: Container(
        width: mathMinD(560, MediaQuery.of(context).size.width - 32),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.panelSolid,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.blue),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusIcon(maxLvl, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${kTierNames[maxLvl]}${list.length > 1 ? ' · ${list.length} alerts' : ''}',
                    style: AVText.displayStyle(18, w: FontWeight.w600, color: p.fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final a in list)
                      AlertCard(a: a, modal: true, compact: false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: AVButton('Close', small: true, ghost: true, onPressed: () {
                for (final a in list) {
                  st.shown[a.id] = true;
                }
                st.notifyChange();
              }),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// tier 4 full screen
class UrgentScreen extends StatelessWidget {
  final AppState st;
  const UrgentScreen({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    final t4 = st.evaluate().where((a) => a.tier == 4 && st.ack[a.id] != true).toList();
    if (t4.isEmpty) return const SizedBox.shrink();
    final a = t4.first;
    final spo = metricUiId(a.metric ?? '') == 'spo2';
    String reading = '';
    if (a.metric != null) {
      final id = metricUiId(a.metric!);
      reading = '${fmtVal(st, id)} ${metricDef(id).unit}';
    }
    final safe = spo ? '(safe: 90% or higher)' : '';
    final canClose = st.u1 && st.u2;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: const Color(0xFF1C0404),
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: mathMinD(640, MediaQuery.of(context).size.width - 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusIcon(5, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        spo ? 'SpO₂ below safe range' : '${a.title} needs action now',
                        style: AVText.displayStyle(26, w: FontWeight.w700,
                            color: Colors.white, ls: .5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Reading: ',
                      style: AVText.num(40, color: Colors.white)),
                  TextSpan(text: '$reading  ',
                      style: AVText.num(40, color: Colors.white)),
                  TextSpan(text: safe,
                      style: AVText.bodyStyle(16, color: const Color(0xFFFFB4AE))),
                ])),
                const SizedBox(height: 10),
                Text('ACTION REQUIRED NOW',
                    style: AVText.displayStyle(13, w: FontWeight.w600,
                        color: const Color(0xFFFFB4AE), ls: 2)),
                const SizedBox(height: 10),
                for (var i = 0; i < a.acts.length; i++)
                  _urgentStep(context, a, i),
                const SizedBox(height: 8),
                Text(
                  canClose
                      ? 'Both confirmed. You can close this screen.'
                      : 'Confirm steps 1 and 2 to close this screen.',
                  style: AVText.bodyStyle(14, color: const Color(0xFFFFB4AE)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AVButton('Close alert',
                          onPressed: canClose ? st.urgentClose : null),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AVButton('Reading looks wrong? Re-measure',
                          ghost: true,
                          onPressed: () => st.urgentRemeasure(a.field, a.id)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _urgentStep(BuildContext context, AlertItem a, int i) {
    final step1 = i == 0;
    final step2 = i == 1;
    final on = (step1 && st.u1) || (step2 && st.u2);
    final btnLabel = on
        ? 'Done'
        : step1
            ? (metricUiId(a.metric ?? '') == 'spo2' ? 'O₂ started' : 'Step 1 done')
            : 'Notified';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: on ? const Color(0x1A74D67C) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? const Color(0xFF74D67C) : Colors.white,
            ),
            child: Text(on ? '✓' : '${i + 1}',
                style: AVText.displayStyle(15, w: FontWeight.w700,
                    color: on ? const Color(0xFF1C0404) : const Color(0xFF1C0404))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(a.acts[i],
                style: AVText.bodyStyle(17, color: Colors.white)),
          ),
          if (step1 || step2)
            SizedBox(
              height: 48,
              child: AVButton(
                btnLabel,
                onPressed: () => step1 ? st.toggleU1() : st.toggleU2(),
              ),
            ),
        ],
      ),
    );
  }
}

double mathMinD(double a, double b) => a <= b ? a : b;
