/// The 40 fields (F from the design), the five hazards (HZ), region names and
/// the option lists. Field kinds decide the input tool; src documents the
/// source status shown on the card.
library;

class HazardDef {
  final String id, n, short, blurb;
  final List<String> cut;
  const HazardDef(this.id, this.n, this.short, this.blurb, this.cut);
}

const List<HazardDef> kHazards = [
  HazardDef('rad', 'Space radiation', 'Radiation',
      'Cosmic rays and solar particles pass through the hull and through us. Dose adds up over the mission and can raise long-term cancer, heart and nervous-system risk. We track dose, early symptoms and how the body is responding.',
      ['Read the dosimeter on schedule.', 'Move to the shelter during a solar storm.', 'Report skin, eye or stomach symptoms early.']),
  HazardDef('iso', 'Isolation and confinement', 'Isolation',
      'Months in a small crew, far from home, strain sleep, mood and attention. Small changes show up here before they show up in performance.',
      ['Keep a fixed sleep window and morning light.', 'Plan regular contact with family and crew time.', 'Log mood daily. Patterns matter more than single days.']),
  HazardDef('dist', 'Distance from Earth', 'Distance',
      'Help is days away and messages take minutes. We keep records, supplies and decisions ready, so we can act first and consult the flight surgeon with clear facts.',
      ['Write your question in one complete message.', 'Check supplies every week.', 'Log symptoms with severity and duration.']),
  HazardDef('grav', 'Gravity fields', 'Gravity',
      'Weightlessness, and partial gravity on the Moon or Mars, unload bones, muscles and the heart and shift fluid toward the head. Exercise is the main protection.',
      ['Do resistive and aerobic training every day.', 'Watch for vision changes and dizziness.', 'Track body mass, pain and heart readings.']),
  HazardDef('env', 'Hostile, closed environment', 'Environment',
      'A sealed cabin recycles its own air and water. CO₂, humidity, temperature and noise, plus food and fluids, all change how we feel.',
      ['Keep air moving and check the CO₂ readout.', 'Eat the full ration and drink to your goal.', 'Report rashes, cough or headaches.']),
];

/// kinds: dev | mood | chips | photos | meds | sliders | social | weekly |
/// journal | rt | rate | sleepclock | day | sev | dur | medstaken | habitat |
/// inv | delay | flag | pain | food | water
class FieldDef {
  final String id;
  final String hz;
  final String label;
  final String kind;
  final String? metric; // ui metric id for dev cards
  final List<String> keys; // series keys it reads/writes
  final String? g; // chips group
  final List<String>? opts;
  final String? b; // photos bucket
  final String? k; // rate key
  final List<String>? labels;
  final String src; // none | partial | direct
  final String? srcNote;
  final bool log;
  final String why;
  final String? photo;
  const FieldDef({
    required this.id,
    required this.hz,
    required this.label,
    required this.kind,
    this.metric,
    this.keys = const [],
    this.g,
    this.opts,
    this.b,
    this.k,
    this.labels,
    this.src = 'none',
    this.srcNote,
    this.log = true,
    this.why = '',
    this.photo,
  });
}

const kSymRad = [
  'Light flashes in vision', 'Nausea', 'Vomiting', 'Fatigue', 'Skin redness',
  'Eye irritation', 'Headache', 'Loss of appetite'
];
const kSupps = [
  'Vitamin D', 'Calcium', 'Omega-3', 'Vitamin K2', 'Multivitamin',
  'Protein shake', 'Electrolytes'
];
const kMeds = [
  'Acetaminophen', 'Ibuprofen', 'Anti-nausea tablet', 'Melatonin', 'Sleep aid',
  'Antihistamine', 'Decongestant', 'Other'
];
const kDizzy = [
  'Dizzy when standing', 'Blurred vision', 'Head fullness',
  'Hard to focus up close', 'Nausea'
];
const kHead = [
  'Headache', 'Skin rash', 'Itchy or watery eyes', 'Sore throat', 'Cough',
  'Stuffy nose', 'Dry skin'
];
const kDurs = [
  'Under 1 hour', 'A few hours', 'Since this morning', '1 to 2 days',
  '3 days or more', 'A week or more'
];
const kCrewTimes = ['None', 'Under 30 min', '30 to 60 min', '1 to 3 h', 'Over 3 h'];

