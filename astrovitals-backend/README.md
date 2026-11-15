# AstroVitals backend (v0.4: database, rules, readings/entries, simulated crew)

FastAPI + SQLAlchemy + SQLite. The Flutter app is the source of truth for every
threshold; the backend copies its rules into the database.

## Run

```bash
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

On first start the server creates the tables and loads the rules automatically.
Check: http://localhost:8000/health -> `{"status":"ok","rules_loaded":true}`

## Test

```bash
pytest -q                                   # ~100 tests, throwaway database
FLUTTER_LIB=path/to/astrovitals_src/lib pytest -q   # also checks the rules are not stale
```

## The rules: how they get from the app into the database

```
Flutter Dart files --(tools/extract_rules.py)--> app/rules/rules_data.json --(app/rules_loader.py)--> database
```

* `python tools/extract_rules.py path/to/astrovitals_src/lib` regenerates the JSON. It READS the Dart
  files, nothing is typed by hand. It stops with an error if the numbers look wrong (gaps in a zone table,
  wrong counts).
* `python -m app.rules_loader` loads the JSON into the database (safe to repeat; never touches readings,
  alerts or users).
* `python tools/extract_rules.py <lib> --check` says whether the JSON is out of date (use before the demo).

Loaded: 4 environments, 15 metrics, 16 zone tables (110 bands), 15 input limits, 9 baselines, 15 devices,
and settings (sleep plan, health score table, radiation dose-rate bands).

Note: the radiation zone table ('rad') is a % of the environment's mission limit; metric `rad` reads the series
`radTotal` (mSv). The dose-rate bands (1.5x / 3x / 6x of the expected rate) are in `rule_meta`.

## Tables

| Group | Tables |
|---|---|
| Rules (loaded) | env_profiles, metric_defs, zone_tables, zone_bands, input_limits, baselines, device_specs, rule_meta |
| Identity | missions, crew, users, sessions |
| Measures | readings, entries |
| Alerts | alerts, alert_actions |
| Emergency | emergencies, emergency_events |
| Other | context_confirmations, ground_reports |

Design rules:
* every time is UTC epoch **milliseconds** (`*_ms`), as in the contract;
* client-made ids are the primary keys, so a resent item can never be saved twice;
* the database itself rejects: unknown crew/metric/alert links, quality other than ok/stale/suspect,
  alert levels outside 0-5, tier outside 0-4, unknown alert states, duplicate emails, duplicate actions;
* passwords are stored only as hashes; session tokens only as sha256 hashes.

## Endpoints (so far)

| Method | Path | What it does |
|---|---|---|
| GET | /health | liveness + whether the rules are loaded |
| GET | /v1/profiles | all the app's rules (zones, limits, environments, fields...) with an ETag |
| POST | /v1/readings | save one reading, a list, or `{"readings": [...]}`; same id twice = saved once |
| GET | /v1/readings?crew_id=&metric=&from=&to=&limit=&order= | history, in the app's Reading shape |
| POST | /v1/entries | save check-in entries (same rules; empty `payload` allowed) |
| GET | /v1/entries?crew_id=&field=&from=&to= | entry history |

POST answers per item: `{"accepted", "duplicates", "rejected", "results": [{"id", "status", "errors"}]}`.
One bad item never blocks the batch. HTTP 422 only if nothing could be stored. Time must be UTC epoch **milliseconds**.
Still to build: `/v1/auth/*`, `/v1/alerts/{id}/ack|start|override`, `/v1/emergency`, `/v1/context`, `/v1/reports/ground`.
See `docs/FRONTEND_NOTES.md` for things the Flutter side must know.

## Simulated crew (for the demo and for testing the anomaly model)

```bash
python -m sim.load --reset-sim            # runs the app in-process: no server needed
python -m sim.load --reset-sim --api http://localhost:8000    # or into a running server
python -m sim.load --days 60 --end 2026-11-14T12:00:00Z --out sim_output
```

| Crew | Story | What the app's rules see | What it is for |
|---|---|---|---|
| c1 Lena Ortiz | Normal, natural ups and downs, 8 harmless one-day "watch" blips | never above level 1 | false-alarm check: the model must NOT flag the blips |
| c2 Marcus Hale | Quiet drift over 19 days: heart rate up, sleep down, temperature up, breathing up, oxygen down, exercise down, mood down, dose rate ~30 % high | never above level 1, app's pattern alert never fires | early warning: the COMBINATION points to chronic radiation exposure |
| c3 Aiko Tanaka | Normal, then a solar storm in the last 12 h (dose rate up to ~9x expected) | level 2 at about -9 h, level 4 by -5 h | solar-storm demo |
| c4 Omar Haddad | Normal, then a sudden breathing emergency in the last 2 h | first sign about -40 min, level 5 (oxygen < 90 %) at about -10 min | emergency demo |

All data is INVENTED (every reading has `context.simulated = true` and an id starting `sim_`). The c2 pattern is a demo
hypothesis, not medical evidence: word the model's output as "consistent with", never as a diagnosis.

What it writes: readings and entries (through the real API), `anomaly_labels` (the correct answers, incl. harmless
blips with `expected = false`), `alerts` (what the app's rules would have raised, with the app's tiers), and files in
`sim_output/`: `readings.csv` (one row per reading with `rule_level` and `truth_label`), `anomaly_labels.csv`, `entries.csv`, `alerts.csv`, `crew.csv`, `zone_bands.csv`, `baselines.csv`, `metrics.csv`, `truth.json`
(per astronaut: personal baseline, scenario window, and WHEN THE RULES FIRST REACHED each level).

How to test the model: train or calibrate on normal data (c1, and the days before each scenario window), score every
reading into `anomaly_results`, then compare with `truth_label` (found / missed / false alarms), and compare the time you
flagged with `truth.json -> rules_first_reached_level_ms` (lead time over the rules). The AI tables are `anomaly_labels`
and `anomaly_results`.

`ai_kit/compare_models.py` compares anomaly detectors (results and recommendation in `ai_kit/MODEL_COMPARISON.md`; needs `pip install -r ai_kit/requirements.txt`);
`ai_kit/evaluate.py` scores a model against these files; `ai_kit/example_detector.py` is a naive baseline to beat.
Keep `--days` at 40 or less if you want the app's rules to stay quiet for the normal astronaut: the running dose passes 50 % of the
app's 50 mSv mission limit after ~42 days.

Re-running: use `--reset-sim`. Without it, a different end time makes a second, overlapping dataset.

`legacy/` holds the first-draft backend (own routes and tables). It is not used and can be deleted.


## Replay the mission and run the early-warning model (v0.5)

```bash
pip install -r requirements.txt
uvicorn app.main:app --port 8000                 # terminal 1
python -m sim.replay --reset --through-day 15    # terminal 2: record days 1-15 through the real API
curl -X POST localhost:8000/v1/anomalies/run     # -> "still learning" (needs 21+ days)
python -m sim.replay --from-day 16               # record days 16-40
curl -X POST localhost:8000/v1/anomalies/run     # model scores every day after the 20 learning days
```
Open http://localhost:8000/demo for the picture. For a live feel: `python -m sim.replay --reset --day-seconds 2 --live-model`
and tick "auto" on the page.

| Method | Path | What it does |
|---|---|---|
| POST | /v1/anomalies/run | run the model on the readings stored so far, write `anomaly_results` (safe to repeat) |
| GET | /v1/anomalies?crew_id=&flagged_only= | day-by-day score, flagged, short "why" |
| GET | /v1/anomalies/overview | results next to the app's rule level and the answer key (for the demo page) |

The model (`app/anomaly.py`): personal baseline from the first 20 days, 15 z-scores per day, Mahalanobis distance
(Ledoit-Wolf, chi-square 99.5 %), flagged on 2 of the last 3 days. It never changes alerts: the rules stay in charge.
