/// Unified data contract - the single source of truth shared by the front end
/// and the future back end (ported from "front-end & back-end variables.docx").
///
/// Fixes applied per the contract document:
///  * one name per metric: the UI id, the API metric name and the field id are
///    all declared in [MetricDef] (mapping table);
///  * radiation is split into `dose_rate` (mSv/day) and `cumulative_dose` (mSv)
///    with explicit units;
///  * times are UTC epoch milliseconds everywhere;
///  * the one-way delay is named `delayMin` (minutes);
///  * every reading carries `unit`;
///  * every reading carries a client-made `id` and `seq` so the offline queue
///    can resend safely;
///  * every reading carries `quality` (ok / stale / suspect).
library;

import 'zones.dart';

/// quality of a reading (contract section 2, Validation row)
enum ReadingQuality { ok, stale, suspect }

/// source of a reading
enum SourceKind { device, manual }

class SourceInfo {
  final SourceKind kind;
  final String device;
  final String route;
  final String type; // direct / partial / manual / none
  const SourceInfo({
    required this.kind,
    required this.device,
    this.route = '',
    this.type = 'direct',
  });

  Map<String, dynamic> toJson() =>
      {'kind': kind.name, 'device': device, 'route': route, 'type': type};

  static SourceInfo fromJson(Map<String, dynamic> j) => SourceInfo(
        kind: j['kind'] == 'manual' ? SourceKind.manual : SourceKind.device,
        device: j['device'] ?? '',
        route: j['route'] ?? '',
        type: j['type'] ?? 'direct',
      );
}

/// A single measurement, exactly the shape of POST /v1/readings body items.
class Reading {
  final String id; // client-made, ULID-ish
  final int seq; // client sequence number
  final String crewId;
  final String metric; // API metric name (see MetricRegistry)
  final String field; // field id, snake_case (see MetricRegistry)
  final double value;
  final String unit;
  final int time; // UTC epoch milliseconds
  final SourceInfo source;
  final ReadingQuality quality;
  final Map<String, dynamic> context; // mission_day, location

  const Reading({
    required this.id,
    required this.seq,
    required this.crewId,
    required this.metric,
    required this.field,
    required this.value,
    required this.unit,
    required this.time,
    required this.source,
    required this.quality,
    this.context = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'seq': seq,
        'crew_id': crewId,
        'metric': metric,
        'field': field,
        'value': value,
        'unit': unit,
        'time': time,
        'source': source.toJson(),
        'quality': quality.name,
        'context': context,
      };

  static Reading fromJson(Map<String, dynamic> j) => Reading(
        id: j['id'],
        seq: j['seq'] ?? 0,
        crewId: j['crew_id'] ?? 'c1',
        metric: j['metric'],
        field: j['field'] ?? '',
        value: (j['value'] as num).toDouble(),
        unit: j['unit'] ?? '',
        time: j['time'],
        source: SourceInfo.fromJson(Map<String, dynamic>.from(j['source'] ?? {})),
        quality: ReadingQuality.values.firstWhere(
          (q) => q.name == j['quality'],
          orElse: () => ReadingQuality.ok,
        ),
        context: Map<String, dynamic>.from(j['context'] ?? {}),
      );
}

/// A manual check-in entry, the shape of POST /v1/entries.
class CrewEntry {
  final String id;
  final int seq;
  final String field; // field id
  final Map<String, dynamic> payload;
  final int ts; // UTC epoch ms
  const CrewEntry({
    required this.id,
    required this.seq,
    required this.field,
    required this.payload,
    required this.ts,
  });
  Map<String, dynamic> toJson() =>
      {'id': id, 'seq': seq, 'field': field, 'payload': payload, 'ts': ts};
}

/// alert lifecycle (contract section 2, Alert log row)
enum AlertLifecycle { raised, shown, acknowledged, started, overridden, cleared }

/// One alert - the response shape of GET /v1/status and GET /v1/alerts.
class AlertItem {
  final String id;
  final String? metric; // API metric name, null for pattern / field alerts
  final String field;
  final int lvl; // zone level 0..5 (internal)
  final int tier; // what the user sees 0..4 (tierOf(lvl))
  final String title;
  final String obs;
  final List<String> acts;
  final String contact;
  final AlertLifecycle state;
  final int raisedAt; // UTC epoch ms
  final String? overrideReason;