const List<FieldDef> kFields = [
  // radiation
  FieldDef(id: 'radiation_dose_msv', hz: 'rad', label: 'Radiation dose', kind: 'dev', metric: 'rad', keys: ['rad']),
  FieldDef(id: 'symptom_checklist', hz: 'rad', label: 'Symptom checklist', kind: 'chips', g: 'sym', opts: kSymRad,
      why: 'Nausea, skin redness or light flashes can be early signs of a high dose. Tap anything you notice, even if it is small.'),
  FieldDef(id: 'skin_eye_images', hz: 'rad', label: 'Skin and eye photos', kind: 'photos', b: 'skin',
      why: 'A photo gives the flight surgeon something to compare over time. Use even light, hold steady and include a coin or ruler for scale.'),
  FieldDef(id: 'spo2', hz: 'env', label: 'Blood oxygen', kind: 'dev', metric: 'spo2', keys: ['spo2']),
  FieldDef(id: 'body_temperature', hz: 'env', label: 'Body temperature', kind: 'dev', metric: 'temp', keys: ['temp']),
  FieldDef(id: 'medications', hz: 'rad', label: 'Medications', kind: 'meds',
      why: 'Logging each dose helps us spot side effects and avoid doubling up. Pick from the list and add the dose.'),
  FieldDef(id: 'supplements', hz: 'rad', label: 'Supplements', kind: 'chips', g: 'supp', opts: kSupps,
      why: 'Vitamin D, calcium and omega-3 matter more in flight, where bones and the immune system are under strain. Tap what you took today.'),
  // isolation
  FieldDef(id: 'mood_daily', hz: 'iso', label: 'Mood today', kind: 'mood', metric: 'mood', keys: ['mood']),
  FieldDef(id: 'stress_fatigue_workload', hz: 'iso', label: 'Stress, fatigue and workload', kind: 'sliders', src: 'partial', srcNote: 'Self-rating scales on the station laptops',
      why: 'Rating these three each day shows strain building before it affects sleep or work. 0 is none, 10 is the most you can imagine.'),
  FieldDef(id: 'loneliness_crew_interaction', hz: 'iso', label: 'Connection and crew time', kind: 'social', src: 'partial', srcNote: 'Questionnaire on the RSE-Med laptop',
      why: 'Feeling connected, and time spent with the crew, protect mood over long missions. Answer for today.'),
  FieldDef(id: 'weekly_questionnaire', hz: 'iso', label: 'Weekly check-in', kind: 'weekly', src: 'partial', srcNote: 'Weekly questionnaires run as crew tasks',
      why: 'Five short questions once a week give a steadier picture than any single day.'),
  FieldDef(id: 'journal', hz: 'iso', label: 'Private journal', kind: 'journal',
      why: 'Writing a few lines helps process the day. Entries are private and stay on this device unless you choose to share them.'),
  FieldDef(id: 'reaction_time_test', hz: 'iso', label: 'Reaction time check', kind: 'rt', src: 'partial', srcNote: 'Full 3-minute test runs on the station laptop',
      why: 'Slower reactions are an early, objective sign of fatigue. This quick check takes about 30 seconds.'),
  FieldDef(id: 'sleep_hours_wakeups', hz: 'iso', label: 'Sleep and wake-ups', kind: 'dev', metric: 'sleep', keys: ['sleep']),
  FieldDef(id: 'sleep_quality', hz: 'iso', label: 'Sleep quality', kind: 'rate', k: 'sleepq', labels: ['Poor', 'Fair', 'OK', 'Good', 'Great'],
      why: 'How rested you feel matters as much as the hours. Rate last night.'),
  FieldDef(id: 'sleep_vs_mission_clock', hz: 'iso', label: 'Sleep against the mission clock', kind: 'sleepclock', src: 'partial', log: false,
      why: 'Sleeping at the planned time keeps our body clock steady. This compares your sleep with the planned window.'),
  // distance
  FieldDef(id: 'mission_day_phase', hz: 'dist', label: 'Mission day and phase', kind: 'day', src: 'partial', srcNote: 'Mission clock, official schedule', log: false,
      why: 'Knowing the phase helps us expect what comes next. Motivation and sleep often dip in the middle of a long mission.'),
  FieldDef(id: 'symptom_severity', hz: 'dist', label: 'Symptom severity', kind: 'sev', src: 'partial', srcNote: 'Dose tracker style rating',
      why: 'If something feels off, rate the worst of it. 0 means nothing to report. Add how long it has lasted below.'),
  FieldDef(id: 'symptom_duration', hz: 'dist', label: 'Symptom duration', kind: 'dur',
      why: 'Duration tells the flight surgeon whether something is passing or needs attention.'),
  FieldDef(id: 'medications_taken', hz: 'dist', label: 'Medications taken', kind: 'medstaken',
      why: 'Marking each scheduled dose as taken or skipped keeps the record right when the ground team cannot see it.'),
  FieldDef(id: 'habitat_type', hz: 'dist', label: 'Habitat type', kind: 'habitat', log: false,
      why: 'Set this once. It changes the radiation limit, gravity and message delay we use.'),
  FieldDef(id: 'medical_inventory', hz: 'dist', label: 'Medical inventory', kind: 'inv', src: 'partial', srcNote: 'Weekly inventory export',
      why: 'Resupply is far away, so we check what is left every week.'),
  FieldDef(id: 'communication_delay', hz: 'dist', label: 'Message delay', kind: 'delay', src: 'partial', srcNote: 'Spacecraft bus', log: false,
      why: 'With a long delay, a back-and-forth chat is not possible. Plan questions to be complete in one message.'),
  FieldDef(id: 'flight_surgeon_review_flag', hz: 'dist', label: 'Flight surgeon review', kind: 'flag', log: false,
      why: 'AstroVitals flags items that need a flight surgeon’s eyes. You can also ask for a review yourself.'),
  // gravity
  FieldDef(id: 'exercise', hz: 'grav', label: 'Exercise today', kind: 'dev', metric: 'ex', keys: ['ex']),
  FieldDef(id: 'pain_by_region', hz: 'grav', label: 'Pain by region', kind: 'pain',
      why: 'Tap where it hurts. Each tap goes up one level: mild, moderate, severe, then clear. Back and neck pain are common in weightlessness.'),
  FieldDef(id: 'body_mass', hz: 'grav', label: 'Body mass', kind: 'dev', metric: 'mass', keys: ['mass']),
  FieldDef(id: 'heart_rate', hz: 'grav', label: 'Resting heart rate', kind: 'dev', metric: 'hr', keys: ['hr']),
  FieldDef(id: 'blood_pressure', hz: 'grav', label: 'Blood pressure', kind: 'dev', metric: 'bp', keys: ['sys', 'dia']),
  FieldDef(id: 'ultrasound_images', hz: 'grav', label: 'Ultrasound images', kind: 'photos', b: 'ultra', src: 'direct', srcNote: 'Portable ultrasound, guided from the ground',
      why: 'Scans give the ground team a look at bones, muscle and blood vessels. Upload exports from the scanner here.'),
  FieldDef(id: 'dizziness_vision_congestion', hz: 'grav', label: 'Dizziness, vision, congestion', kind: 'chips', g: 'dizzy', opts: kDizzy, src: 'partial', srcNote: 'Vision questionnaire',
      why: 'Fluid shifts toward the head can bring dizziness, head fullness and blurred vision. Tap anything you notice.'),
  // environment
  FieldDef(id: 'co2_ppm', hz: 'env', label: 'Cabin CO₂', kind: 'dev', metric: 'co2', keys: ['co2']),
  FieldDef(id: 'cabin_humidity', hz: 'env', label: 'Cabin humidity', kind: 'dev', metric: 'hum', keys: ['hum']),
  FieldDef(id: 'cabin_temperature', hz: 'env', label: 'Cabin temperature', kind: 'dev', metric: 'ctemp', keys: ['ctemp']),
  FieldDef(id: 'cabin_noise', hz: 'env', label: 'Cabin noise', kind: 'dev', metric: 'noise', keys: ['noise']),
  FieldDef(id: 'respiratory_rate', hz: 'env', label: 'Breathing rate', kind: 'dev', metric: 'resp', keys: ['resp']),
  FieldDef(id: 'food_intake', hz: 'env', label: 'Food intake', kind: 'food', src: 'partial', srcNote: 'Food log, details not documented',
      why: 'Eating the full ration protects weight, bones and mood. Mark each meal.'),
  FieldDef(id: 'hydration', hz: 'env', label: 'Hydration', kind: 'water',
      why: 'Thirst is dulled in weightlessness, so we drink to a goal. Tap each time you finish a drink.'),
  FieldDef(id: 'blood_glucose', hz: 'env', label: 'Blood glucose', kind: 'dev', metric: 'glu', keys: ['glu']),
  FieldDef(id: 'symptoms_headache_rash', hz: 'env', label: 'Headache, rash and irritation', kind: 'chips', g: 'head', opts: kHead, photo: 'rash',
      why: 'Headaches can point to high CO₂. Rashes, dry skin and irritated eyes come from dust and dry air. Add a photo for rashes.'),
];

