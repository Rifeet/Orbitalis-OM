# AstroVitals - Health Monitoring Software for Astronauts

**2026 NASA Space Apps Challenge** · *Create Health Monitoring Software for Astronauts on Space Missions*

AstroVitals is an astronaut-first health console: it turns the five spaceflight
hazards (space radiation, isolation and confinement, distance from Earth, gravity
fields, hostile closed environments) into daily check-ins, colour-coded readings,
a rule-based alert engine and a verified first-aid guide for microgravity.

This is the **Flutter/Dart implementation** of the team's approved HTML prototype
(`AstroVitals_fixed_8.html`), built to match the reference design screen by screen,
with the agreed **front-end / back-end data contract** applied end to end.

---

## What is implemented (1:1 with the reference design)

| Area | Details |
| --- | --- |
| **Today** | Holographic body map (CustomPaint) with 7 tap-able organ hotspots, status hero with health index (0-100, capped by the worst alert), compact alert cards with Acknowledge / Start / Override / Talk to flight surgeon, daily check-in task list, "your other pages" tiles |
| **Check-in** | Sleep (device card + validated manual entry + sleep clock), mood faces, stress / fatigue / workload sliders, crew connection, food + water tracking, symptom checklist, severity slider, duration, pain figure (front/back tap-to-cycle), dizziness chips, headache/rash chips with photo |
| **Vitals** | SpO₂, heart rate, blood pressure, temperature, breathing rate, glucose, body mass, exercise - each with sparkline, zone range bar, device/manual source badge and a **validated manual entry form** |
| **Cabin and mission** | Cabin CO₂ / humidity / temperature / noise, radiation (daily dose + mission total vs limit meter), mission day and phase, message delay |
| **Medical** | Scheduled meds (taken / skipped), medication log with dose validation, supplements chips, medical inventory with low-stock badges, flight-surgeon review flag, skin/eye + ultrasound photo trays |
| **Mind and focus** | Weekly 5-question check-in, reaction time test (5 trials, median), private journal |
| **Progress** | Journey rail (day X of Y), health-log streak, 7 mission badges, hazard explainers, 14-day health-index chart with the six alert bands |
| **Emergency guide** | Same structure as the reference design: scenario pills + step rows (number badge → illustration → title + description). The 4 verified procedures from `emergency.docx` (**Fainting, Chest pain, Not breathing (CPR), Choking**) use the 20 illustrations extracted from the document; the design's Severe bleeding / Hard to breathe / Solar storm procedures render as line art. Source tags, the spaceflight-adaptations panel and the references table are kept in `emergency_data.dart` but are **not rendered**, exactly like the prototype |
| **Alert engine** | Port of `evaluate()`: six levels (Normal → Emergency), tiers 0-4, pattern detection (hr + sleep + mood), field rules, contact text aware of the one-way delay |
| **Overlays** | Tier-3 modal (once per alert), tier-4 full-screen urgent checklist (confirm step 1 + 2 to close, re-measure escape hatch), toasts with undo, detail drawer for every organ/indicator |
| **Modes** | Night mode (dimmed, warm palette, lower-priority items held) and EVA mode (larger targets, do-not-disturb, held items) |
| **Demo controls** | 4 locations (ISS / Lunar base / Transit vehicle / Mars base), 3 display modes, 4 scenarios (Nominal day, Strained week, Solar storm, Cabin air event) |
| **Sign in / Sign up** | Entry gate in the same design language: live per-field validation (email format, password 8+ with letters + digits, confirm match), disabled submit until valid, demo crew quick-fill, Sign out in the profile dialog. Auth endpoints + a `DemoAuthGateway` sit on the same contract seam (`Api.authSignup / authLogin / authLogout`) so a real backend is a drop-in |

## Validation (every user-entered value)

