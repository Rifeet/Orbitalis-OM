// AUTO-GENERATED from emergency.docx (extracted scripts/extract_steps_full.py).
// 4 procedures - 20 steps - 20 illustrations. Sources refer to the References table below.
// English UI (team decision); Arabic strings are kept here for a future bilingual toggle.
library;

class AidStep {
  final int n;
  final String enTitle;
  final String arTitle;
  final String en;
  final String ar;
  final String image; // asset path
  final List<String> sources;
  final bool spaceAdapted;
  const AidStep({required this.n, required this.enTitle, required this.arTitle, required this.en, required this.ar, required this.image, required this.sources, required this.spaceAdapted});
}

class AidProcedure {
  final String id;
  final String name;
  final String nameAr;
  final String trigger;
  final String triggerAr;
  final List<AidStep> steps;
  final String? imageAsset; // set for the three design procedures rendered as line art
  const AidProcedure({required this.id, required this.name, required this.nameAr, required this.trigger, required this.triggerAr, required this.steps, this.imageAsset});
}

const String kEmergencyDocDate = '13 November 2026';

const List<Map<String, String>> kAidReferences = [
  {'id': 'S1', 'org': 'British Red Cross', 'title': 'Learn first aid: unresponsive and breathing / fainting', 'url': 'https://www.redcross.org.uk/first-aid/learn-first-aid/unresponsive-and-breathing'},
  {'id': 'S2', 'org': 'British Red Cross', 'title': 'Learn first aid: heart attack', 'url': 'https://www.redcross.org.uk/first-aid/learn-first-aid/heart-attack'},
  {'id': 'S3', 'org': 'American Red Cross', 'title': 'Adult & child choking: symptoms and first aid', 'url': 'https://www.redcross.org/take-a-class/resources/learn-first-aid/adult-child-choking'},
  {'id': 'S5', 'org': 'European Resuscitation Council (ERC)', 'title': 'ERC Guidelines 2025 on Resuscitation for Everyone (layperson edition)', 'url': 'https://www.erc.edu/media/p5ymaeej/gl2025_layperson_book_ipdf-v11-e.pdf'},
  {'id': 'S6', 'org': 'American Heart Association & American Red Cross', 'title': '2024 AHA and American Red Cross Guidelines for First Aid (chest pain / aspirin)', 'url': 'https://professional.heart.org/en/science-news/2024-aha-and-american-red-cross-guidelines-for-first-aid'},
  {'id': 'S7', 'org': 'German Society of Aerospace Medicine (DGLRM) & ESAM-SMG', 'title': 'Cardiopulmonary resuscitation (CPR) during spaceflight - a guideline for CPR in microgravity', 'url': 'https://pmc.ncbi.nlm.nih.gov/articles/PMC7607644'},
  {'id': 'S9', 'org': 'NASA', 'title': 'Reference: Medical Operations and Clinical Care', 'url': 'https://www.nasa.gov/reference/medical-operations-and-clinical-care'},
  {'id': 'S13', 'org': 'Wilderness Medical Society (WMS)', 'title': 'Treating Cardiac Arrest in Space: The Challenges of Resuscitation in Microgravity', 'url': 'https://wms.org/magazine/magazine/1229/space-medicine/Default.aspx'},
];

const List<String> kSpaceAdaptations = [
  'Patient restraint in microgravity: an unresponsive or fainting crew member is secured with restraints so they do not drift into equipment.',
  'Flight surgeon in the loop: every emergency includes alerting the crew medical officer and the flight surgeon; medicines, including aspirin for chest pain, are given only with flight-surgeon approval.',
  'Microgravity CPR technique: compressions in weightlessness use the DGLRM/ESAM guideline - restrain the patient on the Crew Medical Restraint System and use the Evetts-Russomano technique or the handstand method with feet anchored.',
  'Braced abdominal thrusts: the rescuer braces against a solid surface before abdominal thrusts, because the reaction force pushes both people apart in microgravity.',
  'Airway care without gravity: in microgravity the head is held tilted with the airway kept open manually - the recovery position alone cannot protect the airway when fluids do not drain.',
];

