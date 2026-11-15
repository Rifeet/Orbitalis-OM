/// Central app state - port of the design's `st` object plus its action
/// handlers. Single ChangeNotifier; UI rebuilds through AnimatedBuilder.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../contract/api_contract.dart';
import '../contract/fields.dart';
import '../contract/models.dart';
import '../engine/engine.dart';
import '../validation/validators.dart';
import 'demo_data.dart';
import 'repository.dart';

enum DisplayMode { normal, night, eva }

class Selection {
  final String t; // none | organ | ind
  final String id;
  const Selection.none() : this._('none', '');
  const Selection._(this.t, this.id);
  const Selection.organ(String id) : this._('organ', id);
  const Selection.ind(String id) : this._('ind', id);
  bool get isNone => t == 'none';
}

class AppToast {
  final String msg;
  final VoidCallback? undo;
  const AppToast(this.msg, [this.undo]);
}

class ReactionTest {
  final bool on;
  final List<int> times;
  final String phase; // wait | go | bad
  final String msg;
  final bool done;
  final int t0;
  const ReactionTest({
    required this.on,
    required this.times,
    required this.phase,
    required this.msg,
    required this.done,
    this.t0 = 0,
  });
  ReactionTest copyWith({bool? on, List<int>? times, String? phase, String? msg, bool? done, int? t0}) =>
      ReactionTest(
        on: on ?? this.on,
        times: times ?? this.times,
        phase: phase ?? this.phase,
        msg: msg ?? this.msg,
        done: done ?? this.done,
        t0: t0 ?? this.t0,
      );
}

class AppState extends ChangeNotifier {
  // ---------- config ----------
  String envKey = 'mars_transit';
  String scenKey = 'nominal';
  String tab = 'overview';
  DisplayMode mode = DisplayMode.normal;
  String aidTab = 'faint';
  String painSel = '';
  bool showQueued = false;

  // ---------- demo store ----------
  Map<String, List<double>> hist = {};
  Map<String, ReadingMeta> meta = {};
  final Map<String, Map<String, dynamic>> devBackup = {}; // st.dev
  int wake = 2;
  String bed = '23:42';
  String up = '06:08';
  int day = 47;

  // ---------- crew entries (st.ent) ----------
  late Map<String, dynamic> ent;
  Map<String, int> entTs = {};

  // ---------- ui state ----------
  Selection sel = const Selection.none();
  final Map<String, bool> ack = {};
  final Map<String, bool> shown = {};
  final Map<String, bool> started = {};
  final Map<String, String> over = {};
  String? overOpen;
  String? urgId;
  bool u1 = false, u2 = false;
  List<int> wk = [0, 0, 0, 0, 0];
  ReactionTest? rt;
  Timer? _rtTimer;

  // ---------- profile ----------
  String profileName = 'Lena Ortiz';
  String profileRole = 'Flight engineer';
  bool welcomed = false;

  // ---------- session (auth pages) ----------
  bool signedIn = false;
  String sessionEmail = '';

  // ---------- services ----------
  final DemoRepository repo = DemoRepository();
  SyncQueue get syncQueue => repo.queue;
  AppToast? toastMsg;
  Timer? _toastTimer;

  EnvProfile get env => kEnvProfiles.firstWhere((e) => e.key == envKey);
  bool get dnd => mode != DisplayMode.normal;
  int get syncPending => syncQueue.pendingCount;

  // =====================================================================
  // boot / build
  // =====================================================================
  AppState() {
    ent = _defaultEnt();
    _rebuild();
  }