  const AlertItem({
    required this.id,
    required this.metric,
    required this.field,
    required this.lvl,
    required this.tier,
    required this.title,
    required this.obs,
    required this.acts,
    required this.contact,
    this.state = AlertLifecycle.raised,
    required this.raisedAt,
    this.overrideReason,
  });

  AlertItem copyWith(
          {AlertLifecycle? state, String? overrideReason, int? raisedAt}) =>
      AlertItem(
        id: id,
        metric: metric,
        field: field,
        lvl: lvl,
        tier: tier,
        title: title,
        obs: obs,
        acts: acts,
        contact: contact,
        state: state ?? this.state,
        raisedAt: raisedAt ?? this.raisedAt,
        overrideReason: overrideReason ?? this.overrideReason,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'metric': metric,
        'field': field,
        'lvl': lvl,
        'tier': tier,
        'title': title,
        'obs': obs,
        'acts': acts,
        'contact': contact,
        'state': state.name,
        'raised_at': raisedAt,
        if (overrideReason != null) 'override_reason': overrideReason,
      };
}

/// Environment profile - ENV table from the design + contract names.
class EnvProfile {
  final String key;
  final String n; // display name
  final String endA;
  final String endB;
  final int total; // mission length in days
  final int day; // mission day used by the demo
  final String g; // gravity label
  final double dose; // expected dose rate mSv/day
  final double limit; // mission dose limit mSv
  final double delayMin; // one-way delay in minutes (contract name)
  final String phase;

  const EnvProfile({
    required this.key,
    required this.n,
    required this.endA,
    required this.endB,
    required this.total,
    required this.day,
    required this.g,
    required this.dose,
    required this.limit,
    required this.delayMin,
    required this.phase,
  });