final Map<String, FieldDef> kFieldById = {
  for (final f in kFields) f.id: f
};

/// pain regions (FRONT / BACK from the design): id, shape, cx, cy, rx/w, ry/h
/// shape: c circle | e ellipse | r rect
const List<List<dynamic>> kFrontRegions = [
  ['head', 'c', 55, 20, 15, 0],
  ['neck', 'r', 48, 34, 14, 10],
  ['shoulderL', 'e', 30, 52, 12, 9],
  ['shoulderR', 'e', 80, 52, 12, 9],
  ['chest', 'r', 38, 46, 34, 30],
  ['abdomen', 'r', 40, 78, 30, 28],
  ['armL', 'r', 14, 60, 12, 52],
  ['armR', 'r', 84, 60, 12, 52],
  ['hip', 'r', 38, 108, 34, 18],
  ['thighL', 'r', 38, 128, 15, 44],
  ['thighR', 'r', 57, 128, 15, 44],
  ['kneeL', 'c', 45.5, 178, 8, 0],
  ['kneeR', 'c', 64.5, 178, 8, 0],
  ['shinL', 'r', 38, 188, 14, 38],
  ['shinR', 'r', 58, 188, 14, 38],
];
const List<List<dynamic>> kBackRegions = [
  ['neckback', 'r', 48, 34, 14, 10],
  ['upperback', 'r', 36, 46, 38, 30],
  ['lowerback', 'r', 40, 78, 30, 28],
  ['glute', 'r', 38, 108, 34, 18],
  ['hamL', 'r', 38, 128, 15, 44],
  ['hamR', 'r', 57, 128, 15, 44],
  ['calfL', 'r', 38, 188, 14, 38],
  ['calfR', 'r', 58, 188, 14, 38],
];

