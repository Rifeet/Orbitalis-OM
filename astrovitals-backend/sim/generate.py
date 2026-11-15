"""Simulated crew for the AstroVitals demo and for testing the anomaly model.

Four astronauts, each built to exercise one thing:

  c1  NORMAL          healthy, with natural ups and downs and a few harmless one-day 'watch' blips.
                      The model must NOT flag these (false-alarm check).
  c2  QUIET DRIFT     a slow, combined change over ~19 days (heart rate up, sleep down, temperature
                      up, breathing up, oxygen down, exercise down, mood down, dose rate a bit high).
                      Every value stays inside the app's rule thresholds, so the rules stay quiet,
                      but the COMBINATION points to chronic radiation exposure.
  c3  SOLAR STORM     normal until a solar particle event in the last 12 hours: dose rate climbs to
                      ~9x the expected level (this astronaut was outside the shelter).
  c4  EMERGENCY       normal until the last 2 hours, then a sudden breathing emergency:
                      oxygen falls below 90 % (level 5), breathing and heart rate shoot up.

IMPORTANT: this is INVENTED data. The c2 pattern is a demo hypothesis, not medical evidence. Every
reading carries context.simulated = true and ids starting with 'sim_'.

Everything is deterministic: same (end_ms, days, seed) gives identical data.
"""
from __future__ import annotations

import math
import random
from typing import Any

from .levels import Levels, tier_of

DAY_MS = 86_400_000
HOUR_MS = 3_600_000
MIN_MS = 60_000
DATASET = "demo"

CREW = [
    {"id": "c1", "name": "Lena Ortiz", "role": "Flight engineer", "story": "normal"},
    {"id": "c2", "name": "Marcus Hale", "role": "Mission specialist", "story": "quiet_drift"},
    {"id": "c3", "name": "Aiko Tanaka", "role": "EVA specialist", "story": "solar_storm"},
    {"id": "c4", "name": "Omar Haddad", "role": "Systems engineer", "story": "emergency"},
]

# personal normal values (keys follow the app's series keys; dia/dose are extra)
PERSON = {
    "c1": dict(hr=66, sys=112, dia=72, spo2=98, glu=90, temp=36.6, sleep=7.8, mood=4.4, ex=125, resp=15,
               mass=74.0, co2=2300, hum=47, ctemp=22.5, noise=47, dose=0.6),
    "c2": dict(hr=64, sys=110, dia=70, spo2=98, glu=88, temp=36.5, sleep=7.7, mood=4.5, ex=135, resp=14,
               mass=74.5, co2=2350, hum=46, ctemp=22.0, noise=46, dose=0.6),
    "c3": dict(hr=70, sys=118, dia=76, spo2=98, glu=92, temp=36.6, sleep=7.6, mood=4.3, ex=140, resp=15,
               mass=73.0, co2=2250, hum=48, ctemp=23.0, noise=48, dose=0.6),
    "c4": dict(hr=68, sys=116, dia=74, spo2=98, glu=91, temp=36.7, sleep=7.9, mood=4.4, ex=120, resp=16,
               mass=75.0, co2=2300, hum=47, ctemp=22.5, noise=47, dose=0.6),
}

# api metric -> (key in PERSON, normal day-to-day spread). Spread is clipped at 1.8x, which keeps every
# natural value inside the app's level-0 band (checked by the tests).
METRICS = [
    ("heart_rate", "hr", 2.2), ("blood_pressure", "sys", 3.0), ("spo2", "spo2", 0.4),
    ("blood_glucose", "glu", 3.0), ("body_temperature", "temp", 0.10), ("sleep_hours", "sleep", 0.25),
    ("mood_daily", "mood", 0.35), ("exercise_minutes", "ex", 8.0), ("respiratory_rate", "resp", 0.7),
    ("body_mass", "mass", 0.15), ("co2_ppm", "co2", 150), ("cabin_humidity", "hum", 2.5),
    ("cabin_temperature", "ctemp", 0.5), ("cabin_noise", "noise", 2.0), ("dose_rate", "dose", 0.04),
]
DEVICE_SERIES = {"heart_rate": "hr", "blood_pressure": "sys", "spo2": "spo2", "blood_glucose": "glu",
                 "body_temperature": "temp", "sleep_hours": "sleep", "exercise_minutes": "ex",
                 "respiratory_rate": "resp", "body_mass": "mass", "co2_ppm": "co2", "cabin_humidity": "hum",
                 "cabin_temperature": "ctemp", "cabin_noise": "noise", "dose_rate": "rad",
                 "cumulative_dose": "rad"}
