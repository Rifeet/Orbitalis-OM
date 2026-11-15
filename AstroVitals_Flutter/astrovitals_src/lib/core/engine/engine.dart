/// Level engine - port of the design's mv/lv/zl/tierOf/idx functions plus the
/// rule-based alert engine (evaluate) and organ levels.
library;

import '../contract/models.dart';
import '../contract/zones.dart';
import '../contract/fields.dart';
import 'levels_text.dart';

/// status names for the six levels
const List<String> kTierNames = [
  'Normal', 'Monitor', 'Advisory', 'Action soon', 'Act now', 'Emergency'
];
const List<int> kScore = [100, 85, 65, 40, 20, 0];
const List<int> kCap = [100, 89, 79, 64, 49, 34];

int tierOf(int l) => l <= 0 ? 0 : l <= 2 ? l : l <= 4 ? 3 : 4;

/// Snapshot: one day of readings + sleep extras.
class Snapshot {
  final Map<String, double> v; // by series key
  final int wake;
  final String bed;
  final String up;
  const Snapshot(this.v, {required this.wake, required this.bed, required this.up});
  double operator [](String k) => v[k] ?? 0;
}

/// The evaluation context passed in from state.
class EngineContext {
  final Snapshot cur;
  final List<double> Function(String metricId) series;
  final EnvProfile env;
  final Map<String, dynamic> ent;
  final Map<String, int> entTs; // field id -> epoch ms (last stamp)
  final Map<String, String> metaSource; // key -> 'device' | 'manual'
  final int day;
  final bool flagReq;
  const EngineContext({
    required this.cur,
    required this.series,
    required this.env,
    required this.ent,
    required this.entTs,
    required this.metaSource,
    required this.day,
    required this.flagReq,
  });
}

/// mv() port - mapped value per metric id
double mv(EngineContext c, String id) {
  final s = c.cur;
  switch (id) {
    case 'bp':
      return s['sys'];
    case 'rad':
      return s['radTotal'] / c.env.limit * 100;
    case 'mass':
      return (s['mass'] - (kBase['mass'] ?? 74)) / (kBase['mass'] ?? 74) * 100;
    default:
      final d = metricDef(id);
      return s[d.key];
  }
}

/// lv() port - zone level per metric id
int lv(EngineContext c, String id) {
  final s = c.cur;
  if (id == 'bp') {
    return maxLevel(zoneLevel(sysZones, s['sys']), zoneLevel(diaZones, s['dia']));
  }
  if (id == 'rad') {
    final r = s['rad'] / c.env.dose;
    final dl = r < 1.5 ? 0 : r < 3 ? 2 : r < 6 ? 3 : 4;
    return maxLevel(
        zoneLevel(radZones, mv(c, 'rad')), dl);
  }
  final t = kZoneByKey[id]!;
  return zoneLevel(t.z, mv(c, id));
}

int maxLevel(int a, int b) => a >= b ? a : b;