const AidProcedure kAidFaint = AidProcedure(
  id: 'faint',
  name: 'Fainting',
  nameAr: 'الإغماء',
  trigger: 'Someone collapses or feels about to',
  triggerAr: 'عندما ينهار رائد الفضاء أو يشعر أنه على وشك الإغماء',
  steps: [
    AidStep(n: 1, enTitle: 'Keep them from falling.', arTitle: 'امنعه من السقوط', en: 'Lower them gently to a firm surface and protect the head. In microgravity, restrain them so they do not drift.', ar: 'أنزِله بلطف على سطح ثابت واحمِ رأسه. في انعدام الجاذبية ثبّته بحمالات حتى لا يطفو في الوحدة.', image: 'assets/aid/aid_01.png', sources: ['S1'], spaceAdapted: true),
    AidStep(n: 2, enTitle: 'Check they respond and breathe.', arTitle: 'افحص الاستجابة والتنفس', en: 'Tap the shoulders and speak loudly. Look, listen and feel for breathing for up to 10 seconds.', ar: 'اطرب على الكتفين ونادِ بصوت مرتفع. راقب التنفس بالنظر والاستماع والإحساس لمدة تصل إلى 10 ثوانٍ.', image: 'assets/aid/aid_02.png', sources: ['S1', 'S5'], spaceAdapted: false),
    AidStep(n: 3, enTitle: 'If breathing, help blood reach the brain.', arTitle: 'ساعد الدم على الوصول للدماغ', en: 'If they are breathing, loosen tight clothing and raise the legs about 30 cm (above heart level) while lying on the back. In microgravity, keep them restrained and calm.', ar: 'إذا كان يتنفس، فك الملابس الضيقة وارفع الساقين نحو 30 سم (أعلى من مستوى القلب) وهو مستلقٍ على الظهر. في انعدام الجاذبية أبقه مثبتاً ومرتاحاً.', image: 'assets/aid/aid_03.png', sources: ['S1', 'S4'], spaceAdapted: true),
    AidStep(n: 4, enTitle: 'Call for help.', arTitle: 'اطلب المساعدة', en: 'Alert the crew medical officer and the flight surgeon. Say what happened, how long the faint lasted and how they feel now.', ar: 'أبلغ ضابط الطاقم الطبي والطبيب الجراح الفضائي. قل ماذا حدث، وكم استمر الإغماء، وكيف يشعر الآن.', image: 'assets/aid/aid_04.png', sources: ['S9'], spaceAdapted: true),
    AidStep(n: 5, enTitle: 'Keep watching.', arTitle: 'راقب باستمرار', en: 'If they stay unresponsive but are breathing, place them in the recovery position on their side and re-check breathing every minute. If breathing stops, start CPR. In microgravity fluids do not drain and the recovery position alone cannot protect the airway - keep them restrained, hold the head tilted so the airway stays open, and keep watching continuously.', ar: 'إذا بقي غير مستجيب لكنه يتنفس، ضعه في وضعية الإنقاذ على جانبه وأعد فحص التنفس كل دقيقة. إذا توقف التنفس ابدأ الإنعاش القلبي الرئوي. في انعدام الجاذبية لا تجري السوائل، ووضعية الإنقاذ وحدها لا تحمي مجرى الهواء - ثبّت المصاب بنظام التقييد، وأمسك الرأس بزاوية تُبقي مجرى الهواء مفتوحاً، واستمر في المراقبة دون انقطاع.', image: 'assets/aid/aid_05.png', sources: ['S1', 'S5', 'S7', 'S13'], spaceAdapted: true),
  ],
);

