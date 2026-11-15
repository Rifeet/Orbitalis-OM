/// Demo data generation - port of the design's SCEN/START/AMP/nz/rnd/build.
/// Generates 14-day series with a deterministic noise function so demo runs
/// are repeatable (contract: "Noise and seed - fixed seed for repeatable runs").
library;

import 'dart:math' as math;

import '../contract/limits.dart';
import '../contract/models.dart';

const int kN = 14;

/// demo scenarios
class ScenDef {
  final String id, label;
  final Map<String, double> end;
  final int wake;
  final String bed, up;
  final double radX;
  const ScenDef(this.id, this.label, this.end, this.wake, this.bed, this.up, this.radX);
}

const Map<String, ScenDef> kScen = {
  'nominal': ScenDef('nominal', 'Nominal day', {
    'hr': 70, 'sys': 118, 'dia': 76, 'glu': 94, 'temp': 36.7, 'sleep': 6.4,
    'mood': 4, 'spo2': 97, 'ex': 95, 'co2': 3200, 'hum': 46, 'ctemp': 22.4,
    'noise': 58, 'resp': 15, 'mass': 73.6,
  }, 2, '23:42', '06:08', 1),
  'sleep': ScenDef('sleep', 'Strained week', {
    'hr': 93, 'sys': 132, 'dia': 86, 'glu': 104, 'temp': 36.9, 'sleep': 5.2,
    'mood': 2, 'spo2': 96, 'ex': 40, 'co2': 3600, 'hum': 44, 'ctemp': 23.1,
    'noise': 64, 'resp': 17, 'mass': 73.2,
  }, 5, '01:10', '06:20', 1),
  'spe': ScenDef('spe', 'Solar storm', {
    'hr': 82, 'sys': 122, 'dia': 78, 'glu': 98, 'temp': 37.4, 'sleep': 5.9,
    'mood': 3, 'spo2': 96, 'ex': 60, 'co2': 3300, 'hum': 45, 'ctemp': 22.6,
    'noise': 62, 'resp': 16, 'mass': 73.4,
  }, 3, '00:05', '06:00', 5.2),
  'air': ScenDef('air', 'Cabin air event (urgent alert)', {
    'hr': 96, 'sys': 130, 'dia': 84, 'glu': 100, 'temp': 36.9, 'sleep': 6.1,
    'mood': 3, 'spo2': 87, 'ex': 70, 'co2': 8200, 'hum': 41, 'ctemp': 24.2,
    'noise': 63, 'resp': 24, 'mass': 73.5,
  }, 3, '23:50', '06:02', 1),
};

const List<String> kScenOrder = ['nominal', 'sleep', 'spe', 'air'];

const Map<String, double> kStart = {
  'hr': 68, 'sys': 114, 'dia': 74, 'glu': 92, 'temp': 36.6, 'sleep': 7.1,
  'mood': 4, 'spo2': 98, 'ex': 95, 'rad': 1, 'co2': 2800, 'hum': 45,
  'ctemp': 22, 'noise': 57, 'resp': 14, 'mass': 74.0,
};

const Map<String, double> kAmp = {
  'hr': 3, 'sys': 4, 'dia': 3, 'glu': 3, 'temp': 0.12, 'sleep': 0.5,
  'mood': 0.5, 'spo2': 0.6, 'ex': 10, 'rad': 0.15, 'co2': 150, 'hum': 2,
  'ctemp': 0.3, 'noise': 1.5, 'resp': 1, 'mass': 0.15,
};

const List<String> kSeriesKeys = [
  'hr', 'sys', 'dia', 'glu', 'temp', 'sleep', 'mood', 'spo2', 'ex', 'rad',
  'co2', 'hum', 'ctemp', 'noise', 'resp', 'mass', 'radTotal'
];

/// deterministic noise, port of nz()
double nz(int i, int k) {
  final x = (i * 12.9898 + k * 78.233) * 43758.5453;
  final frac = x - x.floorToDouble();
  return frac - 0.5;
}

/// rounding rules, port of rnd()
double rnd(String k, double v) {
  if (k == 'temp' || k == 'sleep' || k == 'mass' || k == 'ctemp') {
    return (v * 10).roundToDouble() / 10;
  }
  if (k == 'rad') return v < 0 ? 0 : (v * 100).roundToDouble() / 100;
  if (k == 'mood') return v.clamp(1, 5).roundToDouble();
  return v.roundToDouble();
}

class ReadingMeta {
  final String source; // device | manual
  final String device;
  final String route;
  final String kind; // direct | partial | manual | none
  final int ts; // epoch ms
  const ReadingMeta(this.source, this.device, this.route, this.kind, this.ts);
}

class DemoBuild {
  final Map<String, List<double>> hist;
  final Map<String, ReadingMeta> meta;
  final Map<String, double> end;
  final int wake;
  final String bed, up;
  final double radTotal;
  const DemoBuild(this.hist, this.meta, this.end, this.wake, this.bed, this.up, this.radTotal);
}

/// build() port - generate the 14-day demo store for a profile + scenario
DemoBuild buildDemo(EnvProfile env, String scenKey) {
  final sc = kScen[scenKey]!;
  final end = Map<String, double>.from(sc.end);
  end['rad'] = (env.dose * sc.radX * 100).roundToDouble() / 100;
  final total = ((env.dose * env.day + (end['rad']! - env.dose)) * 10).roundToDouble() / 10;

  final hist = <String, List<double>>{};
  final keys = kSeriesKeys.where((k) => k != 'radTotal').toList();
  for (var ki = 0; ki < keys.length; ki++) {
    final key = keys[ki];
    final a = <double>[];
    for (var i = 0; i < kN; i++) {
      final p = i / (kN - 1);
      double v;
      if (key == 'rad') {
        v = env.dose + nz(i, ki) * 2 * kAmp['rad']!;
      } else {
        v = (kStart[key] ?? 0) +
            (end[key]! - (kStart[key] ?? 0)) * math.pow(p, 1.6).toDouble() +
            nz(i, ki) * 2 * (kAmp[key] ?? 0);
      }
      a.add(rnd(key, v));
    }
    a[kN - 1] = rnd(key, end[key]!);
    hist[key] = a;
  }

  final rt = List<double>.filled(kN, 0);
  rt[kN - 1] = total;
  for (var i = kN - 2; i >= 0; i--) {
    rt[i] = ((rt[i + 1] - hist['rad']![i + 1]) * 100).roundToDouble() / 100;
  }
  hist['radTotal'] = rt;

  final now = DateTime.now().millisecondsSinceEpoch;
  final meta = <String, ReadingMeta>{};
  for (final key in kSeriesKeys) {
    final d = kDevices[key == 'radTotal' ? 'rad' : key];
    meta[key] = d != null
        ? ReadingMeta('device', d.device, d.route, d.kind, now - d.ageMin * 60000)
        : ReadingMeta('manual', 'Crew entry', '', 'none', now - 5 * 3600000);
  }

  return DemoBuild(hist, meta, end, sc.wake, sc.bed, sc.up, total);
}