  String delayLabel() {
    if (delayMin == 0) return 'Near real time';
    if (delayMin < 1) return 'about ${delayMin * 60.round()} s';
    return '${formatNum(delayMin)} min';
  }
}

const List<EnvProfile> kEnvProfiles = [
  EnvProfile(
      key: 'iss',
      n: 'Space station',
      endA: 'Launch',
      endB: 'Return',
      total: 180,
      day: 30,
      g: '0 g',
      dose: 0.6,
      limit: 50,
      delayMin: 0,
      phase: 'station increment'),
  EnvProfile(
      key: 'moon',
      n: 'Lunar base',
      endA: 'Landing',
      endB: 'Departure',
      total: 60,
      day: 21,
      g: '0.17 g',
      dose: 1.4,
      limit: 100,
      delayMin: 0.02,
      phase: 'surface stay'),
  EnvProfile(
      key: 'mars_transit',
      n: 'Transit vehicle',
      endA: 'Earth',
      endB: 'Mars',
      total: 270,
      day: 47,
      g: '0 g',
      dose: 1.8,
      limit: 250,
      delayMin: 20,
      phase: 'outbound transit'),
  EnvProfile(
      key: 'mars_surface',
      n: 'Mars base',
      endA: 'Landing',
      endB: 'Ascent',
      total: 500,
      day: 60,
      g: '0.38 g',
      dose: 0.7,
      limit: 100,
      delayMin: 20,
      phase: 'surface stay'),
];

/// Metric registry - the mapping table required by the contract ("one metric
/// has three names" fix). [api] is the metric name used in readings,
/// [field] is the snake_case field id used by POST /v1/entries.
class MetricDef {
  final String id; // UI id (hr, bp, ...)
  final String api; // API metric name
  final String field; // field id
  final String name; // display name
  final String unit;
  final String key; // series key in the demo store
  final int decimals;
  const MetricDef(this.id, this.api, this.field, this.name, this.unit,
      {required this.key, this.decimals = 0});
}

const List<MetricDef> kMetrics = [
  MetricDef('hr', 'heart_rate', 'heart_rate', 'Resting heart rate', 'bpm', key: 'hr'),
  MetricDef('bp', 'blood_pressure', 'blood_pressure', 'Blood pressure', 'mmHg',
      key: 'sys'),
  MetricDef('spo2', 'spo2', 'spo2', 'Blood oxygen', '%', key: 'spo2'),
  MetricDef('glu', 'blood_glucose', 'blood_glucose', 'Fasting glucose', 'mg/dL',
      key: 'glu'),
  MetricDef('temp', 'body_temperature', 'body_temperature', 'Body temperature',
      '°C', key: 'temp', decimals: 1),
  MetricDef('sleep', 'sleep_hours', 'sleep_hours_wakeups', 'Sleep last night', 'h',
      key: 'sleep', decimals: 1),
  MetricDef('mood', 'mood_daily', 'mood_daily', 'Mood', '/ 5', key: 'mood'),
  MetricDef('ex', 'exercise_minutes', 'exercise', 'Exercise today', 'min',
      key: 'ex'),
  MetricDef('rad', 'cumulative_dose', 'radiation_dose_msv',
      'Radiation, mission total', 'mSv', key: 'radTotal'),
  MetricDef('co2', 'co2_ppm', 'co2_ppm', 'Cabin CO₂', 'ppm', key: 'co2'),
  MetricDef('hum', 'cabin_humidity', 'cabin_humidity', 'Cabin humidity', '% RH',
      key: 'hum'),
  MetricDef('ctemp', 'cabin_temperature', 'cabin_temperature',
      'Cabin temperature', '°C', key: 'ctemp', decimals: 1),
  MetricDef('noise', 'cabin_noise', 'cabin_noise', 'Cabin noise', 'dBA',
      key: 'noise'),
  MetricDef('resp', 'respiratory_rate', 'respiratory_rate', 'Breathing rate',
      '/ min', key: 'resp'),
  MetricDef('mass', 'body_mass', 'body_mass', 'Body mass', 'kg', key: 'mass',
      decimals: 1),
];

const List<String> kAllMetrics = [
  'hr', 'bp', 'spo2', 'glu', 'temp', 'sleep', 'mood', 'ex', 'rad',
  'co2', 'hum', 'ctemp', 'noise', 'resp', 'mass'
];
const List<String> kCoreMetrics = [
  'hr', 'bp', 'spo2', 'glu', 'temp', 'sleep', 'mood', 'ex', 'rad'
];

MetricDef metricDef(String id) =>
    kMetrics.firstWhere((m) => m.id == id, orElse: () => kMetrics.first);

String formatNum(num v) {
  if (v == v.roundToDouble()) return v.round().toString();
  String s = v.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// zone table accessor shared by the engine
const Map<String, ZoneTable> kZoneByKey = {
  'hr': ZoneTable(hrZones, bar: [35, 130]),
  'sys': ZoneTable(sysZones, bar: [75, 170]),
  'dia': ZoneTable(diaZones),
  'spo2': ZoneTable(spo2Zones, bar: [84, 100]),
  'glu': ZoneTable(gluZones, bar: [50, 200]),
  'temp': ZoneTable(tempZones, bar: [34.5, 40]),
  'sleep': ZoneTable(sleepZones, bar: [2, 11]),
  'mood': ZoneTable(moodZones, bar: [1, 5]),
  'ex': ZoneTable(exZones, bar: [0, 150]),
  'rad': ZoneTable(radZones, bar: [0, 120]),
  'co2': ZoneTable(co2Zones, bar: [0, 10000]),
  'hum': ZoneTable(humZones, bar: [10, 90]),
  'ctemp': ZoneTable(ctempZones, bar: [14, 32]),
  'noise': ZoneTable(noiseZones, bar: [40, 90]),
  'resp': ZoneTable(respZones, bar: [6, 36]),
  'mass': ZoneTable(massZones, bar: [-10, 10]),
};