const Map<String, String> kRegionNames = {
  'head': 'Head', 'neck': 'Neck', 'shoulderL': 'Left shoulder',
  'shoulderR': 'Right shoulder', 'chest': 'Chest', 'abdomen': 'Abdomen',
  'armL': 'Left arm', 'armR': 'Right arm', 'hip': 'Hips',
  'thighL': 'Left thigh', 'thighR': 'Right thigh', 'kneeL': 'Left knee',
  'kneeR': 'Right knee', 'shinL': 'Left shin', 'shinR': 'Right shin',
  'neckback': 'Back of neck', 'upperback': 'Upper back',
  'lowerback': 'Lower back', 'glute': 'Buttocks', 'hamL': 'Left hamstring',
  'hamR': 'Right hamstring', 'calfL': 'Left calf', 'calfR': 'Right calf',
};

String regionName(String r) => kRegionNames[r] ?? r;

/// organs for the body map (ORG from the design)
class OrganDef {
  final String id, name, fn, haz, prev;
  final List<String> ind;
  const OrganDef(this.id, this.name, this.fn, this.haz, this.prev, this.ind);
}

const List<OrganDef> kOrgans = [
  OrganDef('brain', 'Brain and mind', 'Runs sleep, mood, attention and decisions.',
      'Isolation, confinement and a broken light cycle wear down sleep and mood. High CO₂ and radiation can also affect thinking.',
      'Hold a fixed sleep window, use morning light and keep regular contact with family.', ['sleep', 'mood']),
  OrganDef('heart', 'Heart and circulation', 'Pumps blood and adjusts to every posture and workload.',
      'Fluid shifts and the missing load of gravity deplete the heart’s fitness. Radiation may add to long-term cardiovascular risk.',
      'Do aerobic training most days and keep hydration steady.', ['hr', 'bp', 'resp']),
  OrganDef('lungs', 'Lungs', 'Move oxygen into the blood and carbon dioxide out.',
      'CO₂ pockets, dust and cabin pressure changes matter. Lunar dust is sharp and irritating.',
      'Keep air moving, clean filters and know where CO₂ is read out.', ['spo2', 'co2']),
  OrganDef('metab', 'Metabolism and nutrition', 'Turns food into energy and keeps blood sugar steady.',
      'A limited food system, stress and less activity can change how the body uses sugar and nutrients.',
      'Eat the full ration, favour protein and fibre, and take supplements as prescribed.', ['glu']),
  OrganDef('bones', 'Bones', 'Hold the body up and store calcium.',
      'Without gravity the skeleton is not loaded. Hips and spine can lose about 1% of density a month, and extra calcium in the blood raises kidney stone risk.',
      'Do resistive exercise daily, keep vitamin D and calcium in range and drink plenty of water.', ['ex']),
  OrganDef('muscle', 'Muscles', 'Move us and hold posture.',
      'Unloaded muscles shrink, especially legs and back, and strength falls fast without resistive work.',
      'Train legs, back and core with the resistive device and eat enough protein.', ['ex', 'mass']),
  OrganDef('immune', 'Immune system', 'Fights infection and clears damaged cells.',
      'Stress, radiation and a closed environment change immune function. Dormant viruses can reactivate.',
      'Wash hands, wipe surfaces, sleep enough and report symptoms early.', ['temp']),
];