MANUAL = {"mood_daily"}

# ---- c1: harmless one-day blips (days before the end, metric, value) -> all land in level 1 ('Monitor')
C1_BLIPS = [(26, "sleep_hours", 6.7), (22, "heart_rate", 92), (18, "mood_daily", 3), (14, "blood_glucose", 103),
            (10, "sleep_hours", 6.6), (7, "exercise_minutes", 84), (4, "body_temperature", 37.4),
            (2, "respiratory_rate", 21)]

# ---- c2: the quiet drift. Full-strength change reached ~7 days before the end.
C2_DRIFT_START_J = 19          # days before the end when the drift begins
C2_RAMP_DAYS = 12
C2_DELTA = {"heart_rate": 9.0, "sleep_hours": -1.1, "mood_daily": -0.9, "body_temperature": 0.30,
            "respiratory_rate": 1.8, "spo2": -1.3, "exercise_minutes": -25.0, "body_mass": -1.3}
C2_DOSE_FACTOR = 0.30          # dose rate up to +30 % (stays under the 1.5x rule threshold)
C2_DOSE_BUMP_J, C2_DOSE_BUMP = 20, 0.86   # one quiet day at 1.43x, just before the drift

# ---- c3: solar storm, hourly for the last 12 h. Ratio to the expected dose rate.
C3_STORM_RATIOS = [1.0, 1.1, 1.4, 2.2, 3.1, 4.4, 5.6, 6.8, 7.9, 8.6, 9.0, 8.4, 7.6]   # -12 h ... now

# ---- c4: breathing emergency, every 5 min for the last 2 h. (minutes before the end, value)
C4_KEYS = {
    "heart_rate": [(-120, 68), (-60, 72), (-50, 78), (-35, 92), (-20, 108), (-10, 124), (0, 138)],
    "spo2": [(-120, 98), (-55, 98), (-45, 97), (-35, 95), (-25, 93), (-15, 91.0), (-12, 89.5), (-5, 87), (0, 84)],
    "respiratory_rate": [(-120, 15), (-55, 15.5), (-45, 18), (-30, 23), (-15, 29), (-5, 33), (0, 36)],
    "blood_pressure": [(-120, 116), (-55, 118), (-40, 124), (-20, 134), (-10, 142), (0, 152)],
    "_diastolic": [(-120, 74), (-55, 75), (-40, 78), (-10, 88), (0, 96)],
}
C4_JITTER = {"heart_rate": 1.2, "spo2": 0.35, "respiratory_rate": 0.5, "blood_pressure": 1.5, "_diastolic": 1.0}
C4_ONSET_MIN = 50              # label window starts 50 min before the end


def _rng(seed: int, *parts: str) -> random.Random:
    return random.Random("-".join([str(seed), *parts]))      # str seeds are deterministic


def _natural(rng: random.Random, base: float, sd: float, n: int, phi: float = 0.35, clip: float = 1.8) -> list[float]:
    """Smooth day-to-day wobble around a personal normal (AR(1) noise, clipped)."""
    x, out = 0.0, []
    for _ in range(n):
        x = phi * x + math.sqrt(1 - phi * phi) * rng.gauss(0, 1)
        x = max(-clip, min(clip, x))
        out.append(base + sd * x)
    return out


def _interp(keys: list[tuple[float, float]], t: float) -> float:
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t0 <= t <= t1:
            return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return keys[-1][1]


