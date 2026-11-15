/// Field cards - port of cardHTML()/cardBody()/devBody(): one card per field
/// with immediate validation on every manual input (live error text + disabled
/// Save until the value is valid).
library;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../core/contract/fields.dart';
import '../../core/contract/limits.dart';
import '../../core/contract/models.dart'
    show metricDef, formatNum, kEnvProfiles;
import '../../core/contract/zones.dart' show kBase, kPlanBed, kPlanUp;
import '../../core/data/app_state.dart';
import '../../core/engine/engine.dart' show hm, wrapDiff;
import '../../core/validation/validators.dart';
import '../format.dart';
import 'common.dart';
import 'small_painters.dart';
import 'sparkline.dart';
import 'status_icon.dart';

class FieldCard extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  final VoidCallback rebuild;
  const FieldCard(this.f, {super.key, required this.st, required this.rebuild});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final l = st.fieldLevelOf(f);
    final hz = kHazards.firstWhere((z) => z.id == f.hz);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.label,
                      style: AVText.displayStyle(
                        17,
                        w: FontWeight.w600,
                        color: p.fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${hz.short} hazard',
                      style: AVText.bodyStyle(12.5, color: p.muted),
                    ),
                  ],
                ),
              ),
              if (l >= 0) TierChip(l),
            ],
          ),
          const SizedBox(height: 12),
          _FieldBody(f: f, st: st, rebuild: rebuild),
        ],
      ),
    );
  }
}

class _FieldBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  final VoidCallback rebuild;
  const _FieldBody({required this.f, required this.st, required this.rebuild});

  @override
  Widget build(BuildContext context) {
    switch (f.kind) {
      case 'dev':
        return DevCardBody(f: f, st: st);
      case 'mood':
        return MoodBody(f: f, st: st);
      case 'chips':
        return ChipsBody(f: f, st: st);
      case 'photos':
        return PhotosBody(f: f, st: st);
      case 'meds':
        return MedsBody(f: f, st: st);
      case 'sliders':
        return SlidersBody(f: f, st: st);
      case 'social':
        return SocialBody(f: f, st: st);
      case 'weekly':
        return WeeklyBody(f: f, st: st);
      case 'journal':
        return JournalBody(f: f, st: st);
      case 'rt':
        return ReactionBody(f: f, st: st);
      case 'rate':
        return RateBody(f: f, st: st);
      case 'sleepclock':
        return SleepClockBody(f: f, st: st);
      case 'day':
        return DayBody(f: f, st: st);
      case 'sev':
        return SeverityBody(f: f, st: st);
      case 'dur':
        return DurationBody(f: f, st: st);
      case 'medstaken':
        return MedsTakenBody(f: f, st: st);
      case 'habitat':
        return HabitatBody(f: f, st: st);
      case 'inv':
        return InvBody(f: f, st: st);
      case 'delay':
        return DelayBody(f: f, st: st);
      case 'flag':
        return FlagBody(f: f, st: st);
      case 'pain':
        return PainBody(f: f, st: st);
      case 'food':
        return FoodBody(f: f, st: st);
      case 'water':
        return WaterBody(f: f, st: st);
    }
    return const SizedBox.shrink();
  }
}