const AidProcedure kAidChest = AidProcedure(
  id: 'chest',
  name: 'Chest pain',
  nameAr: 'ألم الصدر',
  trigger: 'Pressure, tightness or pain spreading to arm or jaw',
  triggerAr: 'ضغط أو شدّ أو ألم يمتد إلى الذراع أو الفك',
  steps: [
    AidStep(n: 1, enTitle: 'Stop and sit.', arTitle: 'توقف واجلس', en: 'Stop all activity at once. Sit or half-recline in the position that makes breathing easiest - leaning against a wall or seat.', ar: 'توقف عن كل نشاط فوراً. اجلس أو استرخِ نصف استلقاء بالوضعية الأسهل للتنفس - متكيّاً على حائط أو مقعد.', image: 'assets/aid/aid_06.png', sources: ['S2'], spaceAdapted: false),
    AidStep(n: 2, enTitle: 'Call now.', arTitle: 'اتصل فوراً', en: 'Alert the crew and the flight surgeon immediately. Do not wait to see if the pain passes.', ar: 'أبلغ الطاقم والطبيب الجراح الفضائي فوراً. لا تنتظر لترى هل يزول الألم.', image: 'assets/aid/aid_07.png', sources: ['S2', 'S6'], spaceAdapted: true),
    AidStep(n: 3, enTitle: 'Stay calm and loosen clothing.', arTitle: 'اهدأ وفك الملابس الضيقة', en: 'Loosen tight clothing and stay calm with slow, steady breaths. Aspirin can limit heart damage, but aboard the spacecraft give any medicine only if the flight surgeon approves it and the person has no allergy.', ar: 'فك الملابس الضيقة وابقَ هادئاً مع تنفس بطيء منتظم. الأسبرين يحدّ من ضرر القلب، لكن على متن المركبة لا تعطِ أي دواء إلا بإذن الطبيب الجراح الفضائي وبشرط عدم وجود حساسية.', image: 'assets/aid/aid_08.png', sources: ['S6', 'S9'], spaceAdapted: true),
    AidStep(n: 4, enTitle: 'Track the numbers.', arTitle: 'تتبع القراءات', en: 'Measure heart rate, blood pressure and SpO2 every few minutes and read the values to the flight surgeon.', ar: 'قِس نبض القلب وضغط الدم وتشبع الأكسجين SpO2 كل بضع دقائق واقرأ القيم للطبيب الجراح الفضائي.', image: 'assets/aid/aid_09.png', sources: ['S9'], spaceAdapted: true),
    AidStep(n: 5, enTitle: 'If they collapse.', arTitle: 'إذا انهار', en: 'Check breathing. If there is none, start CPR and send someone for the defibrillator (AED).', ar: 'افحص التنفس. إذا لم يكن هناك تنفس ابدأ الإنعاش القلبي الرئوي وأرسل شخصاً لإحضار جهاز الصدمات الكهربائية AED.', image: 'assets/aid/aid_10.png', sources: ['S5'], spaceAdapted: false),
  ],
);

const AidProcedure kAidCpr = AidProcedure(
  id: 'cpr',
  name: 'Not breathing (CPR)',
  nameAr: 'لا يتنفس (إنعاش قلبي رئوي)',
  trigger: 'Unresponsive with no normal breathing',
  triggerAr: 'غير مستجيب ولا يتنفس بشكل طبيعي',
  steps: [
    AidStep(n: 1, enTitle: 'Check response and breathing.', arTitle: 'افحص الاستجابة والتنفس', en: 'Tap the shoulders and shout. If there is no response and no normal breathing - or only gasping - act at once.', ar: 'اطرب على الكتفين ونادِ بصوت عالٍ. إن لم يستجب ولا يتنفس بشكل طبيعي - أو يلهث فقط - تصرف فوراً.', image: 'assets/aid/aid_11.png', sources: ['S5'], spaceAdapted: false),
    AidStep(n: 2, enTitle: 'Get help and the defibrillator.', arTitle: 'اطلب المساعدة وجهاز الصدمات', en: 'Call out for the crew. Send someone for the defibrillator and the medical kit, and inform the flight surgeon.', ar: 'نادِ الطاقم بصوت عالٍ. أرسل شخصاً لإحضار جهاز الصدمات وحقيبة الإسعاف، وأبلغ الطبيب الجراح الفضائي.', image: 'assets/aid/aid_12.png', sources: ['S5', 'S9'], spaceAdapted: true),
    AidStep(n: 3, enTitle: 'Start chest compressions.', arTitle: 'ابدأ ضغطات الصدر', en: 'Heel of one hand on the centre of the chest, other hand on top, arms straight, shoulders above the hands. Push hard and fast: 5-6 cm deep, 100-120 per minute, letting the chest rise between pushes. In microgravity, restrain the patient and anchor yourself - use the Evetts-Russomano method or the Crew Medical Restraint System (DGLRM/ESAM space CPR guideline).', ar: 'كعب يد واحدة في منتصف الصدر واليد الأخرى فوقها، الذراعان مستقيمتان والكتفان فوق اليدين. اضغط بقوة وبسرعة: عمق 5-6 سم بمعدل 100-120 ضغطة في الدقيقة مع السماح للصدر بالارتفاع بين الضغطات. في انعدام الجاذبية ثبّت المريض وثبّت نفسك - استخدم طريقة إيفيتس-روسومانو أو نظام التثبيت الطبي للطاقم CMRS وفق إرشادية الجمعيتين الألمانية والأوروبية لطب الفضاء.', image: 'assets/aid/aid_13.png', sources: ['S5', 'S7'], spaceAdapted: true),
    AidStep(n: 4, enTitle: 'Give breaths if trained.', arTitle: 'أعطِ الأنفاس إن كنت مدرّباً', en: 'After every 30 compressions, tilt the head, lift the chin and give 2 breaths (about 1 second each), then return straight to compressions.', ar: 'بعد كل 30 ضغطة، مِل الرأس للأخلف وارفع الذقن وأعطِ نفَسين (حوالي ثانية لكل نفَس)، ثم عد فوراً للضغطات.', image: 'assets/aid/aid_14.png', sources: ['S5'], spaceAdapted: false),
    AidStep(n: 5, enTitle: 'Use the defibrillator.', arTitle: 'استخدم جهاز الصدمات', en: 'Switch the AED on as soon as it arrives, attach the pads to the bare chest and follow the voice prompts. Do not stop CPR until the patient responds or trained help takes over.', ar: 'شغّل جهاز الصدمات فور وصوله، ألصق الرقعتين على الصدر المجرد واتبع التعليمات الصوتية. لا تتوقف عن الإنعاش حتى يستجيب المريض أو يتولى المهمة فريق مدرّب.', image: 'assets/aid/aid_15.png', sources: ['S5'], spaceAdapted: false),
  ],
);