* **Numeric readings** - LIM range check with per-metric messages ("Systolic pressure must be a number between 60 and 260."), immediate error under the field and a disabled Save button.
* **Blood pressure cross-check** - "Diastolic must be lower than systolic."
* **Sleep** - both times required, wake-ups 0-20, resulting duration 0.5-16 h ("That gives 25.0 hours. Check the times.").
* **Mission day** - 1..mission length.
* **Medication dose** - optional but validated against a number+unit pattern, ≤ 30 chars.
* **Inventory code** - required, ≤ 40 chars. **Journal** - required, ≤ 1000 chars.
* **Water** - clamped to 0-10000 mL. **Photos** - image only, ≤ 8 MB, max 6 per tray.
* **Weekly questionnaire** - all five answers required before saving.
* **Profile** - name required, name/role ≤ 40 chars.
* **Auth forms** - email format, password ≥ 8 chars with at least one letter and one digit, confirm-password match; errors appear under each field as you type and the submit button stays disabled until the form is valid.
* **Repository level** (contract) - LIM range check, freshness/quality tagging (ok / stale / suspect) and duplicate-id protection in the send queue.

## The data contract (front-end ↔ back-end)

`lib/core/contract/` implements the agreed contract fixes:

* one name per metric - `MetricDef` maps **UI id ↔ API metric ↔ snake_case field id**;
* radiation split into `dose_rate` (mSv/day) and `cumulative_dose` (mSv) with explicit units;
* UTC epoch-millisecond timestamps everywhere (`Reading.time`, `AlertItem.raisedAt`);
* one-way delay named `delayMin` (minutes);
* every reading carries `unit`, client `id` + `seq`, and `quality` (ok / stale / suspect);
* alert lifecycle: raised → shown → acknowledged / started / overridden / cleared;
* `Api` holds every endpoint (`POST /v1/readings`, `GET /v1/status`, `POST /v1/alerts/{id}/ack|start|override`, `POST /v1/entries`, `GET /v1/context`, `POST /v1/emergency`, `POST /v1/reports/ground`, `GET /v1/sync/queue`, `WS /v1/stream`);
* `AstroRepository` is the single seam: the demo build enqueues payloads in `SyncQueue`
  (duplicate-safe, with client id + seq). To go live, implement `AstroRepository`
  against the real API - **no UI or engine changes needed**.

## Project layout

```
lib/
  main.dart                     app entry + state scope
  app_theme.dart                design tokens (palette, fonts, modes) + store scope
  core/
    contract/                   data contract: models, metrics, zones, limits, fields, api endpoints
    data/                       demo data generator, app state (ChangeNotifier), repository + sync queue
    engine/                     level engine + alert engine (evaluate) + observation texts
    validation/                 validators for every input
  ui/
    pages/                      Today, data pages, Progress, Emergency, drawer, overlays, shell
    widgets/                    body map, charts, sparklines, status icons, field cards, painters
  emergency/                    emergency_data.dart (generated from emergency.docx) + line-art scenes
assets/
  fonts/                        Chakra Petch + IBM Plex Sans (bundled, offline-safe)
  aid/                          the 20 illustrations from emergency.docx
  img/                          demo placeholders for the photo trays
```

## Run it

Requires Flutter 3.35+ (`flutter doctor` should be clean).

```bash
flutter pub get
flutter run                # pick a device: Chrome (fastest demo), Android, iOS
```

Run the tests:

```bash
flutter test
```

Build for the web (a ready-made release build is included in `build/web/`):

```bash
flutter build web --release
```

The fastest way to demo to judges is `flutter run -d chrome`.

## Emergency guide sources

The four procedures and their 20 illustrations come from the team's verified
`emergency.docx` (checked against ERC 2025, British/American Red Cross, AHA/American
Red Cross 2024, DGLRM/ESAM microgravity CPR guideline, NASA medical operations and
the WMS space-medicine article). The steps are English (per the team's language
decision); the Arabic text from the document is preserved in `emergency_data.dart`
for a future bilingual toggle. Per the prototype, only the steps + illustrations
are rendered on the page; the source list, spaceflight adaptations and references
stay in the data file for judges who ask for provenance.

---

AstroVitals supports self-checks and does not replace your flight surgeon.
Demo data is generated locally with a fixed seed for repeatable runs.
