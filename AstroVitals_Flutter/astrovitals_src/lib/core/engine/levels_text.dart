/// Observation texts (OBS from the design) and the per-field observation /
/// action strings (the obs/acts lambdas on F).
library;

import '../contract/models.dart';
import '../contract/fields.dart';
import '../contract/zones.dart';
import 'engine.dart';

String observationText(String id, EngineContext c) {
  final s = c.cur;
  switch (id) {
    case 'hr':
      return 'Resting heart rate is ${s['hr'].round()} bpm (your baseline: ${kBase['hr']!.round()}).';
    case 'bp':
      return 'Blood pressure is ${s['sys'].round()}/${s['dia'].round()} mmHg (your baseline: ${kBase['sys']!.round()}/${kBase['dia']!.round()}).';
    case 'spo2':
      return 'Blood oxygen is ${s['spo2'].round()}% (safe range: 90% or higher, usual for you: ${kBase['spo2']!.round()}%).';
    case 'glu':
      return 'Fasting glucose is ${s['glu'].round()} mg/dL (your baseline: ${kBase['glu']!.round()}).';
    case 'temp':
      return 'Body temperature is ${s['temp'].toStringAsFixed(1)} °C (your baseline: ${kBase['temp']}).';
    case 'sleep':
      return 'Last night: ${hm(s['sleep'])} (your average: ${hm(kBase['sleep']!)}).';
    case 'mood':
      return 'Mood logged as ${s['mood'].round()} of 5 (your usual: ${kBase['mood']!.round()}).';
    case 'ex':
      return 'Exercise today: ${s['ex'].round()} min (plan: 90 min).';
    case 'rad':
      return 'Mission dose is ${s['radTotal'].round()} mSv, ${mv(c, 'rad').round()}% of the ${c.env.limit} mSv limit. Today: ${s['rad'].toStringAsFixed(2)} mSv (typical here: ${formatNum(c.env.dose)}).';
    case 'co2':
      return 'Cabin CO₂ is ${s['co2'].round()} ppm (comfortable: under 3,000).';
    case 'hum':
      return 'Cabin humidity is ${s['hum'].round()}% (comfortable: 40 to 60%).';
    case 'ctemp':
      return 'Cabin temperature is ${s['ctemp'].toStringAsFixed(1)} °C (comfortable: 20 to 25 °C).';
    case 'noise':
      return 'Noise is ${s['noise'].round()} dBA (comfortable: under 60).';
    case 'resp':
      return 'Breathing rate is ${s['resp'].round()} per minute (usual: 12 to 20).';
    case 'mass':
      final p = mv(c, 'mass');
      return 'Body mass is ${s['mass'].toStringAsFixed(1)} kg, ${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)}% from baseline ${kBase['mass']!.toStringAsFixed(1)}.';
  }
  return '';
}

List<String> _acts(List<String> a) => a;