const AidProcedure kAidChoke = AidProcedure(
  id: 'choke',
  name: 'Choking',
  nameAr: 'الاختناق',
  trigger: 'Cannot speak, cough or breathe',
  triggerAr: 'لا يستطيع الكلام أو الكحة أو التنفس',
  steps: [
    AidStep(n: 1, enTitle: 'Ask "Are you choking?".', arTitle: 'اسأله: هل تختنق؟', en: 'If they can cough, speak or breathe, let them cough it out. If they cannot speak, cough or breathe, act now.', ar: 'إذا استطاع الكحة أو الكلام أو التنفس فدعه يكح لطرد الجسم. إذا لم يستطع الكلام أو الكحة أو التنفس، تصرف فوراً.', image: 'assets/aid/aid_16.png', sources: ['S3', 'S5'], spaceAdapted: false),
    AidStep(n: 2, enTitle: 'Give 5 back blows.', arTitle: 'أعطِ 5 ضربات على الظهر', en: 'Stand to the side and slightly behind, lean them forward, and strike between the shoulder blades with the heel of your hand - 5 times, checking between blows.', ar: 'قف جانباً وخلفه قليلاً، أمِله للأمام، واضرب بين لوحتي الكتف بكعب اليد 5 مرات مع الفحص بين الضربات.', image: 'assets/aid/aid_17.png', sources: ['S3', 'S5'], spaceAdapted: false),
    AidStep(n: 3, enTitle: 'Give 5 abdominal thrusts.', arTitle: 'أعطِ 5 ضغطات بطنية', en: 'Stand behind, make a fist just above the navel, cover it with your other hand and pull sharply inward and upward - 5 times. In microgravity, brace yourself against a solid surface.', ar: 'قف خلفه، اصنع قبضة فوق السرّة مباشرة وغطّها بيديك الأخرى واسحب بقوة إلى الداخل وإلى الأعلى 5 مرات. في انعدام الجاذبية اسند نفسك على سطح ثابت.', image: 'assets/aid/aid_18.png', sources: ['S3', 'S5'], spaceAdapted: true),
    AidStep(n: 4, enTitle: 'Alternate the cycles.', arTitle: 'بدّل بين الدورتين', en: 'Keep repeating cycles of 5 back blows and 5 abdominal thrusts until the object comes out or they can breathe again.', ar: 'استمر في تكرار دورات من 5 ضربات على الظهر و5 ضغطات بطنية حتى يخرج الجسم أو يعود التنفس.', image: 'assets/aid/aid_19.png', sources: ['S3'], spaceAdapted: false),
    AidStep(n: 5, enTitle: 'If they become unresponsive.', arTitle: 'إذا فقد الاستجابة', en: 'Lower them to a firm, flat surface, call for help and start CPR with compressions. Before each set of breaths, open the mouth and look for the object - remove it only if you can see it clearly. Never sweep blindly with a finger.', ar: 'أنزله على سطح ثابت ومستوٍ، نادِ المساعدة وابدأ الإنعاش بالضغطات أولاً. قبل كل مجموعة أنفاس افتح الفم وابحث عن الجسم - أخرجه فقط إن رأيته بوضوح. لا تُجرِ أبداً مسحاً عمياء بالإصبع.', image: 'assets/aid/aid_20.png', sources: ['S3', 'S5'], spaceAdapted: false),
  ],
);

const List<AidProcedure> kAidProcedures = [kAidFaint, kAidChest, kAidCpr, kAidChoke];