def _smoothstep(u: float) -> float:
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def generate(end_ms: int, days: int = 30, seed: int = 7, env: str = "iss") -> dict[str, Any]:
    if days < 30:
        raise ValueError("days must be at least 30 (the scenarios reach back 27 days)")
    levels = Levels()
    rules = levels.rules
    mdef = {m["api_metric"]: m for m in rules["metrics"]}
    dev = rules["devices"]

    def rnd(api: str, v: float):
        d = mdef[api]["decimals"]
        v = round(v, d)
        return int(v) if d == 0 else v

    def source(api: str) -> dict:
        if api in MANUAL:
            return {"kind": "manual", "device": "Manual entry", "route": "", "type": "manual"}
        spec = dev[DEVICE_SERIES[api]]
        return {"kind": "device", "device": spec["device"], "route": spec["route"], "type": spec["kind"]}

    def t_of(j: int) -> int:                      # daily time, j days before the end (0 = now)
        return end_ms - j * DAY_MS

    readings: list[dict] = []
    seqs = {c["id"]: 0 for c in CREW}

    def add(crew: str, api: str, value: float, t: int, extra_ctx: dict | None = None, j: int | None = None):
        seqs[crew] += 1
        md = 1 + (days - 1 - j) if j is not None else days
        ctx = {"mission_day": md, "location": env, "simulated": True, **(extra_ctx or {})}
        m = mdef[api]
        readings.append({"id": f"sim_{crew}_{api}_{t}", "seq": seqs[crew], "crew_id": crew, "metric": api,
                         "field": m["field"], "value": value, "unit": m["unit"], "time": t,
                         "source": source(api), "quality": "ok", "context": ctx})

    entries: list[dict] = []

    def add_entry(crew: str, t: int, symptoms: list[str], severity: int):
        n = sum(1 for e in entries if e["crew_id"] == crew) + 1
        entries.append({"id": f"sim_e_{crew}_{t}", "seq": n, "crew_id": crew, "field": "symptom_checklist",
                        "payload": {"symptoms": symptoms, "severity": severity, "simulated": True}, "ts": t})

    labels: list[dict] = []

    def label(crew: str, metric: str, start: int, end: int, scenario: str, expected: bool, note: str):
        labels.append({"dataset": DATASET, "crew_id": crew, "metric": metric, "start_ms": start, "end_ms": end,
                       "scenario": scenario, "expected": expected, "note": note})

    story = {c["id"]: c["story"] for c in CREW}

    # ------------------------------------------------------------------ daily readings for everyone
    for crew in (c["id"] for c in CREW):
        p = PERSON[crew]
        daily: dict[str, list] = {}
        dia_nat = _natural(_rng(seed, crew, "dia"), p["dia"], 2.5, days)
        for api, key, sd in METRICS:
            vals = _natural(_rng(seed, crew, api), p[key], sd, days)
            for k in range(days):
                j = days - 1 - k
                v = vals[k]
                if story[crew] == "quiet_drift":
                    s = _smoothstep((C2_DRIFT_START_J - j) / C2_RAMP_DAYS)
                    if api in C2_DELTA:
                        v += C2_DELTA[api] * s
                    if api == "dose_rate":
                        v = C2_DOSE_BUMP if j == C2_DOSE_BUMP_J else v * (1 + C2_DOSE_FACTOR * s)
                if api == "mood_daily":
                    v = max(1.0, min(5.0, v))
                if api == "spo2":
                    v = min(100.0, v)
                vals[k] = v
            if story[crew] == "normal":
                for bj, bapi, bval in C1_BLIPS:
                    if bapi == api:
                        vals[days - 1 - bj] = bval
            daily[api] = [rnd(api, v) for v in vals]

        dose = daily["dose_rate"]
        cum, run = [], 0.0
        for v in dose:
            run += v
            cum.append(round(run, 2))
        daily["cumulative_dose"] = cum

        skip: set[tuple[str, int]] = set()          # (metric, j) replaced by a high-frequency stream
        if story[crew] == "solar_storm":
            skip |= {("dose_rate", 0), ("cumulative_dose", 0)}
        if story[crew] == "emergency":
            skip |= {(m, 0) for m in ("heart_rate", "blood_pressure", "spo2", "respiratory_rate")}

        for k in range(days):
            j = days - 1 - k
            for api in [m[0] for m in METRICS] + ["cumulative_dose"]:
                if (api, j) in skip:
                    continue
                ctx = {"diastolic": rnd("heart_rate", dia_nat[k])} if api == "blood_pressure" else None
                add(crew, api, daily[api][k], t_of(j), ctx, j)

        # ------------------------------------------------------------ scenario tails
        if story[crew] == "solar_storm":
            cum_now = daily["cumulative_dose"][days - 2] + p["dose"] / 24 * 12
            r = _rng(seed, crew, "storm")
            for i, ratio in enumerate(C3_STORM_RATIOS):
                t = end_ms - (12 - i) * HOUR_MS
                rate = ratio * p["dose"] * (1 + max(-0.04, min(0.04, r.gauss(0, 0.02))))
                cum_now += rate / 24
                add(crew, "dose_rate", rnd("dose_rate", rate), t)
                add(crew, "cumulative_dose", rnd("cumulative_dose", cum_now), t)

        if story[crew] == "emergency":
            r = _rng(seed, crew, "stream")
            for m in range(-120, 1, 5):
                t = end_ms + m * MIN_MS
                vals = {}
                for name, keys in C4_KEYS.items():
                    jit = max(-2.0, min(2.0, r.gauss(0, 1))) * C4_JITTER[name]
                    vals[name] = _interp(keys, m) + jit
                vals["spo2"] = min(100.0, vals["spo2"])
                add(crew, "heart_rate", rnd("heart_rate", vals["heart_rate"]), t)
                add(crew, "spo2", rnd("spo2", vals["spo2"]), t)
                add(crew, "respiratory_rate", rnd("respiratory_rate", vals["respiratory_rate"]), t)
                add(crew, "blood_pressure", rnd("blood_pressure", vals["blood_pressure"]), t,
                    {"diastolic": rnd("blood_pressure", vals["_diastolic"])})

    # ------------------------------------------------------------------ symptom check-ins (context)
    add_entry("c1", t_of(13), ["Headache"], 1)
    add_entry("c1", t_of(22), ["Fatigue"], 1)
    for j, sym, sev in [(9, ["Fatigue"], 1), (6, ["Fatigue"], 2), (4, ["Headache"], 2), (2, ["Fatigue", "Loss of appetite"], 2),
                        (0, ["Fatigue"], 2)]:
        add_entry("c2", t_of(j), sym, sev)
    add_entry("c3", end_ms - 6 * HOUR_MS, ["Nausea"], 2)
    add_entry("c3", end_ms - 2 * HOUR_MS, ["Fatigue", "Headache"], 2)
    add_entry("c4", end_ms - 45 * MIN_MS, ["Headache"], 2)

    # ------------------------------------------------------------------ labels = the correct answers
    for bj, bapi, _ in C1_BLIPS:
        label("c1", bapi, t_of(bj) - 6 * HOUR_MS, t_of(bj) + 6 * HOUR_MS, "benign_blip", False,
              "one-day watch-level value that recovers; the model should NOT flag it")
    c2_start = t_of(C2_DRIFT_START_J)
    for api in list(C2_DELTA) + ["dose_rate"]:
        label("c2", api, c2_start, end_ms, "quiet_drift", True, "part of the slow combined drift")
    label("c2", "_combined_", c2_start, end_ms, "quiet_drift", True,
          "several signals drift together while each stays inside the rule thresholds")
    c3_start = end_ms - 12 * HOUR_MS
    # only dose_rate is labelled: cumulative_dose is a running total that always rises (a model must difference it)
    label("c3", "dose_rate", c3_start, end_ms, "solar_storm", True, "dose rate far above expected")
    label("c3", "_combined_", c3_start, end_ms, "solar_storm", True, "acute radiation event")
    c4_start = end_ms - C4_ONSET_MIN * MIN_MS
    for api in ("heart_rate", "blood_pressure", "spo2", "respiratory_rate"):
        label("c4", api, c4_start, end_ms, "respiratory_emergency", True, "sudden breathing emergency")
    label("c4", "_combined_", c4_start, end_ms, "respiratory_emergency", True, "sudden breathing emergency")

    # ------------------------------------------------------------------ rule levels + the alerts the app would raise
    readings.sort(key=lambda r: (r["time"], r["crew_id"], r["metric"]))
    lv = {r["id"]: levels.reading_level(r["metric"], r["value"], r["context"], env) for r in readings}
    tier_names = rules["meta"]["tier_names"]
    alerts: list[dict] = []
    episode: dict[tuple, int] = {}
    for r in readings:
        key, L = (r["crew_id"], r["metric"]), lv[r["id"]]
        if L < 2:
            episode[key] = 0
            continue
        if L > episode.get(key, 0):                       # new alert only when an episode starts or worsens
            episode[key] = L
            name = mdef[r["metric"]]["name"]
            alerts.append({
                "id": f"sim_alert_{r['crew_id']}_{r['metric']}_{r['time']}", "crew_id": r["crew_id"],
                "metric": r["metric"], "field": r["field"], "lvl": L, "tier": tier_of(L),
                "title": f"{name}: {tier_names[L]}", "obs": f"{r['value']:g} {r['unit']}",
                "acts_json": [], "contact": "Contact the flight surgeon." if L >= 3 else "",
                "state": "raised" if r["time"] >= end_ms - 12 * HOUR_MS else "cleared",
                "raised_ms": r["time"], "updated_ms": r["time"], "override_reason": None})

    return {"meta": {"end_ms": end_ms, "days": days, "seed": seed, "env": env, "dataset": DATASET},
            "crew": CREW, "readings": readings, "levels": lv, "entries": entries, "labels": labels,
            "alerts": alerts, "truth": build_truth(readings, lv, labels, end_ms)}


