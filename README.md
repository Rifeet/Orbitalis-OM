# Orbitalis-OM
Our solution to the Nasa Space App challenge 2026
# AstroVitals

> **Crew health when the nearest doctor is 20 minutes away.**
> Act first, then report with clear facts.

Repository: **Orbitalis-OM** · [NASA Space Apps Challenge 2026](https://www.spaceappschallenge.org/) · Challenge: *Create Health Monitoring Software for Astronauts on Space Missions*

**Team:** Orbitalis OM — Ariam Saleh Zuwayid Al Hasani, 
Shima Mubarak Al-breaking, Rifeet Akhter Mohammed Abdul Mannan
**Demo video:** https://drive.google.com/drive/folders/1qvBIJN_B5YkBdSW1fyWN0W-cC__P4uTt

![Today screen](docs/screenshots/today.png)

---

## The problem

On a mission to Mars, a message to the flight surgeon can take about 20 minutes to arrive, and the reply takes as long
to come back. If something feels wrong, the crew has to act first and ask later. Most health apps assume a doctor is one
tap away. AstroVitals starts from the other end: it is built around the delay, not just the data.

## What AstroVitals does

| What you see | What it does |
|---|---|
| **Six alert levels** | Every reading is placed in one of six levels: Normal, Monitor, Advisory, Action soon, Act now, Emergency. Each level has its own **colour and shape** (circle, hollow circle, triangle, diamond, octagon, hexagon), so it also works for colour-blind crew and in low light. Each level tells the crew exactly what to do. |
| **Emergency takeover** | If blood oxygen falls below 90 % the screen becomes a red checklist (start the oxygen procedure, notify the commander). Each step must be confirmed before the alert clears. A "reading looks wrong? re-measure" escape is available. |
| **Solar storm** | The radiation alert offers "In storm shelter" and a one-tap **Solar storm steps** guide. |
| **Body map** | Tap one of 7 body systems (brain, immune, lungs, heart, metabolism, bones, muscle) to see its readings, why it matters in space, and what to do. |
| **Advice that depends on distance** | Four environments (space station, lunar base, transit vehicle, Mars base), each with its own dose limits and message delay. Near Earth: "call the flight surgeon now". On the way to Mars: "start with your crew, then send one complete message". |
| **Night and EVA modes** | At night and during spacewalks, low-priority alerts (Monitor, Advisory) are held for a briefing. Action soon, Act now and Emergency always come through. |
| **First-aid guide** | Step-by-step procedures adapted for weightlessness (fainting, chest pain, CPR, choking), plus the solar storm procedure. Illustrated, English and Arabic, with sources cited in the app. |
| **Daily check-in** | Sleep, mood, symptoms, medication, reaction-time test and journal, with validated manual entry. |
| **Charts, streaks, badges** | Trend charts and a mission journey. Badges reward **logging**, not good numbers, so nobody is tempted to hide a bad reading to keep a streak. |
| **Early-warning model** *(backend prototype)* | Learns each astronaut's own normal and flags slow, combined drifts that the six levels miss. See below. |

On a serious alert the first button is the treatment, not "re-measure". Overriding an alert always asks why.

## How it works

```
 Flutter app (frontend/)                         FastAPI backend (backend/)
 -----------------------                         --------------------------
 body map, alerts, check-in,    <-- rules ---    rules loaded from the app's own zone tables
 emergency guide, charts        --- readings -->  POST /v1/readings, /v1/entries  -> SQLite
 alert engine (levels 0-5)                        early-warning model -> anomaly_results
```

- **Readings -> levels.** Each reading is compared with zone tables for its metric and placed in a level. Radiation is judged against
  the **environment** (expected dose rate and mission limit).
- **One source of truth for thresholds.** The Flutter files are the source of truth. `backend/tools/extract_rules.py` reads them and
  the backend copies the numbers into its database, so the two can never silently disagree.
- **Prototype values.** The thresholds are prototype values chosen by the team. They must be reviewed by a flight surgeon before any real use.

### Early-warning model (prototype)

- **Idea:** a reading can look fine on its own while the *combination* of small changes is unusual for that person.
- **Method:** personal baseline from each astronaut's first 20 days -> one 15-metric z-score vector per day -> Mahalanobis distance ->
  alert only if flagged on 2 of the last 3 days -> short explanation ("sleep -4.3 sigma, heart rate +2.8 sigma...").
- **Rule:** it never changes an alert level and never diagnoses. The wording is "consistent with a sustained change".
- **Tested on simulated data** (4 astronauts, 3 datasets, same protocol for 8 detectors, thresholds fixed in advance):
  it flagged a slow drift about 6-8 days after it began, while the six levels never alerted, with about 1 false-alarm day in 57.
  Simple statistics beat Isolation Forest and MEWMA at this data size. Details and limits: [`backend/ai_kit/MODEL_COMPARISON.md`](backend/ai_kit/MODEL_COMPARISON.md).
- **Status:** backend only. It is not yet connected to the Flutter app. It covers slow drifts, not sudden events (those are handled by the rules).

### Simulated data

Every reading is **invented**. Four test astronauts exercise the system:

| Crew | Story |
|---|---|
| Lena Ortiz | Normal, with natural ups and downs and a few harmless one-day blips |
| Marcus Hale | A quiet 19-day combined drift that stays inside every rule threshold |
| Aiko Tanaka | A solar storm in the last 12 hours |
| Omar Haddad | A sudden breathing emergency in the last 2 hours |

The app's demo uses four built-in scenarios (nominal day, strained week, solar storm, cabin air event).



## Run it

### Test account
lena.ortiz@astrovitals.demo
password: passw0rd1

### Backend (Python 3.10+)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Open <http://localhost:8000/health> (should show `"rules_loaded": true`) and <http://localhost:8000/docs>.

Replay the simulated mission day by day and run the early-warning model (server must be running):

```bash
python -m sim.replay --reset                     # all 40 days
curl -X POST http://localhost:8000/v1/anomalies/run
# then open http://localhost:8000/demo to compare the model with the app's rules
```

Tests:

```bash
pytest -q
```

### Flutter app

Needs a Flutter version that includes Dart 3.9 or newer.

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Use **Demo controls** at the top of the app: *Location* (environment), *Display* (normal / night / EVA) and *Demo data* (scenario).

| To see | Set | Then |
|---|---|---|
| Emergency takeover | Demo data: **Cabin air event** | Confirm the two steps to close |
| Solar storm | Demo data: **Solar storm** | Tap **Solar storm steps** on the alert |
| Distance-aware advice | Location: **Space station**, then **Transit** | Compare the banner on the Today page |
| Body map | Demo data: **Strained week** | Tap a body system |



## How this meets the challenge

| The brief asks for | Where |
|---|---|
| Gather health indicators (blood pressure, heart rate, glucose, temperature, sleep, mood) | Vitals and Check-in pages, plus oxygen, breathing, cabin air and radiation |
| Help astronauts evaluate and act | Six levels with clear actions, emergency takeover |
| Colour coding for a quick read | Colour **and** shape per level |
| Clickable human figure | Body map with 7 systems |
| Dynamic charts | Sparklines, zone bars, 14-day health index |
| Gamification | Mission journey, logging streaks, badges |
| Prompts and simple explanations | Daily check-in; every metric explains how to measure it and why it matters |
| Different environments | Station, lunar base, transit vehicle, Mars base |
| NASA's five hazards | Radiation, isolation, distance, gravity, closed environment (Progress page and check-in groups) |

## Limitations

- The Flutter app runs on built-in demo data. **It is not connected to the backend yet.**
- The early-warning model is not shown in the app and covers slow drifts only.
- All crew data is simulated. The drift pattern is a demo hypothesis, not medical evidence.

## Roadmap

1. Connect the app to the backend (readings, rules, alert actions).
2. Show the early-warning card in the app (separate from the six levels).
3. Ground report: one message with readings, steps confirmed with times, and the model's note.
4. Fast layer for sudden events, and an environment-change prompt with per-environment baselines.
5. Review of thresholds and procedures by a medical professional.


## Disclaimer

AstroVitals is a hackathon prototype for decision support. It is **not** a medical device and does not diagnose. All data shown is simulated.

## Credits and license

- Fonts: Chakra Petch and IBM Plex Sans (bundled; see their licenses).
- First-aid procedures and sources are cited inside the app's Emergency guide.
- Challenge: NASA Space Apps Challenge 2026.
- License: [CHOOSE ONE, for example MIT, and add a LICENSE file]