const List<String> kOrganOrder = [
  'brain', 'heart', 'lungs', 'metab', 'bones', 'muscle', 'immune'
];

OrganDef organDef(String id) => kOrgans.firstWhere((o) => o.id == id);

/// INFO knowledge base: why / how / space / escalation + actions per level
class MetricInfo {
  final String why;
  final List<String> how;
  final String space;
  final String esc;
  final Map<int, List<String>> act;
  const MetricInfo(this.why, this.how, this.space, this.esc, this.act);
}

const Map<String, MetricInfo> kInfo = {
  'hr': MetricInfo(
    'Resting heart rate is one of the quickest signs of deconditioning, dehydration, stress, fever or poor sleep. In weightlessness the heart works less, so fitness can slip without us noticing.',
    ['Sit upright and rest for 5 minutes.', 'Use the wrist strap or ECG patch, or count your pulse at the wrist for 30 seconds and double it.', 'Measure at the same time each morning, before caffeine.'],
    'Fluid shifts toward the head and the heart adapts to a lighter load. Radiation may add to long-term heart risk.',
    'Resting rate above 100 or below 45 that lasts, an irregular rhythm, chest pain, fainting or breathlessness.',
    {1: ['Drink 500 mL of water and rest for 15 minutes, then measure again.', 'Look back at caffeine, sleep and stress over the last 24 hours.', 'Do a light aerobic session if you feel well.'],
     2: ['Pause strenuous work and sit or lie down.', 'Repeat the measurement and note any symptoms.', 'Talk to the flight surgeon, especially with chest pain, dizziness or an irregular pulse.']},
  ),
  'bp': MetricInfo(
    'Blood pressure shows how well circulation copes with fluid shifts, salt and stress. Low readings matter for dizziness and for standing up again in gravity.',
    ['Sit with your back supported, feet flat or strapped, arm at heart height.', 'Rest 5 minutes, then take two readings one minute apart with the automatic cuff.', 'Record the average.'],
    'Blood and fluid move toward the head in weightlessness. Pressure often runs lower in flight, and standing in gravity can cause fainting.',
    'Top number 140 or higher or below 85, bottom number 90 or higher, or any reading with headache, vision change or chest pain.',
    {1: ['Go easy on salty food today and drink water.', 'Take slow breaths for 5 minutes and measure again.', 'Think about pain, stress or lost sleep as possible causes.'],
     2: ['Sit quietly for 5 minutes and re-measure.', 'Hold off on hard exercise until you have spoken to the flight surgeon.', 'Hydrate with 500 mL of water and rest 15 minutes.']},
  ),
  'spo2': MetricInfo(
    'Oxygen saturation shows whether cabin air and our lungs deliver enough oxygen. A drop can come from high CO₂, poor airflow, dust or illness.',
    ['Warm your hand and keep it still.', 'Clip the oximeter on a fingertip without nail polish.', 'Wait about 30 seconds for the number to settle.'],
    'CO₂ can pool where air does not circulate. On the Moon and Mars, fine dust irritates the airways.',
    'Below 92%, or below 95% together with headache, breathlessness or confusion.',
    {1: ['Move to a well-ventilated module and breathe slowly for 2 minutes.', 'Check the CO₂ monitor and the air filters.', 'Measure again in 15 minutes.'],
     2: ['Sit upright, breathe slowly and check the CO₂ and oxygen readouts.', 'Talk to the flight surgeon.', 'Be ready to start the supplemental oxygen procedure.']},
  ),
  'glu': MetricInfo(
    'Blood sugar shifts with stress, food, sleep loss and less activity. Catching a rise early lets us adjust food and exercise first.',
    ['Measure before the first meal, after at least 8 hours without food.', 'Wash and dry your hands, prick the side of a fingertip and touch the strip to the drop.', 'Log the number in mg/dL.'],
    'Stress hormones, disrupted sleep and the limited food system can nudge glucose up, and less muscle work means less sugar used.',
    'Fasting 126 mg/dL or higher on two days, below 60, or any reading with extreme thirst, confusion or sweating.',
    {1: ['Choose protein and fibre at the next meal and skip sweet drinks.', 'Add a 20-minute walk on the treadmill.', 'Measure again tomorrow morning.'],
     2: ['Recheck now with a fresh strip.', 'Follow the medical kit protocol for the result.', 'Talk to the flight surgeon today.']},
  ),
  'temp': MetricInfo(
    'Temperature points to infection and heat stress. A small rise can be the first sign that a dormant virus is waking under stress.',
    ['Use the forehead or ear thermometer, 15 minutes after exercise or a hot drink.', 'Measure at the same time each day.', 'Repeat once if the number is unexpected.'],
    'Warm air does not rise in weightlessness, so heat builds around us. Immune function changes in flight and latent viruses can reactivate.',
    '38.0 °C or higher, shivering, or a rise lasting more than 24 hours.',
    {1: ['Drink water and rest. Measure again in 2 hours.', 'Wash hands and wipe shared surfaces.', 'Keep exercise light today.'],
     2: ['Keep apart from crewmates where possible and wear a mask.', 'Talk to the flight surgeon about symptoms.', 'Log any cough, sore throat or rash.']},
  ),
  'sleep': MetricInfo(
    'Sleep protects mood, attention and the immune system. Crews often sleep close to 6 hours, which builds into real debt over weeks.',
    ['Wear the activity watch overnight, or enter bedtime and wake time by hand.', 'Note how rested you feel on waking.', 'Aim for 7 to 8 hours in a fixed window.'],
    'There is no natural day and night, the cabin is noisy and the schedule is full. Light timing is our strongest lever.',
    'Under 5 hours for three nights in a row, or sleeping well but feeling unwell, confused or very low.',
    {1: ['Keep a fixed sleep window, even on days off.', 'Dim cabin lights and screens for 1 hour before bed.', 'Keep hard exercise away from bedtime.'],
     2: ['Ask for a lighter workload for 24 hours.', 'Use ear plugs, an eye mask and a morning light.', 'Tell the flight surgeon about the pattern.']},
  ),
  'mood': MetricInfo(
    'Mood shows how isolation, workload and distance from home are affecting us. A dip often shows up before sleep and performance slip.',
    ['Rate your mood from 1 to 5 each evening.', 'Add a word for what drove it.', 'Compare against the last week, not only today.'],
    'Confinement, repetitive days and message delays are the main drivers.',
    'Mood of 1 or 2 for several days, loss of interest, strong irritability with the crew, or any thoughts of harming yourself.',
    {1: ['Plan a call with family or friends.', 'Take a short break with something you enjoy.', 'Talk to a crewmate about how the day went.'],
     2: ['Set up a private conference with the flight surgeon or behavioural health team.', 'Lighten tomorrow’s load if the schedule allows.', 'We do not have to carry this alone.']},
  ),
  'ex': MetricInfo(
    'Without gravity, bones and muscles are not loaded, so they shrink. Daily resistive and aerobic exercise is the main protection.',
    ['Log minutes of resistive work, treadmill and cycle.', 'Count only active time.', 'Aim for about 90 minutes a day, in sessions that match your plan.'],
    'Weight-bearing bones can lose around 1% of density a month in weightlessness. On the Moon or Mars the load is lower than on Earth.',
    'Pain while lifting, back pain that lasts, or a missed programme for more than 3 days in a row.',
    {1: ['Add one resistive session today, focused on legs and back.', 'Schedule tomorrow’s plan before you finish the day.', 'Eat protein within an hour of training.'],
     2: ['Do at least 30 minutes of loaded exercise as soon as it is safe.', 'Tell the exercise specialist about the missed sessions.', 'Check calcium and vitamin D intake with the flight surgeon.']},
  ),
  'rad': MetricInfo(
    'Radiation dose adds up over the mission and raises long-term cancer and heart risk. A solar particle event can deliver a large dose in hours.',
    ['Read the personal dosimeter at the scheduled time.', 'Compare it with the ground-reported dose.', 'Log the number in mSv.'],
    'Cosmic rays and solar particles are the main source. The hull gives some shielding, and the Moon or Mars add little.',
    'A solar particle event alert, a daily dose far above typical, or a mission total above 80% of the limit.',
    {1: ['Spend extra time in the best-shielded area, such as the sleep quarters.', 'Review the radiation forecast with the ground team.', 'Keep a log of unusual readings.'],
     2: ['Move to the storm shelter and follow the radiation protocol.', 'Stay until mission control clears you.', 'Report nausea, vomiting or skin redness straight away.']},
  ),
  'co2': MetricInfo(
    'CO₂ builds up where air does not move. High levels cause headaches, drowsiness and slower thinking before we notice the air is stale.',
    ['Read the cabin CO₂ monitor in the module where you spend most time.', 'Check a second module if you feel unwell.'],
    'With no natural convection, our own breath can form a pocket around the head, especially during sleep.',
    'Above 7,000 ppm, or any headache, breathlessness or confusion that eases when you change module.',
    {1: ['Move to an area with strong airflow and check the vents are clear.', 'Re-check in 15 minutes.', 'Note any headache or drowsiness.'],
     2: ['Move to a well-ventilated module and check the scrubber status.', 'Tell the crew and the ground team.', 'Follow the CO₂ scrubber procedure.']},
  ),
  'hum': MetricInfo(
    'Humidity affects comfort, skin, mould growth and sleep.',
    ['Read the Multi-Gas Monitor humidity value.', 'Compare modules if one feels damp or dry.'],
    'Condensation collects on cold surfaces in a sealed cabin, so damp spots can grow mould.',
    'Below 25% or above 70%, or visible condensation or mould.',
    {1: ['Check the cabin dehumidifier settings.', 'Wipe damp surfaces and report mould early.'],
     2: ['Report it to the ground team.', 'Avoid sleeping in the damp area until it has been checked.']},
  ),
  'ctemp': MetricInfo(
    'Cabin temperature affects sleep, performance and how much we sweat.',
    ['Read the cabin air-control display.', 'Adjust your local vent first.'],
    'Heat from equipment and our bodies stays near us because warm air does not rise.',
    'Below 18 °C or above 27 °C for more than a few hours.',
    {1: ['Adjust the local vent and use layers.', 'Re-check in 30 minutes.'],
     2: ['Ask the ground team for a cabin setpoint change.', 'Rest in a cooler module if you feel unwell.']},
  ),
  'noise': MetricInfo(
    'Constant fans and pumps make noise that harms sleep and hearing over months.',
    ['Read the sound level meter in the module.', 'Measure at ear height near where you sleep.'],
    'Fans cannot be switched off and sound bounces off hard walls.',
    'Above 72 dBA for long periods, or ringing in the ears.',
    {1: ['Use ear plugs while you sleep.', 'Move quiet tasks to a quieter module.'],
     2: ['Wear hearing protection near loud equipment.', 'Tell the ground team and report ear symptoms.']},
  ),
  'resp': MetricInfo(
    'Breathing rate rises early with CO₂, fever or stress, often before we feel it.',
    ['Wear the Bio-Monitor shirt for the reading.', 'Or count breaths for 30 seconds at rest and double it.'],
    'Air quality and exercise load both change breathing.',
    'Above 28 breaths per minute at rest, or below 8.',
    {1: ['Rest and slow your breathing for 2 minutes.', 'Check cabin CO₂.'],
     2: ['Sit upright and check CO₂ and oxygen.', 'Talk to the flight surgeon.']},
  ),
  'mass': MetricInfo(
    'Body mass shows whether we eat and drink enough and whether muscle is holding up.',
    ['Use the SLAMMD device as instructed.', 'Measure at the same time of day.'],
    'There is no scale in weightlessness, so mass is calculated from acceleration.',
    'A drop or rise of more than 5% from baseline.',
    {1: ['Check that you are eating the full ration.', 'Add protein with training.'],
     2: ['Review food and exercise with the flight surgeon.', 'Re-measure in 2 days.']},
  ),
};