/// fieldLevel() port - level of a field (dev metrics + custom rules)
int fieldLevel(EngineContext c, FieldDef f) {
  if (f.metric != null) return lv(c, f.metric!);
  switch (f.id) {
    case 'symptom_checklist':
      final a = List<String>.from(c.ent['sym'] ?? []);
      if (a.isEmpty) return 0;
      if (a.contains('Vomiting')) return 3;
      return a.length >= 3 ? 2 : 1;
    case 'stress_fatigue_workload':
      final s = Map<String, dynamic>.from(c.ent['stress'] ?? {});
      final m = [
        (s['stress'] ?? 0) as num,
        (s['fatigue'] ?? 0) as num,
        (s['workload'] ?? 0) as num
      ].reduce((a, b) => a > b ? a : b);
      return m >= 8 ? 2 : m >= 6 ? 1 : 0;
    case 'loneliness_crew_interaction':
      final conn = (c.ent['social']?['conn'] ?? 4) as num;
      return conn <= 2 ? 2 : conn == 3 ? 1 : 0;
    case 'weekly_questionnaire':
      final avg = (c.ent['weekly']?['avg'] ?? 4.1) as num;
      return avg >= 4 ? 0 : avg >= 3 ? 1 : avg >= 2 ? 2 : 3;
    case 'reaction_time_test':
      final rt = Map<String, dynamic>.from(c.ent['rt'] ?? {});
      final last = (rt['last'] ?? 268) as num;
      final base = (rt['base'] ?? 252) as num;
      final r = last / base;
      return r < 1.1 ? 0 : r < 1.2 ? 1 : r < 1.35 ? 2 : 3;
    case 'sleep_quality':
      final q = (c.ent['sleepq'] ?? 3) as num;
      return q <= 2 ? 1 : 0;
    case 'sleep_vs_mission_clock':
      final src = c.metaSource['sleep'];
      if (src != 'device' && src != 'manual') return -1;
      final o = sleepOffsets(c);
      final m = o['bed']!.abs();
      return m < 30 ? 0 : m < 75 ? 1 : 2;
    case 'symptom_severity':
      final sev = (c.ent['sev'] ?? 0) as num;
      int l = sevLevel(sev.toDouble());
      if (l >= 2 && (c.ent['dur'] ?? -1) >= 3) l = (l + 1).clamp(0, 4);
      return l;
    case 'medical_inventory':
      return lowStock(c).isNotEmpty ? 1 : 0;
    case 'pain_by_region':
      final p = Map<String, dynamic>.from(c.ent['pain'] ?? {});
      int m = 0;
      p.forEach((_, v) {
        if ((v as num) > m) m = v.round();
      });
      return m >= 3 ? 2 : m == 2 ? 1 : 0;
    case 'dizziness_vision_congestion':
      final a = List<String>.from(c.ent['dizzy'] ?? []);
      if (a.isEmpty) return 0;
      if (a.contains('Blurred vision')) return 3;
      return a.length >= 2 ? 2 : 1;
    case 'symptoms_headache_rash':
      final n = (List<String>.from(c.ent['head'] ?? [])).length;
      return n == 0 ? 0 : n == 1 ? 1 : 2;
  }
  return -1;
}

/// sevLevel port
int sevLevel(double x) => x <= 0 ? 0 : x <= 3 ? 1 : x <= 6 ? 2 : x <= 8 ? 3 : 4;

