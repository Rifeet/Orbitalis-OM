/// Emergency guide page (aidView port) - exact structure of the reference
/// design: "First aid guide" panel with scenario pills, then the selected
/// procedure panel with steps laid out as [number badge] [illustration]
/// [title + description]. The four verified procedures come from
/// emergency.docx with their 20 illustrations; the remaining three design
/// procedures render as line art.
library;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../core/data/app_state.dart';
import '../../emergency/aid_art.dart';
import '../../emergency/emergency_data.dart';
import '../widgets/common.dart';

class EmergencyPage extends StatelessWidget {
  final AppState st;
  const EmergencyPage({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    // tab order as the design: the 4 docx procedures first, then the 3 design ones
    const docxIds = ['faint', 'chest', 'cpr', 'choke'];
    final docx = <AidProcedure>[];
    for (final id in docxIds) {
      docx.add(kAidProcedures.firstWhere((a) => a.id == id));
    }

    final isDocx = docxIds.contains(st.aidTab);
    final procedure = docx.firstWhere(
      (a) => a.id == st.aidTab,
      orElse: () => docx.first,
    );
    final design = kDesignAids.where((d) => d.id == st.aidTab).toList();

    final delayNote = st.env.delayMin < 1
        ? 'In a real emergency, call the crew and the flight surgeon now.'
        : 'In a real emergency, start these steps with your crew now. Send the flight surgeon one complete message (${st.env.delayLabel()} each way).';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelHead('First aid guide'),
                Text('Pick what is happening. Steps appear below. $delayNote',
                    style: AVText.bodyStyle(14, color: p.muted)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in docx)
                      _aidTab(context, a.id, a.name, a.id == st.aidTab),
                    for (final d in kDesignAids)
                      _aidTab(context, d.id, d.name, d.id == st.aidTab),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                          isDocx ? procedure.name : design.first.name,
                          style: AVText.displayStyle(19, w: FontWeight.w600, color: p.fg)),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                          isDocx ? procedure.trigger : design.first.sub,
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: AVText.bodyStyle(13.5, color: p.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isDocx)
                  for (final s in procedure.steps)
                    _docxStep(context, s)
                else
                  for (var i = 0; i < design.first.steps.length; i++)
                    _designStep(context, design.first.steps[i], i),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// scenario pill (.aidtabs button): content-sized, never stretched
  Widget _aidTab(BuildContext context, String id, String name, bool sel) {
    final p = avp(context);
    return Material(
      color: sel ? p.blue : p.surf2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => st.setAid(id),
        // 13px vertical padding -> the design's 48px pill height; padding-only
        // sizing keeps the pill content-sized inside the Wrap
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: AVText.displayStyle(14,
                      w: FontWeight.w600,
                      color: sel ? const Color(0xFF06121D) : p.fg)),
            ],
          ),
        ),
      ),
    );
  }

  /// step row (.asteps li): 34px number badge + 190px illustration + text,
  /// vertically centred like the design grid (36px 190px 1fr / gap 14px)
  Widget _stepRow(
    BuildContext context, {
    required Widget illustration,
    required String number,
    required String title,
    required String description,
  }) {
    final p = avp(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surf2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > 620;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _numberBadge(p, number),
              const SizedBox(width: 14),
              illustration,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AVText.displayStyle(17, w: FontWeight.w600, color: p.fg)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: AVText.bodyStyle(15, color: p.muted, height: 1.5)),
                  ],
                ),
              ),
            ],
          );
        }
        // narrow: badge + title share the first line, illustration below
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _numberBadge(p, number),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: AVText.displayStyle(17, w: FontWeight.w600, color: p.fg)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            illustration,
            const SizedBox(height: 8),
            Text(description, style: AVText.bodyStyle(15, color: p.muted, height: 1.5)),
          ],
        );
      }),
    );
  }

  Widget _numberBadge(AVPalette p, String number) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: p.blue),
      child: Text(number,
          style: AVText.num(16, w: FontWeight.w700, color: const Color(0xFF06121D))),
    );
  }

  /// docx illustration in the design's slot: 190px wide, rounded 12
  Widget _docxStep(BuildContext context, AidStep s) {
    const imgW = 190.0;
    final illustration = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        s.image,
        width: imgW,
        fit: BoxFit.contain,
        errorBuilder: (_, e, s) => Container(
          width: imgW,
          height: 110,
          color: Colors.black.withValues(alpha: 0.22),
        ),
      ),
    );
    return _stepRow(
      context,
      illustration: illustration,
      number: '${s.n}',
      title: s.enTitle,
      description: s.en,
    );
  }

  Widget _designStep(BuildContext context, (String, String, List<Prim> Function()) s, int i) {
    final illustration = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 190,
        child: AidArt(scene: s.$3, height: 110),
      ),
    );
    return _stepRow(
      context,
      illustration: illustration,
      number: '${i + 1}',
      title: s.$1,
      description: s.$2,
    );
  }
}