/// fieldObs() port
String fieldObs(String fieldId, EngineContext c) {
  final e = c.ent;
  switch (fieldId) {
    case 'symptom_checklist':
      final a = List<String>.from(e['sym'] ?? []);
      return 'You noted: ${a.join(', ')}.';
    case 'stress_fatigue_workload':
      final s = Map<String, dynamic>.from(e['stress'] ?? {});
      return 'Stress ${s['stress']}, fatigue ${s['fatigue']} and workload ${s['workload']} out of 10.';
    case 'loneliness_crew_interaction':
      final conn = (e['social']?['conn'] ?? 4) as num;
      const labels = ['not at all', 'a little', 'somewhat', 'mostly', 'very'];
      return 'You feel ${labels[(conn.round() - 1).clamp(0, 4)]} connected to the crew today.';
    case 'weekly_questionnaire':
      final avg = (e['weekly']?['avg'] ?? 4.1) as num;
      return 'Weekly check-in average is ${avg.toStringAsFixed(1)} of 5.';
    case 'reaction_time_test':
      final rt = Map<String, dynamic>.from(e['rt'] ?? {});
      return 'Reaction time is ${rt['last']} ms (your baseline: ${rt['base']} ms).';
    case 'sleep_quality':
      return 'You rated last night’s sleep ${e['sleepq']} of 5.';
    case 'sleep_vs_mission_clock':
      final o = sleepOffsets(c);
      return 'You fell asleep ${o['bed']!.abs()} min ${o['bed']! >= 0 ? 'after' : 'before'} the planned $kPlanBed.';
    case 'symptom_severity':
      final dur = e['dur'] ?? -1;
      return 'Worst symptom today is ${e['sev']} of 10${dur >= 0 ? ', for ${kDurs[dur].toLowerCase()}' : ''}.';
    case 'medical_inventory':
      return 'Running low: ${lowStock(c).map((i) => '${i['n']} (${i['c']} left, minimum ${i['min']})').join(', ')}.';
    case 'pain_by_region':
      final p = Map<String, dynamic>.from(e['pain'] ?? {});
      final a = <String>[];
      p.forEach((k, v) {
        if ((v as num) >= 2) {
          a.add('${regionName(k)} (${['', 'mild', 'moderate', 'severe'][v.round()]})');
        }
      });
      return 'Pain noted: ${a.join(', ')}.';
    case 'dizziness_vision_congestion':
      final a = List<String>.from(e['dizzy'] ?? []);
      return 'You noted: ${a.join(', ')}.';
    case 'symptoms_headache_rash':
      final a = List<String>.from(e['head'] ?? []);
      return 'You noted: ${a.join(', ')}.';
  }
  return '';
}

/// fieldActs() port
List<String> fieldActs(String fieldId, EngineContext c) {
  switch (fieldId) {
    case 'symptom_checklist':
      return _acts([
        'Rest and drink water.',
        'Note when each symptom started.',
        'Talk to the flight surgeon if they continue or get stronger.'
      ]);
    case 'stress_fatigue_workload':
      return _acts([
        'Plan one lighter block in today’s schedule.',
        'Take a 10-minute break away from screens.',
        'Talk to a crewmate or the flight surgeon if it stays high.'
      ]);
    case 'loneliness_crew_interaction':
      return _acts([
        'Share a meal with the crew today.',
        'Plan a call with family in the next comms window.',
        'Talk to the flight surgeon or behavioural health team if this continues.'
      ]);
    case 'weekly_questionnaire':
      return _acts([
        'Look at which answers were lowest.',
        'Plan one change for next week, such as an earlier wind-down.',
        'Talk to the flight surgeon if it keeps falling.'
      ]);
    case 'reaction_time_test':
      return _acts([
        'Take a short rest and re-test in an hour.',
        'Avoid precision tasks until you have rested.',
        'Talk to the flight surgeon if it stays slow.'
      ]);
    case 'sleep_quality':
      return _acts([
        'Dim cabin lights and screens for an hour before bed.',
        'Keep tonight’s sleep window fixed.',
        'Use ear plugs and an eye mask.'
      ]);
    case 'sleep_vs_mission_clock':
      return _acts([
        'Start your wind-down 30 minutes earlier tonight.',
        'Get bright light soon after waking.',
        'Keep the planned window, even on days off.'
      ]);
    case 'symptom_severity':
      return _acts([
        'Write down what you notice and when it started.',
        'Rest and drink water.',
        'Send the flight surgeon one complete message with severity, duration and what helped.'
      ]);
    case 'medical_inventory':
      return _acts([
        'Check for a substitute item in the kit.',
        'Add the item to the next supply request.',
        'Ration if needed and tell the flight surgeon.'
      ]);
    case 'pain_by_region':
      return _acts([
        'Rest the area and stretch gently.',
        'Check your posture and restraints during exercise.',
        'Talk to the flight surgeon if it lasts more than 2 days.'
      ]);
    case 'dizziness_vision_congestion':
      return _acts([
        'Rest with your head slightly raised if you can.',
        'Note how long it lasts and what makes it better.',
        'Talk to the flight surgeon about any vision change.'
      ]);
    case 'symptoms_headache_rash':
      return _acts([
        'Check cabin CO₂ and move to a well-ventilated module.',
        'Drink water and rest.',
        'Talk to the flight surgeon if it continues past a day.'
      ]);
  }
  return [];
}