// =====================================================================
// dev cards (readings from devices + validated manual entry)
// =====================================================================
class DevCardBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const DevCardBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final m = f.metric!;
    final l = st.fieldLevelOf(f);
    final s = st.cur;
    final def = metricDef(m);
    String big;
    String unit = def.unit;
    List<Widget> extras = [];

    if (m == 'rad') {
      big = s['rad'].toStringAsFixed(2);
      unit = 'mSv today';
      final pct = (s['radTotal'] / st.env.limit * 100).round();
      extras = [
        Row(
          children: [
            Expanded(
              child: KvTile(
                s['radTotal'].round().toString(),
                'mSv mission total',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KvTile('$pct%', 'of the ${st.env.limit} mSv limit'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AVMeter(pct.toDouble(), level: l),
        const SizedBox(height: 8),
        Text(
          'Typical here: ${formatNum(st.env.dose)} mSv per day.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
      ];
    } else if (m == 'bp') {
      big = '${s['sys'].round()}/${s['dia'].round()}';
      extras = [
        Text(
          'Baseline ${kBase['sys']!.round()}/${kBase['dia']!.round()} mmHg.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
      ];
    } else if (m == 'sleep') {
      big = s['sleep'].toStringAsFixed(1);
      extras = [
        Text(
          'Wake-ups: ${st.wake}. Asleep ${st.bed} to ${st.up}. Your average: ${hm(kBase['sleep']!)}.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
      ];
    } else if (m == 'mass') {
      big = s['mass'].toStringAsFixed(1);
      final pct =
          (s['mass'] - (kBase['mass'] ?? 74)) / (kBase['mass'] ?? 74) * 100;
      extras = [
        Text(
          '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% from your baseline of ${(kBase['mass'] ?? 74).toStringAsFixed(1)} kg.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
      ];
    } else if (m == 'co2') {
      big = s['co2'].round().toString();
      extras = [
        Text(
          'Comfortable: under 3,000 ppm. Flag limit: 7,000 ppm.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
      ];
    } else if (m == 'ex') {
      big = s['ex'].round().toString();
      extras = [
        Text(
          'Plan for today: 90 min of resistive and aerobic work.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
      ];
    } else {
      big = fmtVal(st, m);
    }

    final series = st.seriesFor(m);
    final meta = st.metaFor(f);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  big,
                  maxLines: 1,
                  softWrap: false,
                  style: AVText.num(38, w: FontWeight.w600, color: p.tierT(l)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(unit, style: AVText.bodyStyle(13, color: p.muted)),
            const Spacer(),
            Sparkline(series, l, width: 96, height: 30),
          ],
        ),
        ...extras,
        if (meta != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SourceBadge(
              device: meta.source == 'manual' ? '' : meta.device,
              ts: meta.ts,
              tag: meta.source == 'manual'
                  ? 'Manual entry'
                  : meta.kind == 'partial'
                  ? 'Partial source'
                  : 'Direct source',
            ),
          ),
        WhyBlock(m: m),
        ManualForm(f: f, st: st),
      ],
    );
  }
}

/// whyBlock port for metric fields
class WhyBlock extends StatelessWidget {
  final String m;
  const WhyBlock({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final info = kInfo[m]!;
    return Accordion(
      'Why we measure this',
      children: [
        Text(info.why, style: AVText.bodyStyle(14, color: p.muted)),
        const SizedBox(height: 8),
        Text(
          'How to measure',
          style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg),
        ),
        ...info.how.map(
          (x) => Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: AVText.bodyStyle(14, color: p.muted)),
                Expanded(
                  child: Text(x, style: AVText.bodyStyle(14, color: p.muted)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'What spaceflight does',
          style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg),
        ),
        Text(info.space, style: AVText.bodyStyle(14, color: p.muted)),
        const SizedBox(height: 8),
        Text(
          'Talk to the flight surgeon if',
          style: AVText.bodyStyle(14, w: FontWeight.w600, color: p.fg),
        ),
        Text(info.esc, style: AVText.bodyStyle(14, color: p.muted)),
      ],
    );
  }
}

/// manual form with immediate validation
class ManualForm extends StatefulWidget {
  final FieldDef f;
  final AppState st;
  const ManualForm({super.key, required this.f, required this.st});

  @override
  State<ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends State<ManualForm> {
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, String?> _errors = {};
  String? _bpPairError;

  String? _bed, _up, _wake;
  String? _bedError, _upError, _wakeError, _sleepError;
  bool _sleepTouched = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String k) {
    return _ctrls.putIfAbsent(k, () {
      final st = widget.st;
      String init = '';
      if (k == 'bed') init = st.bed;
      if (k == 'up') init = st.up;
      if (k == 'wake') init = st.wake.toString();
      final spec = kManualSpec[widget.f.metric];
      if (spec != null) {
        for (final q in spec) {
          if (q[0] == k) {
            final key = q[0] as String;
            init = key == 'rad'
                ? st.cur['rad'].toStringAsFixed(2)
                : st.cur[key].toString();
          }
        }
      }
      return TextEditingController(text: init);
    });
  }

  void _validate(String k, String raw) {
    setState(() {
      if (widget.f.metric == 'sleep') {
        if (k == 'bed') {
          _bed = raw;
          _bedError = raw.isEmpty ? 'Enter bedtime.' : null;
        } else if (k == 'up') {
          _up = raw;
          _upError = raw.isEmpty ? 'Enter wake time.' : null;
        } else if (k == 'wake') {
          _wake = raw;
          final wk = int.tryParse(raw);
          _wakeError = (wk == null || wk < 0 || wk > 20)
              ? 'Wake-ups must be between 0 and 20.'
              : null;
        }
        // combined check
        _sleepError = null;
        if (_bed != null &&
            _up != null &&
            _wake != null &&
            _bedError == null &&
            _upError == null &&
            _wakeError == null) {
          final v = validateSleep(_bed!, _up!, _wake!);
          _sleepError = v.ok ? null : v.error;
        }
        _sleepTouched = true;
      } else {
        _errors[k] = validateNumber(raw, k).error;
        if (widget.f.metric == 'bp') {
          _bpPairError = validateBpPair(
            _ctrl('sys').text,
            _ctrl('dia').text,
          ).error;
        }
      }
    });
  }

  bool get _hasError {
    if (_errors.values.any((e) => e != null && e.isNotEmpty)) return true;
    if (_bpPairError != null) return true;
    if (_sleepError != null ||
        _bedError != null ||
        _upError != null ||
        _wakeError != null)
      return true;
    return false;
  }

  bool get _dirty => _errors.values.any((e) => e != null) || _sleepTouched;

  void _save() {
    if (_hasError) return;
    final st = widget.st;
    if (widget.f.metric == 'sleep') {
      st.saveSleep(
        _bed ?? st.bed,
        _up ?? st.up,
        int.tryParse(_wake ?? '') ?? st.wake,
      );
      setState(() {
        _bedError = _upError = _wakeError = _sleepError = null;
        _errors.clear();
        _dirty;
      });
    } else {
      final vals = <String, double>{};
      var ok = true;
      for (final k in widget.f.keys) {
        final raw = _ctrl(k).text;
        final v = validateNumber(raw, k);
        if (!v.ok) {
          ok = false;
          break;
        }
        vals[k] = double.parse(raw.replaceAll(',', '.'));
      }
      if (!ok) return;
      st.setManual(vals);
      setState(() => _errors.clear());
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final isSleep = widget.f.metric == 'sleep';
    final spec = isSleep ? null : kManualSpec[widget.f.metric];

    return Accordion(
      'Enter manually',
      children: [
        if (isSleep)
          Row(
            children: [
              Expanded(
                child: FieldLabel(
                  label: 'Bedtime',
                  child: AVTextField(
                    controller: _ctrl('bed'),
                    hint: 'HH:MM',
                    error: _bedError != null,
                    onChanged: (v) => _validate('bed', v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FieldLabel(
                  label: 'Wake time',
                  child: AVTextField(
                    controller: _ctrl('up'),
                    hint: 'HH:MM',
                    error: _upError != null,
                    onChanged: (v) => _validate('up', v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FieldLabel(
                  label: 'Wake-ups',
                  child: AVTextField(
                    controller: _ctrl('wake'),
                    keyboardType: TextInputType.number,
                    error: _wakeError != null,
                    onChanged: (v) => _validate('wake', v),
                  ),
                ),
              ),
            ],
          )
        else if (spec != null)
          Column(
            children: [
              for (final q in spec)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FieldLabel(
                        label: q[1] as String,
                        child: AVTextField(
                          controller: _ctrl(q[0] as String),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          error: (_errors[q[0] as String] ?? '').isNotEmpty,
                          onChanged: (v) => _validate(q[0] as String, v),
                        ),
                      ),
                      ErrorText(_errors[q[0] as String]),
                    ],
                  ),
                ),
              if (widget.f.metric == 'bp') ErrorText(_bpPairError),
            ],
          ),
        if (isSleep) ...[
          ErrorText(_bedError ?? _upError ?? _wakeError ?? _sleepError),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            AVButton('Save', small: true, onPressed: _hasError ? null : _save),
            const SizedBox(width: 10),
            if (widget.f.keys.any((k) => st.hasDeviceBackup(k)))
              AVButton(
                'Use device feed',
                small: true,
                ghost: true,
                onPressed: () {
                  st.useDevice(widget.f.id);
                },
              ),
          ],
        ),
      ],
    );
  }
}

// =====================================================================
// input cards
// =====================================================================
class MoodBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const MoodBody({super.key, required this.f, required this.st});

  static const labels = ['Very low', 'Low', 'Neutral', 'Good', 'Great'];

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final current = st.cur['mood'].round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final v = i + 1;
            final sel = current == v;
            return Expanded(
              child: GestureDetector(
                onTap: () => st.setFace(v.toDouble()),
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  constraints: const BoxConstraints(minHeight: 62),
                  decoration: BoxDecoration(
                    color: sel
                        ? p.mixColors(p.blue, 0.22)
                        : p.mixColors(Colors.white, 0.08),
                    border: Border.all(
                      color: sel ? p.blue : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaceIcon(v, color: sel ? p.fg : p.muted),
                      const SizedBox(height: 2),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: AVText.bodyStyle(
                          10,
                          color: sel ? p.fg : p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Your usual: ${kBase['mood']!.round()} of 5. Mood over a week tells us more than one day.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Crew entry',
        ),
        WhyBlock(m: 'mood'),
      ],
    );
  }
}

class ChipsBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const ChipsBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final sel = List<String>.from(st.ent[f.g!] ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: f.opts!
              .map(
                (o) => Material(
                  color: sel.contains(o)
                      ? p.mixColors(p.blue, 0.22)
                      : p.mixColors(Colors.white, 0.08),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => st.toggleChip(f.g!, o),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        o,
                        style: AVText.bodyStyle(13.5, color: p.fg),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (f.photo != null) ...[
          const SizedBox(height: 10),
          Text(
            'Photo of a rash or irritation (optional)',
            style: AVText.bodyStyle(13.5, color: p.muted),
          ),
          PhotosPicker(bucket: f.photo!, st: st),
        ],
        const SizedBox(height: 8),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Crew entry',
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

/// demo photo picker: adds a bundled sample image (the real build posts a
/// camera photo; validation limits still apply)
class PhotosPicker extends StatelessWidget {
  final String bucket;
  final AppState st;
  const PhotosPicker({super.key, required this.bucket, required this.st});

  static const samples = {
    'skin': 'assets/img/sample_skin.png',
    'rash': 'assets/img/sample_rash.png',
    'ultra': 'assets/img/sample_ultra.png',
    'food': 'assets/img/sample_food.png',
    'inv': 'assets/img/sample_label.png',
  };

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final img = (st.ent['img'] as Map<String, List<String>>)[bucket] ?? [];
    final label = switch (bucket) {
      'ultra' => 'Upload scan export',
      'inv' => 'Photo of label',
      _ => 'Add photo',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < img.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      img[i],
                      width: 84,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => st.removePhoto(bucket, i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.bg.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: p.line),
                        ),
                        child: Text(
                          'Remove',
                          style: AVText.bodyStyle(11, color: p.fg),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            final asset = samples[bucket] ?? samples['skin']!;
            st.addPhoto(bucket, asset, true, 90000);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: p.blue,
                style: BorderStyle.solid,
                width: 1,
              ),
            ),
            child: Text(
              label.toUpperCase(),
              style: AVText.displayStyle(12, w: FontWeight.w600, color: p.holo),
            ),
          ),
        ),
      ],
    );
  }
}

class PhotosBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const PhotosBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhotosPicker(bucket: f.b!, st: st),
        const SizedBox(height: 8),
        Text(
          f.b == 'ultra'
              ? 'Last session: 2 days ago, guided from the ground.'
              : 'Photos stay on this device until you send them.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: f.src == 'direct' ? 'Direct source' : 'Crew entry',
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class MedsBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const MedsBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    return _MedsForm(st: st);
  }
}

class _MedsForm extends StatefulWidget {
  final AppState st;
  final String fieldId;
  final String why;
  _MedsForm({required this.st})
    : fieldId = 'medications',
      why = kFieldById['medications']!.why;
  @override
  State<_MedsForm> createState() => _MedsFormState();
}

class _MedsFormState extends State<_MedsForm> {
  String _name = kMeds.first;
  final _doseCtrl = TextEditingController();
  String? _doseError;

  @override
  void dispose() {
    _doseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final meds = List<Map<String, dynamic>>.from(widget.st.ent['meds'] as List);
    // ignore: unused_local_variable
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AVSelect<String>(
                value: _name,
                items: [for (final m in kMeds) (m, m)],
                onChanged: (v) => setState(() => _name = v ?? _name),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(
                    label: 'Dose',
                    child: AVTextField(
                      controller: _doseCtrl,
                      hint: 'e.g. 400 mg',
                      maxLength: 30,
                      error: _doseError != null,
                      onChanged: (v) {
                        setState(() => _doseError = validateMedDose(v).error);
                      },
                    ),
                  ),
                  ErrorText(_doseError),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AVButton(
          'Log dose',
          small: true,
          onPressed: _doseError == null
              ? () {
                  widget.st.logMed(_name, _doseCtrl.text);
                  _doseCtrl.clear();
                  setState(() => _doseError = null);
                }
              : null,
        ),
        const SizedBox(height: 6),
        ...List.generate(meds.length, (i) {
          final m = meds[i];
          final ts = m['ts'] as int;
          final hh = DateTime.fromMillisecondsSinceEpoch(ts);
          return ListRow(
            Text(
              '${m['n']}${(m['d'] as String?)?.isNotEmpty == true ? ' · ${m['d']}' : ''}',
              style: AVText.bodyStyle(13.5, color: p.fg),
            ),
            right: Text(
              '${hh.hour.toString().padLeft(2, '0')}:${hh.minute.toString().padLeft(2, '0')}',
              style: AVText.bodyStyle(13.5, color: p.muted),
            ),
          );
        }, growable: true),
        if (meds.isEmpty)
          ListRow(
            Text(
              'No doses logged today.',
              style: AVText.bodyStyle(13.5, color: p.muted),
            ),
          ),
        const SizedBox(height: 8),
        SourceBadge(
          ts: (widget.st.ent['ts'] as Map<String, int>)[widget.fieldId],
          tag: 'Crew entry',
        ),
        Accordion(
          'Why we ask',
          children: [
            Text(widget.why, style: AVText.bodyStyle(14, color: p.muted)),
          ],
        ),
      ],
    );
  }
}

class SlidersBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const SlidersBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final s = st.ent['stress'] as Map<String, dynamic>;
    return Column(
      children: [
        SliderRow(
          k: 'stress',
          label: 'Stress',
          value: (s['stress'] as num).toDouble(),
          st: st,
        ),
        SliderRow(
          k: 'fatigue',
          label: 'Fatigue',
          value: (s['fatigue'] as num).toDouble(),
          st: st,
        ),
        SliderRow(
          k: 'workload',
          label: 'Workload',
          value: (s['workload'] as num).toDouble(),
          st: st,
        ),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Partial source',
          srcNote: f.srcNote,
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class SliderRow extends StatelessWidget {
  final String k;
  final String label;
  final double value;
  final AppState st;
  const SliderRow({
    super.key,
    required this.k,
    required this.label,
    required this.value,
    required this.st,
  });

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AVText.bodyStyle(12, color: p.muted)),
            Text(value.round().toString(), style: AVText.num(14, color: p.fg)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: p.blue,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: p.blue,
            overlayColor: p.blue.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => st.setSlider(k, v),
          ),
        ),
      ],
    );
  }
}

class SocialBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const SocialBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final social = st.ent['social'] as Map<String, dynamic>;
    final conn = (social['conn'] as num).round();
    const labels = ['Not at all', 'A little', 'Somewhat', 'Mostly', 'Very'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How connected do you feel to the crew today?',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (i) {
            final v = i + 1;
            final sel = conn == v;
            return Expanded(
              child: GestureDetector(
                onTap: () => st.setRate('conn', v),
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  constraints: const BoxConstraints(minHeight: 50),
                  decoration: BoxDecoration(
                    color: sel
                        ? p.mixColors(p.blue, 0.22)
                        : p.mixColors(Colors.white, 0.08),
                    border: Border.all(
                      color: sel ? p.blue : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$v', style: AVText.num(16, color: p.fg)),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: AVText.bodyStyle(10, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          'Time with the crew today',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        const SizedBox(height: 6),
        AVSelect<String>(
          value: social['crew'] as String,
          items: [for (final o in kCrewTimes) (o, o)],
          onChanged: (v) {
            if (v != null) {
              social['crew'] = v;
              st.stamp('loneliness_crew_interaction');
              st.notifyChange();
            }
          },
        ),
        const SizedBox(height: 8),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Partial source',
          srcNote: f.srcNote,
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class WeeklyBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const WeeklyBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final weekly = st.ent['weekly'] as Map<String, dynamic>;
    final complete = st.wk.every((v) => v > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last check-in: average ${(weekly['avg'] as num).toStringAsFixed(1)} of 5. Answer for this past week (1 never, 5 always).',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        const SizedBox(height: 10),
        for (var qi = 0; qi < kWeeklyQuestions.length; qi++) ...[
          Text(
            kWeeklyQuestions[qi],
            style: AVText.bodyStyle(13.5, color: p.fg),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(5, (i) {
              final v = i + 1;
              final sel = st.wk[qi] == v;
              return Expanded(
                child: GestureDetector(
                  onTap: () => st.setWkAnswer(qi, v),
                  child: Container(
                    margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                    constraints: const BoxConstraints(minHeight: 50),
                    decoration: BoxDecoration(
                      color: sel
                          ? p.mixColors(p.blue, 0.22)
                          : p.mixColors(Colors.white, 0.08),
                      border: Border.all(
                        color: sel ? p.blue : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text('$v', style: AVText.num(16, color: p.fg)),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
        ],
        AVButton(
          'Save this week',
          small: true,
          onPressed: complete ? st.saveWeekly : null,
        ),
        const SizedBox(height: 8),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Partial source',
          srcNote: f.srcNote,
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class JournalBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const JournalBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final journal = List<Map<String, dynamic>>.from(st.ent['journal'] as List);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JournalEntry(st: st),
        const SizedBox(height: 8),
        ...journal.asMap().entries.map((e) {
          final d = DateTime.fromMillisecondsSinceEpoch(e.value['ts'] as int);
          return ListRow(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.value['text'] as String,
                        style: AVText.bodyStyle(13.5, color: p.fg),
                      ),
                    ),
                    if (e.value['ex'] == true) const TagEx(),
                  ],
                ),
                Text(
                  '${d.day} ${_month(d.month)}',
                  style: AVText.bodyStyle(13, color: p.muted),
                ),
              ],
            ),
            right: AVButton(
              'Delete',
              small: true,
              ghost: true,
              onPressed: () => st.deleteJournal(e.key),
            ),
          );
        }),
        Text(
          'Private. Stays on this device unless you share it.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        SourceBadge(ts: (st.ent['ts'] as Map<String, int>)[f.id]),
      ],
    );
  }
}

String _month(int m) => [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][m - 1];

class _JournalEntry extends StatefulWidget {
  final AppState st;
  const _JournalEntry({required this.st});
  @override
  State<_JournalEntry> createState() => _JournalEntryState();
}

class _JournalEntryState extends State<_JournalEntry> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AVTextField(
          controller: _ctrl,
          maxLines: 3,
          maxLength: 1000,
          hint: 'A few lines about today',
          error: _error != null,
          onChanged: (v) {
            setState(() {
              _error = v.trim().isEmpty ? 'Write a line first.' : null;
            });
          },
        ),
        ErrorText(_error),
        const SizedBox(height: 8),
        AVButton(
          'Save entry',
          small: true,
          onPressed: _error == null && _ctrl.text.trim().isNotEmpty
              ? () {
                  widget.st.addJournal(_ctrl.text);
                  _ctrl.clear();
                  setState(() => _error = null);
                }
              : null,
        ),
      ],
    );
  }
}

class ReactionBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const ReactionBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final rt = st.rt;
    final l = st.fieldLevelOf(f);
    if (rt != null && rt.on) {
      final cls = rt.phase == 'go'
          ? p.blueD
          : rt.phase == 'bad'
          ? p.mixColors(Colors.white, 0.08)
          : p.mixColors(p.blue, 0.1);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: rt.phase == 'go' ? p.blueD : cls,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: st.rtTap,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      rt.phase == 'wait'
                          ? 'Wait for the colour to change'
                          : rt.phase == 'go'
                          ? 'Tap now'
                          : rt.msg,
                      textAlign: TextAlign.center,
                      style: AVText.displayStyle(
                        18,
                        w: FontWeight.w600,
                        color: rt.phase == 'go' ? Colors.white : p.fg,
                      ),
                    ),
                    Text(
                      'Trial ${mathMin(rt.times.length + 1, 5)} of 5',
                      style: AVText.bodyStyle(12, color: p.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SourceBadge(
            ts: (st.ent['ts'] as Map<String, int>)[f.id],
            tag: 'Partial source',
            srcNote: f.srcNote,
          ),
          Accordion(
            'Why we ask',
            children: [
              Text(f.why, style: AVText.bodyStyle(14, color: p.muted)),
            ],
          ),
        ],
      );
    }
    final rtEnt = st.ent['rt'] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${rtEnt['last']}',
          style: AVText.num(
            38,
            w: FontWeight.w600,
            color: p.tierT(mathMax(l.toDouble(), 0).round()),
          ),
        ),
        Text('ms median', style: AVText.bodyStyle(13, color: p.muted)),
        const SizedBox(height: 4),
        Text(
          'Your baseline: ${rtEnt['base']} ms. ${rt?.done == true ? 'New result saved.' : ''}',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        const SizedBox(height: 8),
        AVButton('Start quick check', small: true, onPressed: st.rtStart),
        const SizedBox(height: 8),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Partial source',
          srcNote: f.srcNote,
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class RateBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const RateBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final val = (st.ent[f.k!] ?? 3) as num;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final v = i + 1;
            final sel = val.round() == v;
            return Expanded(
              child: GestureDetector(
                onTap: () => st.setRate(f.k!, v),
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  constraints: const BoxConstraints(minHeight: 50),
                  decoration: BoxDecoration(
                    color: sel
                        ? p.mixColors(p.blue, 0.22)
                        : p.mixColors(Colors.white, 0.08),
                    border: Border.all(
                      color: sel ? p.blue : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$v', style: AVText.num(16, color: p.fg)),
                      Text(
                        f.labels![i],
                        textAlign: TextAlign.center,
                        style: AVText.bodyStyle(10, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Crew entry',
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class SleepClockBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const SleepClockBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final oBed = wrapDiff(_tmin(st.bed), _tmin(kPlanBed));
    final oUp = wrapDiff(_tmin(st.up), _tmin(kPlanUp));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SleepClock(planBed: kPlanBed, planUp: kPlanUp, bed: st.bed, up: st.up),
        const SizedBox(height: 8),
        Text(
          'Fell asleep ${oBed.abs()} min ${oBed >= 0 ? 'after' : 'before'} plan. Woke ${oUp.abs()} min ${oUp >= 0 ? 'after' : 'before'} plan.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        SourceBadge(
          ts: st.meta['sleep']?.ts,
          tag: 'Partial source',
          srcNote: f.srcNote,
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

int _tmin(String t) {
  final parts = t.split(':');
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

class DayBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const DayBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final e = st.env;
    final r = st.day / e.total;
    final ph = r < .33
        ? 'Early ${e.phase}'
        : r < .66
        ? 'Middle of ${e.phase}'
        : 'Late ${e.phase}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${st.day}',
              style: AVText.num(34, w: FontWeight.w600, color: p.fg),
            ),
            const SizedBox(width: 6),
            Text(
              'of ${e.total} days',
              style: AVText.bodyStyle(13, color: p.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AVMeter(r * 100),
        const SizedBox(height: 6),
        Text(
          '${ph[0].toUpperCase()}${ph.substring(1)}. ${e.n}, gravity ${e.g}.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        SourceBadge(ts: null, tag: 'Partial source', srcNote: f.srcNote),
        _DayForm(st: st),
        Accordion(
          'Why we show this',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class _DayForm extends StatefulWidget {
  final AppState st;
  const _DayForm({required this.st});
  @override
  State<_DayForm> createState() => _DayFormState();
}

class _DayFormState extends State<_DayForm> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.st.day.toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Accordion(
      'Enter manually',
      children: [
        FieldLabel(
          label: 'Mission day',
          child: AVTextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            error: _error != null,
            onChanged: (v) {
              setState(() {
                _error = validateMissionDay(v, widget.st.env.total).error;
              });
            },
          ),
        ),
        ErrorText(_error),
        const SizedBox(height: 8),
        AVButton(
          'Save',
          small: true,
          onPressed: _error == null && _ctrl.text.isNotEmpty
              ? () {
                  final day = int.tryParse(_ctrl.text);
                  if (day != null) {
                    widget.st.setDay(day);
                  }
                }
              : null,
        ),
      ],
    );
  }
}

class SeverityBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const SeverityBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Column(
      children: [
        SliderRow(
          k: 'sev',
          label: 'Worst symptom today (0 = none)',
          value: ((st.ent['sev'] ?? 0) as num).toDouble(),
          st: st,
        ),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Partial source',
          srcNote: f.srcNote,
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class DurationBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const DurationBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final dur = st.ent['dur'] as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How long has it lasted?',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        const SizedBox(height: 6),
        AVSelect<String>(
          value: dur.toString(),
          items: [
            ('-1', 'Nothing to report'),
            for (var i = 0; i < kDurs.length; i++) (i.toString(), kDurs[i]),
          ],
          onChanged: (v) {
            st.ent['dur'] = int.tryParse(v ?? '-1') ?? -1;
            st.stamp('symptom_duration');
            st.notifyChange();
          },
        ),
        const SizedBox(height: 8),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Crew entry',
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class MedsTakenBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const MedsTakenBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final sched = List<Map<String, dynamic>>.from(st.ent['sched'] as List);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sched.asMap().entries.map((e) {
          final m = e.value;
          final st2 = m['st'];
          return ListRow(
            Text(
              '${m['n']} · ${m['d']}  ${m['t']}',
              style: AVText.bodyStyle(13.5, color: p.fg),
            ),
            right: st2 == 'pending'
                ? Row(
                    children: [
                      AVButton(
                        'Taken',
                        small: true,
                        onPressed: () => st.medTake(e.key, 'taken'),
                      ),
                      const SizedBox(width: 6),
                      AVButton(
                        'Skip',
                        small: true,
                        ghost: true,
                        onPressed: () => st.medTake(e.key, 'skipped'),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      TierChip(st2 == 'taken' ? 0 : 1),
                      const SizedBox(width: 6),
                      AVButton(
                        'Undo',
                        small: true,
                        ghost: true,
                        onPressed: () => st.medTake(e.key, 'pending'),
                      ),
                    ],
                  ),
          );
        }),
        Text(
          'Log other doses in Medications below.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Crew entry',
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class HabitatBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const HabitatBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final e = st.env;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where are you based?',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        const SizedBox(height: 6),
        AVSelect<String>(
          value: st.envKey,
          items: [for (final ep in kEnvProfiles) (ep.key, ep.n)],
          onChanged: (v) {
            if (v != null) st.setEnv(v);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Gravity ${e.g}. Radiation limit ${e.limit} mSv. Message delay ${e.delayLabel()}.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class InvBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const InvBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final inv = List<Map<String, dynamic>>.from(st.ent['inv'] as List);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...inv.asMap().entries.map((e) {
          final it = e.value;
          final low = (it['c'] as num) < (it['min'] as num);
          return ListRow(
            Row(
              children: [
                Expanded(
                  child: Text(
                    it['n'] as String,
                    style: AVText.bodyStyle(13.5, color: p.fg),
                  ),
                ),
                if (low) const TierChip(1),
              ],
            ),
            right: Row(
              children: [
                Text('${it['c']}', style: AVText.num(17, color: p.fg)),
                const SizedBox(width: 8),
                AVButton(
                  'Used 1',
                  small: true,
                  ghost: true,
                  onPressed: (it['c'] as num) > 0
                      ? () => st.invUse(e.key)
                      : null,
                ),
              ],
            ),
          );
        }),
        _InvForm(st: st),
        PhotosPicker(bucket: 'inv', st: st),
        Text(
          'Barcode scanning needs the tablet camera. Type the code or attach a photo.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Partial source',
          srcNote: f.srcNote,
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class _InvForm extends StatefulWidget {
  final AppState st;
  const _InvForm({required this.st});
  @override
  State<_InvForm> createState() => _InvFormState();
}

class _InvFormState extends State<_InvForm> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(
          label: 'Item name or barcode',
          child: AVTextField(
            controller: _ctrl,
            maxLength: 40,
            error: _error != null,
            onChanged: (v) {
              setState(() {
                _error = v.trim().isEmpty
                    ? 'Enter an item name or barcode.'
                    : null;
              });
            },
          ),
        ),
        ErrorText(_error),
        const SizedBox(height: 8),
        AVButton(
          'Log use',
          small: true,
          onPressed: _error == null && _ctrl.text.trim().isNotEmpty
              ? () {
                  widget.st.invLogCode(_ctrl.text);
                  _ctrl.clear();
                  setState(() => _error = null);
                }
              : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class DelayBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const DelayBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final d = st.env.delayMin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              d == 0
                  ? 'Live'
                  : d < 1
                  ? '~${(d * 60).round()}'
                  : formatNum(d),
              style: AVText.num(34, w: FontWeight.w600, color: p.fg),
            ),
            const SizedBox(width: 6),
            Text(
              d == 0
                  ? 'near real time'
                  : d < 1
                  ? 'seconds one way'
                  : 'min one way',
              style: AVText.bodyStyle(13, color: p.muted),
            ),
          ],
        ),
        Text(
          d >= 1
              ? 'A question and its answer take about ${(d * 2).round()} minutes. Write one complete message with severity, duration and what you tried.'
              : 'Conversation with the ground is close to real time.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        SourceBadge(tag: 'Partial source', srcNote: f.srcNote),
        Accordion(
          'Why we show this',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class FlagBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const FlagBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final all = st.evaluate();
    final rs = <String>[];
    for (final a in all) {
      if (a.tier >= 3) rs.add(a.title);
    }
    if (st.ent['flagReq'] == true) rs.add('Requested by you');
    final on = rs.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusIcon(on ? 3 : 0, size: 22),
            const SizedBox(width: 8),
            Text(
              on ? 'Review suggested' : 'No flag',
              style: AVText.num(
                20,
                w: FontWeight.w600,
                color: on ? p.tierT(3) : p.tierT(0),
              ),
            ),
          ],
        ),
        if (on)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rs
                  .map(
                    (r) => Text(
                      '· $r',
                      style: AVText.bodyStyle(13.5, color: p.muted),
                    ),
                  )
                  .toList(),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Nothing needs review right now.',
              style: AVText.bodyStyle(13.5, color: p.muted),
            ),
          ),
        const SizedBox(height: 8),
        AVButton(
          st.ent['flagReq'] == true
              ? 'Review requested. Tap to withdraw'
              : 'Request flight surgeon review',
          small: true,
          ghost: st.ent['flagReq'] != true,
          onPressed: st.toggleFlagReq,
        ),
        Accordion(
          'Why we show this',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class PainBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const PainBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final pain = Map<String, int>.from(st.ent['pain'] ?? {});
    final marked = pain.entries.where((e) => e.value > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // .pain{display:flex;gap:10px;justify-content:center}
        // .pain svg{width:min(48%,150px);height:auto} - viewBox 110x246
        LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth.isFinite ? box.maxWidth : 320.0;
            final fw = mathMax(
              0,
              mathMin(mathMin(w * 0.48, 150.0), (w - 10) / 2),
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: fw,
                  child: PainFigure(
                    pain: pain,
                    selected: st.painSel,
                    back: false,
                    onTap: st.painTap,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: fw,
                  child: PainFigure(
                    pain: pain,
                    selected: st.painSel,
                    back: true,
                    onTap: st.painTap,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        // .legend{gap:12px;justify-content:center}
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              _legend(p.p1, 'Mild'),
              _legend(p.p2, 'Moderate'),
              _legend(p.p3, 'Severe'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap where it hurts. Each tap goes up one level: mild, moderate, severe, then clear.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        if (marked.isEmpty)
          ListRow(
            Text(
              'No pain marked.',
              style: AVText.bodyStyle(13.5, color: p.muted),
            ),
          )
        else
          ...marked.map(
            (e) => ListRow(
              Text(
                regionName(e.key),
                style: AVText.bodyStyle(13.5, color: p.fg),
              ),
              right: Text(
                ['', 'Mild', 'Moderate', 'Severe'][e.value],
                style: AVText.bodyStyle(13.5, color: p.muted),
              ),
            ),
          ),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Crew entry',
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) {
    return Builder(
      builder: (context) {
        final p = avp(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: c),
            const SizedBox(width: 5),
            Text(label, style: AVText.bodyStyle(11, color: p.muted)),
          ],
        );
      },
    );
  }
}

class FoodBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const FoodBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final food = st.ent['food'] as Map<String, dynamic>;
    const meals = [
      ['breakfast', 'Breakfast'],
      ['lunch', 'Lunch'],
      ['dinner', 'Dinner'],
      ['snack', 'Snack'],
    ];
    int sum = 0;
    food.forEach((_, v) => sum += (v as num).round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...meals.map((m) {
          final v = (food[m[0]] ?? 0) as num;
          return ListRow(
            Text(m[1], style: AVText.bodyStyle(13.5, color: p.fg)),
            right: AVSegment(
              options: const [('0', 'None'), ('1', 'Part'), ('2', 'Full')],
              value: v.toString(),
              onChanged: (val) => st.setMeal(m[0], int.tryParse(val) ?? 0),
            ),
          );
        }),
        const SizedBox(height: 8),
        AVMeter(sum / 8 * 100),
        const SizedBox(height: 6),
        Text(
          'Ration eaten so far: ${(sum / 8 * 100).round()}%.',
          style: AVText.bodyStyle(13.5, color: p.muted),
        ),
        PhotosPicker(bucket: 'food', st: st),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Partial source',
          srcNote: f.srcNote,
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}

class WaterBody extends StatelessWidget {
  final FieldDef f;
  final AppState st;
  const WaterBody({super.key, required this.f, required this.st});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    const goal = 2500.0;
    final w = (st.ent['water'] as num).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              (w / 1000).toStringAsFixed(2),
              style: AVText.num(34, w: FontWeight.w600, color: p.fg),
            ),
            const SizedBox(width: 6),
            Text(
              'of ${(goal / 1000).toStringAsFixed(1)} L goal',
              style: AVText.bodyStyle(13, color: p.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AVMeter(w / goal * 100),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AVButton('+250 mL', small: true, onPressed: () => st.addWater(250)),
            AVButton('+500 mL', small: true, onPressed: () => st.addWater(500)),
            AVButton(
              'Undo',
              small: true,
              ghost: true,
              onPressed: () => st.addWater(-250),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SourceBadge(
          ts: (st.ent['ts'] as Map<String, int>)[f.id],
          tag: 'Crew entry',
        ),
        Accordion(
          'Why we ask',
          children: [Text(f.why, style: AVText.bodyStyle(14, color: p.muted))],
        ),
      ],
    );
  }
}
