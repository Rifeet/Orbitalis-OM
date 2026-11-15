/// Data pages (Check-in / Vitals / Cabin and mission / Medical / Mind and
/// focus) - port of pageView(): grouped sections of field cards with task
/// completion heads and scroll-to-field support.
library;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/contract/fields.dart';
import '../../core/data/app_state.dart';
import '../widgets/common.dart';
import '../widgets/field_cards.dart';

class DataPage extends StatefulWidget {
  final String pageId;
  final AppState st;
  final VoidCallback rebuild;
  const DataPage({super.key, required this.pageId, required this.st, required this.rebuild});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  final Map<String, GlobalKey> _sectionKeys = {};
  final ScrollController _scroll = ScrollController();
  String? _lastTarget;

  GlobalKey _keyOf(String id) => _sectionKeys.putIfAbsent(id, GlobalKey.new);

  void _scrollToTarget() {
    final target = widget.st.scrollTargetField;
    if (target == null || target == _lastTarget) return;
    _lastTarget = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (target.startsWith('sec:')) {
        final k = _keyOf(target.substring(4));
        _scrollToKey(k);
      } else {
        _scrollToKey(_keyOf('f_$target'));
      }
      widget.st.consumeScrollTarget();
    });
  }

  void _scrollToKey(GlobalKey k) {
    final ctx = k.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 400),
        alignment: 0.1,
        curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final def = kPages.firstWhere((d) => d.id == widget.pageId);
    _scrollToTarget();
    final tasksDoneCount = widget.st.tasksDone;

    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(def.n, style: AVText.displayStyle(19, w: FontWeight.w600, color: p.fg)),
                ),
                if (widget.pageId == 'checkin')
                  Text('$tasksDoneCount of ${kTasks.length} done today',
                      style: AVText.bodyStyle(13.5, color: p.muted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(def.sub, style: AVText.bodyStyle(15.5, color: p.fg)),
          ),
          for (final sec in def.secs) ...[
            if (sec.t.isNotEmpty)
              Container(
                key: _keyOf(sec.id),
                child: GroupHead(
                  sec.t,
                  small: sec.s +
                      (kTaskMap[sec.id] != null && widget.st.taskIsDone(sec.id) ? ' · done today' : ''),
                  trailing: sec.nothing
                      ? Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: AVButton('Nothing to report today', small: true, ghost: true,
                              onPressed: widget.st.noSymptoms),
                        )
                      : null,
                  done: kTaskMap[sec.id] != null && widget.st.taskIsDone(sec.id),
                ),
              ),
            _FieldGrid(
              fields: [
                for (final id in sec.f)
                  if (kFieldById[id] != null) kFieldById[id]!,
              ],
              st: widget.st,
              keyOf: _keyOf,
              rebuild: widget.rebuild,
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  final List<FieldDef> fields;
  final AppState st;
  final GlobalKey Function(String) keyOf;
  final VoidCallback rebuild;
  const _FieldGrid({required this.fields, required this.st, required this.keyOf, required this.rebuild});

  @override
  Widget build(BuildContext context) {
    // vit/cabin cards squeeze to ~260px min ('dv'), other pages are single column ('ck')
    final isDv = fields.isNotEmpty &&
        (fields.every((f) => f.kind == 'dev') ||
            fields.every((f) => f.kind == 'dev' || f.id == 'mission_day_phase' || f.id == 'communication_delay'));
    return LayoutBuilder(builder: (context, box) {
      final colCount = box.maxWidth > 1150 && isDv
          ? 3
          : box.maxWidth > 720 && isDv
              ? 2
              : 1;
      if (colCount == 1) {
        return Column(
          children: [
            for (final f in fields)
              Container(
                key: keyOf('f_${f.id}'),
                margin: const EdgeInsets.only(bottom: 14),
                child: FieldCard(f, st: st, rebuild: rebuild),
              ),
          ],
        );
      }
      return Column(
        children: [
          for (var i = 0; i < fields.length; i += colCount)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = i; j < mathMinInt(i + colCount, fields.length); j++)
                  Expanded(
                    child: Container(
                      key: keyOf('f_${fields[j].id}'),
                      margin: EdgeInsets.only(
                          bottom: 14, right: j < mathMinInt(i + colCount - 1, fields.length) ? 14 : 0),
                      child: FieldCard(fields[j], st: st, rebuild: rebuild),
                    ),
                  ),
              ],
            ),
        ],
      );
    });
  }
}

int mathMaxInt(int a, int b) => a >= b ? a : b;
int mathMinInt(int a, int b) => a <= b ? a : b;
