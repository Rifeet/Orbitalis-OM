/// Zone tables (Z from the design): each zone is [from, to, level].
/// Values are grouped in a ZoneTable with an optional bar range used by the
/// range bar widget.
library;

class ZoneTable {
  final List<List<double>> z;
  final List<double>? bar;
  const ZoneTable(this.z, {this.bar});
}

const List<List<double>> hrZones = [
  [30, 35, 4], [35, 40, 3], [40, 45, 2], [45, 50, 1], [50, 90, 0],
  [90, 100, 1], [100, 110, 2], [110, 130, 3], [130, 200, 4],
];
const List<List<double>> sysZones = [
  [60, 70, 4], [70, 80, 3], [80, 85, 2], [85, 90, 1], [90, 130, 0],
  [130, 135, 1], [135, 140, 2], [140, 160, 3], [160, 220, 4],
];
const List<List<double>> diaZones = [
  [30, 40, 4], [40, 50, 3], [50, 55, 2], [55, 60, 1], [60, 85, 0],
  [85, 90, 1], [90, 95, 2], [95, 110, 3], [110, 160, 4],
];
const List<List<double>> spo2Zones = [
  [70, 90, 5], [90, 92, 3], [92, 94, 2], [94, 95, 1], [95, 101, 0],
];
const List<List<double>> gluZones = [
  [20, 54, 4], [54, 60, 3], [60, 70, 2], [70, 100, 0], [100, 110, 1],
  [110, 126, 2], [126, 180, 3], [180, 600, 4],
];
const List<List<double>> tempZones = [
  [32, 35, 3], [35, 35.5, 2], [35.5, 36.1, 1], [36.1, 37.3, 0],
  [37.3, 37.7, 1], [37.7, 38, 2], [38, 39, 3], [39, 43, 4],
];
const List<List<double>> sleepZones = [
  [0, 4, 4], [4, 5, 3], [5, 6, 2], [6, 7, 1], [7, 9, 0], [9, 10, 1], [10, 16, 2],
];
const List<List<double>> moodZones = [[1, 2, 3], [2, 3, 2], [3, 4, 1], [4, 5.1, 0]];
const List<List<double>> exZones = [[0, 30, 3], [30, 60, 2], [60, 90, 1], [90, 600, 0]];
const List<List<double>> radZones = [
  [0, 50, 0], [50, 70, 1], [70, 85, 2], [85, 100, 3], [100, 400, 4],
];
const List<List<double>> co2Zones = [
  [0, 3000, 0], [3000, 4000, 1], [4000, 5000, 2], [5000, 7000, 3],
  [7000, 10000, 4], [10000, 40000, 5],
];
const List<List<double>> humZones = [
  [0, 25, 3], [25, 30, 2], [30, 40, 1], [40, 60, 0], [60, 70, 1],
  [70, 75, 2], [75, 100, 3],
];
const List<List<double>> ctempZones = [
  [0, 16, 3], [16, 18, 2], [18, 20, 1], [20, 25, 0], [25, 27, 1],
  [27, 30, 2], [30, 50, 3],
];
const List<List<double>> noiseZones = [
  [20, 60, 0], [60, 65, 1], [65, 72, 2], [72, 85, 3], [85, 140, 4],
];
const List<List<double>> respZones = [
  [2, 8, 4], [8, 10, 3], [10, 12, 1], [12, 20, 0], [20, 24, 1],
  [24, 28, 2], [28, 34, 3], [34, 60, 4],
];
const List<List<double>> massZones = [
  [-30, -7, 4], [-7, -5, 3], [-5, -3, 2], [-3, -2, 1], [-2, 2, 0],
  [2, 3, 1], [3, 5, 2], [5, 7, 3], [7, 30, 4],
];

/// zl() port: find the level for value v; below the first zone or above the
/// last one clamps to the nearest zone's level.
int zoneLevel(List<List<double>> z, double v) {
  for (final zone in z) {
    if (v >= zone[0] && v < zone[1]) return zone[2].round();
  }
  return v < z[0][0] ? z[0][2].round() : z[z.length - 1][2].round();
}

/// personal baselines (BASE from the design)
const Map<String, double> kBase = {
  'hr': 68, 'sys': 114, 'dia': 74, 'glu': 92, 'temp': 36.6,
  'sleep': 7.0, 'mood': 4, 'spo2': 98, 'mass': 74.0,
};

/// planned sleep window (PLAN from the design)
const String kPlanBed = '22:30';
const String kPlanUp = '06:30';