  Map<String, dynamic> _defaultEnt() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const H = 3600000;
    return {
      'sym': <String>[],
      'supp': <String>['Vitamin D', 'Omega-3'],
      'head': <String>[],
      'dizzy': <String>[],
      'meds': <Map<String, dynamic>>[],
      'sched': <Map<String, dynamic>>[
        {'n': 'Vitamin D3', 'd': '2000 IU', 't': '08:00', 'st': 'taken'},
        {'n': 'Melatonin', 'd': '3 mg', 't': '21:30', 'st': 'pending'},
      ],
      'stress': {'stress': 4, 'fatigue': 5, 'workload': 5},
      'social': {'conn': 4, 'crew': '30 to 60 min'},
      'weekly': {'avg': 4.1, 'ts': now - 3 * 86400000},
      'journal': <Map<String, dynamic>>[
        {
          'ts': now - 26 * H,
          'text': 'Good stretch of work in the lab. Missed the family call because of a schedule change.',
          'ex': true
        }
      ],
      'rt': {'last': 268, 'base': 252, 'ts': now - 2 * 86400000},
      'sleepq': 3,
      'sev': 0,
      'dur': -1,
      'flagReq': false,
      'pain': <String, int>{'lowerback': 1},
      'food': {'breakfast': 2, 'lunch': 1, 'dinner': 0, 'snack': 0},
      'water': 1250,
      'inv': <Map<String, dynamic>>[
        {'n': 'Ibuprofen 200 mg', 'c': 18, 'min': 6},
        {'n': 'Oxygen candle', 'c': 4, 'min': 3},
        {'n': 'Saline 500 mL', 'c': 6, 'min': 3},
        {'n': 'Glucose strips', 'c': 42, 'min': 10},
        {'n': 'Anti-nausea tablets', 'c': 9, 'min': 4},
        {'n': 'Sterile dressings', 'c': 30, 'min': 10},
      ],
      'invLog': <Map<String, dynamic>>[],
      'img': <String, List<String>>{'skin': [], 'ultra': [], 'rash': [], 'food': [], 'inv': []},
      'ts': <String, int>{
        'stress_fatigue_workload': now - 5 * H,
        'sleep_quality': now - 5 * H,
        'food_intake': now - 2 * H,
        'hydration': now - H,
        'supplements': now - 6 * H,
        'medications_taken': now - 6 * H,
        'weekly_questionnaire': now - 3 * 86400000,
        'reaction_time_test': now - 2 * 86400000,
      },
    };
  }

  void _rebuild() {
    final b = buildDemo(env, scenKey);
    hist = b.hist;
    meta = b.meta;
    devBackup.clear();
    wake = b.wake;
    bed = b.bed;
    up = b.up;
    day = env.day;
  }

  // =====================================================================
  // engine context + snapshots
  // =====================================================================
  Map<String, double> _valsAt(int i) {
    final m = <String, double>{};
    for (final k in kSeriesKeys) {
      m[k] = hist[k]?[i] ?? 0;
    }
    return m;
  }

  Snapshot snapshotAt(int i) =>
      Snapshot(_valsAt(i), wake: wake, bed: bed, up: up);

  Snapshot get cur => snapshotAt(kN - 1);

  List<Snapshot> get snaps => List.generate(kN, snapshotAt);

  EngineContext makeCtx() {
    final metaSource = <String, String>{};
    meta.forEach((k, v) => metaSource[k] = v.source);
    return EngineContext(
      cur: cur,
      series: (metricId) => hist[metricDef(metricId).key] ?? const [],
      env: env,
      ent: ent,
      entTs: ent['ts'] as Map<String, int>,
      metaSource: metaSource,
      day: day,
      flagReq: ent['flagReq'] == true,
    );
  }

  List<AlertItem> evaluate() => evaluateAlerts(makeCtx());

  List<AlertItem> get alerts {
    final all = evaluate();
    return all.map((a) {
      AlertLifecycle state = AlertLifecycle.raised;
      if (over[a.id] != null) {
        state = AlertLifecycle.overridden;
      } else if (started[a.id] == true) {
        state = AlertLifecycle.started;
      } else if (ack[a.id] == true) {
        state = AlertLifecycle.acknowledged;
      }
      return a.copyWith(
        state: state,
        overrideReason: over[a.id],
      );
    }).toList();
  }

  List<AlertItem> get visibleAlerts =>
      alerts.where((a) => a.tier >= 3 || !dnd).toList();
  List<AlertItem> get queuedAlerts =>
      dnd ? alerts.where((a) => a.tier < 3).toList() : [];

  // health index
  int get healthIndex => idxAt(snaps, env, kN - 1);
  int get healthIndexLevel => idxLevel(healthIndex);
  List<int> get indexSeries =>
      List.generate(kN, (i) => idxAt(snaps, env, i));

  // tasks
  bool loggedField(FieldDef f) {
    if (f.keys.isNotEmpty) {
      final m = meta[f.keys.first];
      final now = DateTime.now().millisecondsSinceEpoch;
      return m != null && now - m.ts < 86400000;
    }
    final t = (ent['ts'] as Map<String, int>)[f.id];
    return t != null && sameDay(t, DateTime.now());
  }

  bool taskIsDone(String taskId) {
    final ids = kTaskMap[taskId] ?? [];
    if (taskId == 'symptoms') return ids.any((i) => loggedField(kFieldById[i]!));
    return ids.every((i) => loggedField(kFieldById[i]!));
  }

  int get tasksDone => kTasks.where((t) => taskIsDone(t.id)).length;
  bool get todayDone => taskIsDone('sleep') && taskIsDone('mood');
  int get streakDays => 11 + (todayDone ? 1 : 0);

  // organs
  Map<String, int> get organLevels {
    final c = makeCtx();
    return {for (final o in kOrganOrder) o: organLevel(c, o)};
  }

  int hzLevelOf(String hz) => hzLevel(makeCtx(), hz);
  int pageLevelOf(String p) => pageLevel(makeCtx(), p);
  int fieldLevelOf(FieldDef f) => fieldLevel(makeCtx(), f);

  // series helpers
  List<double> seriesFor(String metricId) =>
      hist[metricDef(metricId).key] ?? const [];

  ReadingMeta? metaFor(FieldDef f) =>
      f.keys.isNotEmpty ? meta[f.keys.first] : null;

  bool hasDeviceBackup(String key) => devBackup.containsKey(key);

  // =====================================================================
  // toast
  // =====================================================================
  void toast(String msg, [VoidCallback? undo]) {
    toastMsg = AppToast(msg, undo);
    _toastTimer?.cancel();
    _toastTimer = Timer(Duration(milliseconds: undo != null ? 7000 : 3800), () {
      toastMsg = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void hideToast() {
    _toastTimer?.cancel();
    toastMsg = null;
    notifyListeners();
  }

  void runUndo() {
    final u = toastMsg?.undo;
    hideToast();
    u?.call();
  }

  void stamp(String fieldId) {
    (ent['ts'] as Map<String, int>)[fieldId] =
        DateTime.now().millisecondsSinceEpoch;
    repo.postEntry(CrewEntry(
      id: syncQueue.nextId('e'),
      seq: syncQueue.pendingCount,
      field: fieldId,
      payload: const {},
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // =====================================================================
  // navigation + selection
  // =====================================================================
  void setTab(String t) {
    tab = t;
    sel = const Selection.none();
    hideToast();
    notifyListeners();
  }

  void select(Selection s) {
    sel = s;
    notifyListeners();
  }

  void clearSelection() {
    sel = const Selection.none();
    notifyListeners();
  }

  void setAid(String id) {
    aidTab = id;
    notifyListeners();
  }

  void gotoAid(String id) {
    aidTab = id;
    tab = 'aid';
    sel = const Selection.none();
    notifyListeners();
  }

  // =====================================================================
  // env / scenario / mode
  // =====================================================================
  void setEnv(String k) {
    hideToast();
    envKey = k;
    _rebuild();
    _resetAlerts();
    sel = const Selection.none();
    repo.postContextConfirm(k, 'yes', {
      'gravity_g': env.delayMin,
      'delay_min': env.delayMin,
      'dose_rate_expected': env.dose,
    });
    notifyListeners();
  }

  void setScen(String k) {
    hideToast();
    scenKey = k;
    _rebuild();
    _resetAlerts();
    sel = const Selection.none();
    notifyListeners();
  }

  void setMode(DisplayMode m) {
    mode = m;
    notifyListeners();
  }

  void _resetAlerts() {
    ack.clear();
    shown.clear();
    over.clear();
    overOpen = null;
    u1 = false;
    u2 = false;
    urgId = null;
  }

  // =====================================================================
  // data layer: manual entries override device values (DL port)
  // =====================================================================
  void setManual(Map<String, double> vals, {bool quiet = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final readings = <Reading>[];
    vals.forEach((k, v) {
      final m = meta[k];
      if (m != null && m.source == 'device' && !devBackup.containsKey(k)) {
        devBackup[k] = {
          'v': hist[k]![kN - 1],
          'meta': m,
          if (k == 'rad') 'rt': hist['radTotal']![kN - 1],
        };
      }
      hist[k]![kN - 1] = rnd(k, v);
      meta[k] = ReadingMeta('manual', 'Manual entry', '', 'manual', now);
      if (k == 'rad') {
        hist['radTotal']![kN - 1] =
            ((hist['radTotal']![kN - 2] + v) * 100).roundToDouble() / 100;
        meta['radTotal'] = meta['rad']!;
      }
      // contract reading payload
      final def = _readingDef(k);
      if (def != null) {
        readings.add(Reading(
          id: syncQueue.nextId('r'),
          seq: syncQueue.pendingCount,
          crewId: ContractIdentity.crewId,
          metric: def.$1,
          field: def.$2,
          value: hist[k]![kN - 1],
          unit: def.$3,
          time: now,
          source: const SourceInfo(kind: SourceKind.manual, device: 'Manual entry', type: 'manual'),
          quality: ReadingQuality.ok,
          context: {'mission_day': day, 'location': envKey},
        ));
      }
    });
    repo.postReadings(readings);
    if (!quiet) toast('Saved. Queued for the next ground sync.');
    notifyListeners();
  }

  /// (api metric, field id, unit) per series key - contract mapping
  (String, String, String)? _readingDef(String key) {
    switch (key) {
      case 'hr':
        return ('heart_rate', 'heart_rate', 'bpm');
      case 'sys':
        return ('blood_pressure', 'blood_pressure', 'mmHg');
      case 'dia':
        return null; // reported with systolic
      case 'spo2':
        return ('spo2', 'spo2', '%');
      case 'glu':
        return ('blood_glucose', 'blood_glucose', 'mg/dL');
      case 'temp':
        return ('body_temperature', 'body_temperature', '°C');
      case 'sleep':
        return ('sleep_hours', 'sleep_hours_wakeups', 'h');
      case 'mood':
        return ('mood_daily', 'mood_daily', '/ 5');
      case 'ex':
        return ('exercise_minutes', 'exercise', 'min');
      case 'rad':
        return ('dose_rate', 'radiation_dose_msv', 'mSv/day');
      case 'co2':
        return ('co2_ppm', 'co2_ppm', 'ppm');
      case 'hum':
        return ('cabin_humidity', 'cabin_humidity', '%RH');
      case 'ctemp':
        return ('cabin_temperature', 'cabin_temperature', '°C');
      case 'noise':
        return ('cabin_noise', 'cabin_noise', 'dBA');
      case 'resp':
        return ('respiratory_rate', 'respiratory_rate', '/min');
      case 'mass':
        return ('body_mass', 'body_mass', 'kg');
    }
    return null;
  }

  void saveSleep(String bedT, String upT, int wakeUps) {
    final mins = ((toMin(upT) - toMin(bedT)) % 1440 + 1440) % 1440;
    final hrs = mins / 60;
    final now = DateTime.now().millisecondsSinceEpoch;
    bed = bedT;
    up = upT;
    wake = wakeUps;
    final m = meta['sleep'];
    if (m != null && m.source == 'device' && !devBackup.containsKey('sleep')) {
      devBackup['sleep'] = {'v': hist['sleep']![kN - 1], 'meta': m};
    }
    hist['sleep']![kN - 1] = rnd('sleep', (hrs * 10).roundToDouble() / 10);
    meta['sleep'] = ReadingMeta('manual', 'Manual entry', '', 'manual', now);
    repo.postReadings([
      Reading(
        id: syncQueue.nextId('r'),
        seq: syncQueue.pendingCount,
        crewId: ContractIdentity.crewId,
        metric: 'sleep_hours',
        field: 'sleep_hours_wakeups',
        value: (hrs * 10).roundToDouble() / 10,
        unit: 'h',
        time: now,
        source: const SourceInfo(kind: SourceKind.manual, device: 'Manual entry', type: 'manual'),
        quality: ReadingQuality.ok,
        context: {'mission_day': day, 'location': envKey},
      )
    ]);
    toast('Saved. Queued for the next ground sync.');
    notifyListeners();
  }

  void useDevice(String fieldId) {
    final f = kFieldById[fieldId];
    if (f == null) return;
    for (final k in f.keys) {
      final d = devBackup[k];
      if (d == null) continue;
      hist[k]![kN - 1] = (d['v'] as num).toDouble();
      meta[k] = d['meta'] as ReadingMeta;
      if (k == 'rad') {
        hist['radTotal']![kN - 1] = (d['rt'] as num).toDouble();
        meta['radTotal'] = d['meta'] as ReadingMeta;
      }
      devBackup.remove(k);
    }
    toast('Device feed restored.');
    notifyListeners();
  }

  void setDay(int v) {
    day = v;
    toast('Mission day updated.');
    notifyListeners();
  }

  // =====================================================================
  // field interactions
  // =====================================================================
  void toggleChip(String g, String value) {
    final list = List<String>.from(ent[g] ?? []);
    if (list.contains(value)) {
      list.remove(value);
    } else {
      list.add(value);
    }
    ent[g] = list;
    stamp(_chipField(g));
    notifyListeners();
  }

  String _chipField(String g) {
    switch (g) {
      case 'sym':
        return 'symptom_checklist';
      case 'supp':
        return 'supplements';
      case 'dizzy':
        return 'dizziness_vision_congestion';
      case 'head':
        return 'symptoms_headache_rash';
    }
    return '';
  }

  void setFace(double v) {
    setManual({'mood': v}, quiet: true);
    stamp('mood_daily');
    notifyListeners();
  }

  void setRate(String k, int v) {
    if (k == 'sleepq') {
      ent['sleepq'] = v;
      stamp('sleep_quality');
    } else {
      (ent['social'] as Map<String, dynamic>)['conn'] = v;
      stamp('loneliness_crew_interaction');
    }
    notifyListeners();
  }

  void setSlider(String k, double v) {
    if (k == 'sev') {
      ent['sev'] = v.round();
      stamp('symptom_severity');
    } else {
      (ent['stress'] as Map<String, dynamic>)[k] = v.round();
      stamp('stress_fatigue_workload');
    }
    notifyListeners();
  }

  void setWkAnswer(int q, int v) {
    wk[q] = v;
    notifyListeners();
  }

  void saveWeekly() {
    final v = validateWeekly(wk);
    if (!v.ok) {
      toast(v.error!);
      return;
    }
    final avg = wk.fold<double>(0, (a, b) => a + b) / wk.length;
    ent['weekly'] = {'avg': avg, 'ts': DateTime.now().millisecondsSinceEpoch};
    wk = [0, 0, 0, 0, 0];
    stamp('weekly_questionnaire');
    toast('Weekly check-in saved.');
    notifyListeners();
  }

  void addJournal(String text) {
    final v = validateJournal(text);
    if (!v.ok) {
      toast(v.error!);
      return;
    }
    (ent['journal'] as List).insert(0, {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'text': text.trim().substring(0, text.trim().length.clamp(0, 1000)),
      'ex': false,
    });
    stamp('journal');
    toast('Saved privately on this device.');
    notifyListeners();
  }

  void deleteJournal(int i) {
    final list = List<Map<String, dynamic>>.from(ent['journal'] as List);
    final removed = list.removeAt(i);
    ent['journal'] = list;
    notifyListeners();
    toast('Entry deleted.', () {
      final l2 = List<Map<String, dynamic>>.from(ent['journal'] as List);
      l2.insert(i, removed);
      ent['journal'] = l2;
      notifyListeners();
    });
  }

  void addPhoto(String bucket, String assetPath, bool isImage, int sizeBytes) {
    final img = ent['img'] as Map<String, List<String>>;
    final v = validatePhoto((img[bucket] ?? []).length, isImage, sizeBytes);
    if (!v.ok) {
      toast(v.error!);
      return;
    }
    (img[bucket] ??= []).add(assetPath);
    final fieldId = _imgField(bucket);
    if (bucket == 'skin' || bucket == 'ultra') stamp(fieldId);
    notifyListeners();
  }

  void removePhoto(String bucket, int i) {
    final img = ent['img'] as Map<String, List<String>>;
    img[bucket]?.removeAt(i);
    notifyListeners();
  }

  String _imgField(String b) {
    switch (b) {
      case 'skin':
        return 'skin_eye_images';
      case 'ultra':
        return 'ultrasound_images';
      case 'rash':
        return 'symptoms_headache_rash';
      case 'food':
        return 'food_intake';
      case 'inv':
        return 'medical_inventory';
    }
    return '';
  }

  void painTap(String region) {
    final p = Map<String, int>.from(ent['pain'] ?? {});
    final nl = ((p[region] ?? 0) + 1) % 4;
    if (nl > 0) {
      p[region] = nl;
    } else {
      p.remove(region);
    }
    ent['pain'] = p;
    painSel = region;
    stamp('pain_by_region');
    notifyListeners();
  }

  void setMeal(String m, int v) {
    (ent['food'] as Map<String, dynamic>)[m] = v;
    stamp('food_intake');
    notifyListeners();
  }

  void addWater(double delta) {
    final w = ((ent['water'] as num).toDouble() + delta).clamp(0.0, 10000.0);
    final v = validateWaterMl(w);
    if (!v.ok) {
      toast(v.error!);
      return;
    }
    ent['water'] = w;
    stamp('hydration');
    notifyListeners();
  }

  void medTake(int i, String st) {
    final sched = List<Map<String, dynamic>>.from(ent['sched'] as List);
    sched[i]['st'] = st;
    if (st != 'pending') stamp('medications_taken');
    notifyListeners();
  }

  void logMed(String name, String dose) {
    final v = validateMedName(name) ;
    if (!v.ok) {
      toast(v.error!);
      return;
    }
    final vd = validateMedDose(dose);
    if (!vd.ok) {
      toast(vd.error!);
      return;
    }
    (ent['meds'] as List).add({
      'n': name,
      'd': dose.trim(),
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    stamp('medications');
    toast('Dose logged.');
    notifyListeners();
  }

  void invUse(int i) {
    final inv = List<Map<String, dynamic>>.from(ent['inv'] as List);
    final it = inv[i];
    if ((it['c'] as num) <= 0) {
      toast('${it['n']} is already at zero.');
      return;
    }
    it['c'] = (it['c'] as num) - 1;
    stamp('medical_inventory');
    notifyListeners();
    toast('Logged one ${it['n']} as used.', () {
      it['c'] = (it['c'] as num) + 1;
      notifyListeners();
    });
  }

  void invLogCode(String code) {
    final v = validateInvCode(code);
    if (!v.ok) {
      toast(v.error!);
      return;
    }
    final t = code.trim().toLowerCase();
    final inv = List<Map<String, dynamic>>.from(ent['inv'] as List);
    final hit = inv.where((x) => (x['n'] as String).toLowerCase().contains(t)).toList();
    if (hit.isNotEmpty && (hit.first['c'] as num) > 0) {
      hit.first['c'] = (hit.first['c'] as num) - 1;
      toast('Logged use of ${hit.first['n']}.');
    } else {
      (ent['invLog'] as List).add({
        'code': code.trim(),
        'ts': DateTime.now().millisecondsSinceEpoch
      });
      toast('Item not in the list. Logged for the weekly export.');
    }
    stamp('medical_inventory');
    notifyListeners();
  }

  void noSymptoms() {
    ent['sym'] = <String>[];
    ent['sev'] = 0;
    ent['dur'] = -1;
    stamp('symptom_checklist');
    stamp('symptom_severity');
    toast('Logged: nothing to report today.');
    notifyListeners();
  }

  void toggleFlagReq() {
    ent['flagReq'] = !(ent['flagReq'] == true);
    if (ent['flagReq'] == true) {
      toast('Review requested. Message delay: ${env.delayLabel()} each way.');
    }
    notifyListeners();
  }

  void talkToFlightSurgeon() {
    ent['flagReq'] = true;
    toast('Message from $profileName to the flight surgeon is queued. One-way delay: ${env.delayLabel()}.');
    notifyListeners();
  }

  void saveProfile(String name, String role) {
    final v = validateProfileName(name);
    if (!v.ok) {
      toast(v.error!);
      return;
    }
    final vr = validateProfileRole(role);
    if (!vr.ok) {
      toast(vr.error!);
      return;
    }
    profileName = name.trim();
    profileRole = role.trim();
    toast('Profile saved.');
    notifyListeners();
  }

  void welcomeOk() {
    welcomed = true;
    notifyListeners();
  }

  // =====================================================================
  // session (sign in / sign up / sign out)
  // Demo build: the gateway accepts valid credentials locally and queues
  // the auth payload on the contract seam, so the future backend swap
  // keeps the same call sites.
  // =====================================================================
  bool signIn(String email, String password) {
    final res = repo.authSignIn(email.trim(), password);
    if (!res.ok) {
      toast(res.error!);
      return false;
    }
    signedIn = true;
    sessionEmail = email.trim().toLowerCase();
    toast('Signed in as $sessionEmail.');
    notifyListeners();
    return true;
  }

  bool signUp(String name, String role, String email, String password) {
    final res = repo.authSignUp(name.trim(), role.trim(), email.trim(), password);
    if (!res.ok) {
      toast(res.error!);
      return false;
    }
    profileName = name.trim();
    profileRole = role.trim();
    welcomed = false;
    signedIn = true;
    sessionEmail = email.trim().toLowerCase();
    toast('Account created. Welcome aboard, ${profileName.split(' ').first}.');
    notifyListeners();
    return true;
  }

  void signOut() {
    repo.authSignOut();
    signedIn = false;
    sessionEmail = '';
    tab = 'overview';
    sel = const Selection.none();
    toast('Signed out.');
    notifyListeners();
  }

  // =====================================================================
  // reaction test
  // =====================================================================
  void rtStart() {
    rt = const ReactionTest(on: true, times: [], phase: 'wait', msg: '', done: false);
    _rtNext();
    notifyListeners();
  }

  void _rtNext() {
    _rtTimer?.cancel();
    _rtTimer = Timer(
      Duration(milliseconds: 1000 + math.Random().nextInt(2000)),
      () {
        if (rt == null || !rt!.on) return;
        rt = rt!.copyWith(phase: 'go', t0: DateTime.now().millisecondsSinceEpoch);
        notifyListeners();
      },
    );
  }

  void rtTap() {
    final r = rt;
    if (r == null || !r.on) return;
    if (r.phase == 'wait') {
      _rtTimer?.cancel();
      rt = r.copyWith(phase: 'bad', msg: 'Too early. Tap again to retry');
      notifyListeners();
      return;
    }
    if (r.phase == 'bad') {
      _rtNext();
      notifyListeners();
      return;
    }
    final times = [...r.times, DateTime.now().millisecondsSinceEpoch - r.t0];
    if (times.length >= 5) {
      final sorted = [...times]..sort();
      final med = sorted[2];
      (ent['rt'] as Map<String, dynamic>)['last'] = med;
      (ent['ts'] as Map<String, int>)['reaction_time_test'] =
          DateTime.now().millisecondsSinceEpoch;
      rt = ReactionTest(on: false, times: times, phase: 'wait', msg: '', done: true);
      stamp('reaction_time_test');
      _rtTimer?.cancel();
      notifyListeners();
      return;
    }
    rt = r.copyWith(times: times);
    _rtNext();
    notifyListeners();
  }

  // =====================================================================
  // alert lifecycle
  // =====================================================================
  void ackAlert(String id) {
    ack[id] = true;
    repo.postAlertAction(id, 'ack');
    notifyListeners();
    toast('Acknowledged.', () {
      ack.remove(id);
      notifyListeners();
    });
  }

  void unackAlert(String id) {
    ack.remove(id);
    started.remove(id);
    over.remove(id);
    shown[id] = true;
    notifyListeners();
  }

  void startAlert(String id) {
    started[id] = true;
    ack[id] = true;
    repo.postAlertAction(id, 'start');
    notifyListeners();
    final a = evaluate().where((x) => x.id == id).toList();
    toast(
      a.isNotEmpty
          ? '${actLabelFor(a.first)} · logged. ${actNextFor(a.first)}'
          : 'Logged.',
      () {
        ack.remove(id);
        started.remove(id);
        notifyListeners();
      },
    );
  }

  void openOverride(String id) {
    overOpen = id;
    notifyListeners();
  }

  void saveOverride(String id, String reason) {
    over[id] = reason;
    ack[id] = true;
    overOpen = null;
    repo.postAlertAction(id, 'override', reason: reason);
    toast('Override recorded.');
    notifyListeners();
  }

  void showQueuedToggle() {
    showQueued = !showQueued;
    notifyListeners();
  }

  // urgent screen (tier 4)
  void toggleU1() {
    u1 = !u1;
    if (u1 && urgId != null) {
      repo.postEmergencyEvent('e_$urgId', 'answer', 'step_1', true);
    }
    notifyListeners();
  }

  void toggleU2() {
    u2 = !u2;
    if (u2 && urgId != null) {
      repo.postEmergencyEvent('e_$urgId', 'answer', 'step_2', true);
    }
    notifyListeners();
  }

  void urgentClose() {
    if (u1 && u2) {
      final id = urgId ??
          evaluate()
              .where((a) => a.tier == 4)
              .map((a) => a.id)
              .firstOrNull ??
          '';
      if (id.isNotEmpty) {
        ack[id] = true;
        started[id] = true;
        repo.postEmergencyEvent('e_$id', 'closed', 'confirmed', true);
      }
      u1 = false;
      u2 = false;
      urgId = null;
      notifyListeners();
    }
  }

  void urgentRemeasure(String fieldId, String alertId) {
    ack[alertId] = true;
    over[alertId] = 'Re-measuring';
    urgId = null;
    notifyListeners();
    gotoField(fieldId);
  }

  void reportUrgent(AlertItem a) {
    urgId = a.id;
    repo.postEmergencyStart(a.metric ?? 'emergency', DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  // helpers used by start buttons
  String actLabelFor(AlertItem a) {
    const actl = {
      'spo2': ['O₂ procedure started', 'Re-measure in 5 minutes.'],
      'rad': ['In storm shelter', 'Stay until mission control clears you.'],
      'co2': ['Moved to ventilated module', 'Re-check cabin CO₂ in 10 minutes.'],
      'temp': ['Resting and monitoring', 'Re-measure in an hour.'],
      'hr': ['Resting now', 'Re-measure in 15 minutes.'],
      'bp': ['Resting now', 'Re-measure in 15 minutes.'],
      'resp': ['Resting now', 'Re-measure in 5 minutes.'],
      'glu': ['Eaten or treated', 'Re-measure in 15 minutes.'],
      'ctemp': ['Moved to a comfortable module', 'Re-check in 30 minutes.'],
      'hum': ['Humidity control checked', 'Re-check in an hour.'],
      'noise': ['Hearing protection on', 'Re-check in an hour.'],
    };
    if (a.metric != null && actl.containsKey(_uiId(a.metric!))) {
      return actl[_uiId(a.metric!)]![0];
    }
    return 'Step 1 done';
  }

  String actNextFor(AlertItem a) {
    const actl = {
      'spo2': ['O₂ procedure started', 'Re-measure in 5 minutes.'],
      'rad': ['In storm shelter', 'Stay until mission control clears you.'],
      'co2': ['Moved to ventilated module', 'Re-check cabin CO₂ in 10 minutes.'],
      'temp': ['Resting and monitoring', 'Re-measure in an hour.'],
      'hr': ['Resting now', 'Re-measure in 15 minutes.'],
      'bp': ['Resting now', 'Re-measure in 15 minutes.'],
      'resp': ['Resting now', 'Re-measure in 5 minutes.'],
      'glu': ['Eaten or treated', 'Re-measure in 15 minutes.'],
      'ctemp': ['Moved to a comfortable module', 'Re-check in 30 minutes.'],
      'hum': ['Humidity control checked', 'Re-check in an hour.'],
      'noise': ['Hearing protection on', 'Re-check in an hour.'],
    };
    if (a.metric != null && actl.containsKey(_uiId(a.metric!))) {
      return actl[_uiId(a.metric!)]![1];
    }
    return 'Follow the remaining steps, then re-check.';
  }

  String _uiId(String api) {
    for (final m in kMetrics) {
      if (m.api == api) return m.id;
    }
    return api;
  }

  // gotoField: navigate to the field's page and scroll to it
  String? scrollTargetField;
  void gotoField(String fieldId) {
    final p = kFieldPage[fieldId];
    if (p == null) return;
    tab = p;
    sel = const Selection.none();
    scrollTargetField = fieldId;
    notifyListeners();
  }

  void gotoSection(String sectionId) {
    tab = 'checkin';
    sel = const Selection.none();
    scrollTargetField = 'sec:$sectionId';
    notifyListeners();
  }

  void consumeScrollTarget() {
    scrollTargetField = null;
  }

  /// public refresh hook used by widgets that mutate state directly
  void notifyChange() => notifyListeners();

  @override
  void dispose() {
    _rtTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }
}
