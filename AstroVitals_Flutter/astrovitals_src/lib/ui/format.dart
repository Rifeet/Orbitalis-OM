/// value formatting helpers - port of fmt() / sv() / usualText().
library;

import '../../core/contract/models.dart';
import '../../core/contract/zones.dart';
import '../../core/data/app_state.dart';
import '../../core/engine/engine.dart';

/// fmt(id, s) port - big card value
String fmtVal(AppState st, String id) {
  final s = st.cur;
  switch (id) {
    case 'bp':
      return '${s['sys'].round()}/${s['dia'].round()}';
    case 'temp':
    case 'ctemp':
      return s[id].toStringAsFixed(1);
    case 'sleep':
      return s['sleep'].toStringAsFixed(1);
    case 'mass':
      return s['mass'].toStringAsFixed(1);
    case 'rad':
      return s['radTotal'].round().toString();
    default:
      return s[metricDef(id).key].round().toString();
  }
}

/// sv(id, v) port - value + unit (stats tiles, drawer)
String svVal(AppState st, String id, double v) {
  final def = metricDef(id);
  final u = def.unit.isEmpty ? '' : ' ${def.unit}';
  if (id == 'sleep') return hm(v);
  if (id == 'temp' || id == 'mass' || id == 'ctemp') return '${v.toStringAsFixed(1)}$u';
  if (id == 'rad') return '${v.toStringAsFixed(2)}$u';
  return '${(v * 10).round() / 10}$u';
}

/// usualText(id) port
String usualText(AppState st, String id) {
  final k = metricDef(id).key;
  final b = kBase[k];
  if (b == null) return '';
  if (id == 'bp') {
    return 'Your usual: ${kBase['sys']!.round()}/${kBase['dia']!.round()} mmHg';
  }
  return 'Your usual: ${svVal(st, id, b)}';
}

/// statTiles(id) port - average / lowest / highest of the 14-day series
String statsLine(AppState st, String id) {
  final a = st.seriesFor(id);
  if (a.length < 2) return '';
  final avg = a.fold<double>(0, (t, v) => t + v) / a.length;
  final mn = a.reduce((x, y) => x < y ? x : y);
  final mx = a.reduce((x, y) => x > y ? x : y);
  return '${svVal(st, id, avg)} · low ${svVal(st, id, mn)} · high ${svVal(st, id, mx)}';
}