/// TIPS - suggested step when everything is normal
const Map<String, String> kTips = {
  'hr': 'Measure at the same time each morning, before caffeine.',
  'bp': 'Drink water through the day and stand up slowly.',
  'spo2': 'Keep cabin air moving and take a few deep breaths each hour.',
  'glu': 'Eat regular meals and avoid long gaps.',
  'temp': 'Drink water and note how you feel if it changes.',
  'sleep': 'Keep a fixed bedtime, even on rest days.',
  'mood': 'Talk to your crew or family today.',
  'ex': 'Finish today’s exercise session.',
  'rad': 'Stay in the shielded area during solar alerts.',
  'co2': 'Keep vents clear and move away from stale air pockets.',
  'hum': 'Keep vents and filters clear.',
  'ctemp': 'Dress for the cabin and adjust the vents if you feel too hot or cold.',
  'noise': 'Use ear protection near loud equipment.',
  'resp': 'Breathe slowly for one minute if you feel tense.',
  'mass': 'Keep up your resistive exercise to protect muscle.',
};

/// daily tasks (TASKS from the design)
class TaskDef {
  final String id, title, hint;
  const TaskDef(this.id, this.title, this.hint);
}

const List<TaskDef> kTasks = [
  TaskDef('sleep', 'Log last night’s sleep', 'Bedtime, wake time, wake-ups and how rested you feel'),
  TaskDef('mood', 'Mood, stress and workload', 'A minute to check in with yourself'),
  TaskDef('fuel', 'Water and meals', 'What you have eaten and drunk so far'),
  TaskDef('symptoms', 'Symptom check', 'Anything that feels off today'),
];