int toMin(String t) {
  final p = t.split(':');
  if (p.length < 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

int wrapDiff(int a, int b) {
  int d = a - b;
  while (d > 720) {
    d -= 1440;
  }
  while (d < -720) {
    d += 1440;
  }
  return d;
}

Map<String, int> sleepOffsets(EngineContext c) {
  return {
    'bed': wrapDiff(toMin(c.cur.bed), toMin(kPlanBed)),
    'up': wrapDiff(toMin(c.cur.up), toMin(kPlanUp)),
  };
}

List<Map<String, dynamic>> lowStock(EngineContext c) {
  final inv = List<Map<String, dynamic>>.from(c.ent['inv'] ?? []);
  return inv.where((i) => (i['c'] as num) < (i['min'] as num)).toList();
}

/// hzLevel port - worst level across a hazard's fields
int hzLevel(EngineContext c, String hz) {
  int m = 0;
  for (final f in kFields) {
    if (f.hz == hz) {
      final l = fieldLevel(c, f);
      m = maxLevel(m, l < 0 ? 0 : l);
    }
  }
  return m;
}

/// pageLevel port
int pageLevel(EngineContext c, String page) {
  int m = 0;
  for (final f in pageFields(page)) {
    final l = fieldLevel(c, f);
    m = maxLevel(m, l < 0 ? 0 : l);
  }
  return m;
}

/// organ level port
int organLevel(EngineContext c, String o) {
  int m = 0;
  for (final id in organDef(o).ind) {
    m = maxLevel(m, lv(c, id));
  }
  return m;
}

String worstOrgan(EngineContext c) {
  String best = kOrganOrder.first;
  int bj = -1;
  for (final o in kOrganOrder) {
    final l = organLevel(c, o);
    if (l > bj) {
      bj = l;
      best = o;
    }
  }
  return best;
}

/// idxAt port - health index at index i of the 14-day series
int idxAt(List<Snapshot> snaps, EnvProfile env, int i) {
  final s = snaps[i];
  final c = EngineContext(
      cur: s,
      series: (_) => [],
      env: env,
      ent: const {},
      entTs: const {},
      metaSource: const {},
      day: env.day,
      flagReq: false);
  int t = 0, w = 0;
  for (final id in kAllMetrics) {
    final l = lv(c, id);
    t += kScore[l];
    if (l > w) w = l;
  }
  return (t / kAllMetrics.length).round() <= kCap[w]
      ? (t / kAllMetrics.length).round()
      : kCap[w];
}

int idxLevel(num v) =>
    v >= 90 ? 0 : v >= 80 ? 1 : v >= 65 ? 2 : v >= 50 ? 3 : v >= 35 ? 4 : 5;

/// contactText port
String contactText(EnvProfile env, int t, int l) {
  final d = env.delayLabel();
  if (t <= 2) return 'Talk to the flight surgeon if this continues.';
  if (t == 3 && l == 3) {
    return 'Do this within the next few hours, then report at the next comms window (one-way delay: $d).';
  }
  if (t == 3) {
    return 'Act now, then report at the next comms window (one-way delay: $d).';
  }
  return 'Notify the crew commander and ground control now.';
}

/// evaluate() port - the rule-based alert engine.
/// Returns raw alerts; lifecycle state is applied by the app state layer.
List<AlertItem> evaluateAlerts(EngineContext c) {
  final s = c.cur;
  final out = <AlertItem>[];
  final now = DateTime.now().millisecondsSinceEpoch;

  int hrL = lv(c, 'hr'), sleepL = lv(c, 'sleep'), moodL = lv(c, 'mood');
  final pattern = hrL >= 1 && sleepL >= 1 && moodL >= 1;

  for (final id in kAllMetrics) {
    final l = lv(c, id);
    if (l < 1) continue;
    if (pattern && (id == 'hr' || id == 'sleep' || id == 'mood')) continue;
    final t = tierOf(l);
    final info = kInfo[id]!;
    List<String> acts = List<String>.from(l <= 2 ? info.act[1]! : info.act[2]!);
    if (t == 4) {
      acts = id == 'spo2'
          ? [
              'Start the supplemental oxygen procedure',
              'Notify the crew commander',
              'Notify ground control and override comms priority'
            ]
          : [
              'Follow the emergency procedure for this reading',
              'Notify the crew commander',
              'Notify ground control and override comms priority'
            ];
    }
    final def = metricDef(id);
    out.add(AlertItem(
      id: id,
      metric: def.api,
      field: def.field,
      lvl: l,
      tier: t,
      title: id == 'rad' ? 'Radiation dose' : def.name,
      obs: observationText(id, c),
      acts: acts,
      contact: contactText(c.env, t, l),
      raisedAt: now,
    ));
  }

  if (pattern) {
    final ml = [hrL, sleepL, moodL].reduce((a, b) => a > b ? a : b);
    final pt = (tierOf(ml) < 2 ? 2 : tierOf(ml)).clamp(0, 3);
    out.add(AlertItem(
      id: 'pattern',
      metric: null,
      field: 'sleep_hours_wakeups',
      lvl: ml,
      tier: pt,
      title: 'Pattern detected',
      obs:
          'Resting heart rate is ${s['hr'].round()} bpm, sleep was ${hm(s['sleep'])} and mood is ${s['mood'].round()} of 5. Together they differ from your baseline over the same days.',
      acts: [
        'Plan a lighter day if the schedule allows.',
        'Keep tonight’s sleep window fixed and dim the lights an hour earlier.',
        'Talk to the flight surgeon if this continues for three days.'
      ],
      contact: contactText(c.env, pt, ml),
      raisedAt: now,
    ));
  }

  for (final f in kFields) {
    if (f.kind == 'dev') continue; // custom rules only (lvl lambdas)
    final l = fieldLevel(c, f);
    if (l < 1) continue;
    final t = tierOf(l);
    out.add(AlertItem(
      id: 'f_${f.id}',
      metric: null,
      field: f.id,
      lvl: l,
      tier: t,
      title: f.label,
      obs: fieldObs(f.id, c),
      acts: fieldActs(f.id, c),
      contact: contactText(c.env, t, l),
      raisedAt: now,
    ));
  }

  out.sort((a, b) {
    final byTier = b.tier.compareTo(a.tier);
    return byTier != 0 ? byTier : b.lvl.compareTo(a.lvl);
  });
  return out;
}

/// hm() port - hours to '7h 12m'
String hm(double h) {
  final t = (h * 60).round();
  final m = t % 60;
  return '${t ~/ 60}h ${m.toString().padLeft(2, '0')}m';
}

String ageText(int ts, int now) {
  final m = ((now - ts) / 60000).round();
  if (m < 1) return 'Updated just now';
  if (m < 60) return 'Updated $m min ago';
  if (m < 48 * 60) return 'Updated ${(m / 60).round()} h ago';
  return 'Updated ${(m / 1440).round()} days ago';
}

bool sameDay(int ts, DateTime now) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return d.year == now.year && d.month == now.month && d.day == now.day;
}