def build_truth(readings: list[dict], lv: dict, labels: list[dict], end_ms: int) -> dict:
    """Per astronaut: scenario window, personal baseline, and when the app's RULES would first have reacted."""
    truth = {}
    for c in CREW:
        cid = c["id"]
        win = next((l for l in labels if l["crew_id"] == cid and l["metric"] == "_combined_"), None)
        rows = [r for r in readings if r["crew_id"] == cid]
        if win:
            before = [lv[r["id"]] for r in rows if r["time"] < win["start_ms"]]
            inside = [r for r in rows if win["start_ms"] <= r["time"] <= win["end_ms"]]
        else:
            before, inside = [], rows
        first = {f"ge{n}": next((r["time"] for r in sorted(inside, key=lambda x: x["time"]) if lv[r["id"]] >= n), None)
                 for n in (1, 2, 3, 4, 5)}
        truth[cid] = {
            "name": c["name"], "story": c["story"], "personal_baseline": PERSON[cid],
            "window_start_ms": win["start_ms"] if win else None, "window_end_ms": win["end_ms"] if win else None,
            "max_rule_level_before_window": max(before) if before else None,
            "max_rule_level_overall": max(lv[r["id"]] for r in rows),
            "rules_first_reached_level_ms": first,
        }
    truth["_note"] = ("Invented data. rules_first_reached_level_ms = first time ANY reading inside the window reached "
                      "that app level, i.e. when the existing rules would have reacted. Compare with when your model flagged.")
    return truth


def utc(ms: int) -> str:
    from datetime import datetime, timezone
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).isoformat(timespec="seconds")


def csv_rows(data: dict) -> list[dict]:
    """Flat table for the AI notebook: one row per reading, with the rule level and the correct answer."""
    by = {}
    for l in data["labels"]:
        by.setdefault((l["crew_id"], l["metric"]), []).append(l)
    rows = []
    for r in data["readings"]:
        hit = next((l for l in by.get((r["crew_id"], r["metric"]), [])
                    if l["start_ms"] <= r["time"] <= l["end_ms"] and l["expected"]), None)
        rows.append({"id": r["id"], "crew_id": r["crew_id"], "metric": r["metric"], "time_ms": r["time"],
                     "time_utc": utc(r["time"]), "value": r["value"], "unit": r["unit"],
                     "diastolic": r["context"].get("diastolic", ""), "rule_level": data["levels"][r["id"]],
                     "truth_label": 1 if hit else 0, "scenario": hit["scenario"] if hit else "",
                     "source_kind": r["source"]["kind"]})
    return rows