const Map<String, List<String>> kTaskMap = {
  'sleep': ['sleep_quality'],
  'mood': ['mood_daily', 'stress_fatigue_workload'],
  'fuel': ['food_intake', 'hydration'],
  'symptoms': ['symptom_checklist', 'symptom_severity'],
};

/// weekly questionnaire questions
const List<String> kWeeklyQuestions = [
  'I felt rested when I woke up',
  'I felt close to my crewmates',
  'I could focus on my tasks',
  'I looked forward to the days ahead',
  'I felt in control of my workload',
];

/// pages (PAGES from the design): page -> sections -> field ids
class PageSection {
  final String id, t, s;
  final List<String> f;
  final String? cls;
  final bool nothing;
  const PageSection(this.id, this.t, this.s, this.f, {this.cls, this.nothing = false});
}

class PageDef {
  final String id, n, sub;
  final List<PageSection> secs;
  const PageDef(this.id, this.n, this.sub, this.secs);
}

const List<PageDef> kPages = [
  PageDef('checkin', 'Check-in', 'Four short daily items: sleep, mood, water and meals, and symptoms. About two minutes. Nothing here is a test.', [
    PageSection('sleep', 'Sleep', 'Last night', ['sleep_hours_wakeups', 'sleep_quality', 'sleep_vs_mission_clock']),
    PageSection('mood', 'Mood and strain', 'A minute to check in with yourself', ['mood_daily', 'stress_fatigue_workload', 'loneliness_crew_interaction']),
    PageSection('fuel', 'Food and water', 'What you have eaten and drunk so far', ['food_intake', 'hydration']),
    PageSection('symptoms', 'Symptoms', 'Anything that does not feel normal',
        ['symptom_checklist', 'symptom_severity', 'symptom_duration', 'pain_by_region', 'dizziness_vision_congestion', 'symptoms_headache_rash'], nothing: true),
  ]),
  PageDef('vit', 'Vitals', 'From your devices. You can correct any number by hand.', [
    PageSection('v', '', '', ['spo2', 'heart_rate', 'blood_pressure', 'body_temperature', 'respiratory_rate', 'blood_glucose', 'body_mass', 'exercise'], cls: 'dv'),
  ]),
  PageDef('cabin', 'Cabin and mission', 'The air you breathe, the dose you carry and where you are in the mission.', [
    PageSection('air', 'Cabin air', 'From the cabin sensors', ['co2_ppm', 'cabin_humidity', 'cabin_temperature', 'cabin_noise'], cls: 'dv'),
    PageSection('rad', 'Radiation', 'Personal dosimeter', ['radiation_dose_msv'], cls: 'dv'),
    PageSection('mis', 'Mission', 'Day, phase and message delay', ['mission_day_phase', 'communication_delay'], cls: 'dv'),
  ]),
  PageDef('med', 'Medical', 'Medicines, supplies, photos and the flight surgeon.', [
    PageSection('meds', 'Medicines', 'What you take and what is left', ['medications_taken', 'medications', 'supplements', 'medical_inventory']),
    PageSection('fs', 'Flight surgeon', 'Items that need their eyes', ['flight_surgeon_review_flag']),
    PageSection('img', 'Photos and scans', 'Kept on this device until you send them', ['skin_eye_images', 'ultrasound_images']),
  ]),
  PageDef('mind', 'Mind and focus', 'A weekly check-in, a quick fatigue check and your private journal.', [
    PageSection('wk', 'Weekly check-in', 'Once a week', ['weekly_questionnaire']),
    PageSection('rt', 'Reaction time', 'About 30 seconds', ['reaction_time_test']),
    PageSection('jr', 'Journal', 'Private', ['journal']),
  ]),
];

final Map<String, String> kFieldPage = {
  for (final p in kPages)
    for (final s in p.secs)
      for (final id in s.f) id: p.id,
};

List<FieldDef> pageFields(String p) {
  for (final def in kPages) {
    if (def.id == p) {
      return [
        for (final s in def.secs)
          for (final id in s.f)
            if (kFieldById[id] != null) kFieldById[id]!
      ];
    }
  }
  return const [];
}
