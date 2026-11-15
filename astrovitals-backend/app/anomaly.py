"""Early-warning model: personal baseline + Mahalanobis distance on the daily vector + 2-of-3-day rule.

Reads `readings`, writes `anomaly_results`. It never touches alerts: the app's rules stay in charge.
Chosen in ai_kit/MODEL_COMPARISON.md (see also ai_kit/compare_models.py for the protocol).

Steps
  1. A "day" = 24 h counted from the astronaut's first reading. Each metric's value for the day is the median
     of that day's readings (cumulative_dose is skipped: it only rises).
  2. Baseline: the first LEARN_DAYS days are assumed normal. Per astronaut and metric: median and robust spread
     (MAD), shrunk toward the crew-wide spread because 20 days is little data.
  3. Every day becomes 15 z-scores ("how many normal wobbles from MY normal").
  4. Mahalanobis distance of that 15-number vector from the cloud of normal days (Ledoit-Wolf covariance, so
     several small shifts add up). Flag if it exceeds the chi-square 99.5 % cut-off. Fixed, never tuned.
  5. Alert only if flagged on 2 of the last 3 days. One-day blips do not trigger.

Output wording is "consistent with", never a diagnosis.
"""
from __future__ import annotations

from collections import defaultdict
from statistics import median
from typing import Optional

import numpy as np
from scipy.stats import chi2
from sklearn.covariance import LedoitWolf
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from .models import AnomalyResult, Reading

MODEL_VERSION = "maha-v1"
COMBINED = "_combined_"
DAY_MS = 86_400_000
LEARN_DAYS = 20
FEATS = ["heart_rate", "blood_pressure", "spo2", "blood_glucose", "body_temperature", "sleep_hours", "mood_daily",
         "exercise_minutes", "respiratory_rate", "body_mass", "co2_ppm", "cabin_humidity", "cabin_temperature",
         "cabin_noise", "dose_rate"]
NAMES = {"heart_rate": "heart rate", "blood_pressure": "blood pressure", "spo2": "oxygen saturation",
         "blood_glucose": "blood glucose", "body_temperature": "body temperature", "sleep_hours": "sleep",
         "mood_daily": "mood", "exercise_minutes": "exercise", "respiratory_rate": "breathing rate",
         "body_mass": "body mass", "co2_ppm": "cabin CO2", "cabin_humidity": "cabin humidity",
         "cabin_temperature": "cabin temperature", "cabin_noise": "cabin noise", "dose_rate": "radiation dose rate"}
CHI2_P = 0.995
PERSIST_K, PERSIST_WINDOW = 2, 3
SHRINK_M = 10


def daily_vectors(db: Session, crew_id: str) -> tuple[Optional[int], list[dict]]:
    """-> (t0, [{'day': 1.., 'last_ms', 'values': {metric: median}} ...]) in order. Days without data are skipped."""
    rows = db.execute(select(Reading.time_ms, Reading.metric, Reading.value)
                      .where(Reading.crew_id == crew_id, Reading.metric.in_(FEATS))
                      .order_by(Reading.time_ms)).all()
    if not rows:
        return None, []
    t0 = db.scalar(select(Reading.time_ms).where(Reading.crew_id == crew_id).order_by(Reading.time_ms).limit(1))
    buckets: dict[int, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    last: dict[int, int] = {}
    for t, m, v in rows:
        k = (t - t0) // DAY_MS
        buckets[k][m].append(v)
        last[k] = max(last.get(k, 0), t)
    out = [{"day": k + 1, "last_ms": last[k], "values": {m: median(v) for m, v in buckets[k].items()}}
           for k in sorted(buckets)]
    return t0, out


def _matrix(days: list[dict]) -> np.ndarray:
    return np.array([[d["values"].get(f, np.nan) for f in FEATS] for d in days], dtype=float)


def _personal(train: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    med = np.nanmedian(train, axis=0)
    mad = np.nanmedian(np.abs(train - med), axis=0) * 1.4826
    std = np.nanstd(train, axis=0, ddof=1)
    return med, np.where(mad > 0, mad, std)


def run_model(db: Session, crew_ids: Optional[list[str]] = None) -> dict:
    """Recompute everything from the readings now in the database and replace this model's rows. Safe to repeat."""
    all_ids = [c for (c,) in db.execute(select(Reading.crew_id).distinct().order_by(Reading.crew_id))]
    data = {c: daily_vectors(db, c) for c in all_ids}
    ready = {c: d for c, (t0, d) in data.items() if len(d) > LEARN_DAYS}
    status = {c: {"days_of_data": len(d), "learning_days_needed": max(0, LEARN_DAYS + 1 - len(d)),
                  "status": "scoring" if c in ready else "learning"} for c, (t0, d) in data.items()}
    if not ready:
        return {"model_version": MODEL_VERSION, "crew": status, "rows_written": 0}

    # personal baselines
    params, mats = {}, {}
    for c, d in ready.items():
        M = _matrix(d)
        mats[c] = M
        params[c] = _personal(M[:LEARN_DAYS])
    pool = np.median(np.stack([p[1] for p in params.values()]), axis=0)
    pool = np.where(pool > 0, pool, 1e-6)
    sd = {c: np.sqrt((LEARN_DAYS * s ** 2 + SHRINK_M * pool ** 2) / (LEARN_DAYS + SHRINK_M)).clip(1e-6)
          for c, (m, s) in params.items()}
    Z = {c: np.nan_to_num((mats[c] - params[c][0]) / sd[c], nan=0.0) for c in ready}   # missing metric = "normal"

    # the cloud of normal days (everyone's learning days, in personal z-scores)
    train = np.vstack([Z[c][:LEARN_DAYS] for c in ready])
    lw = LedoitWolf().fit(train)
    thr = float(chi2.ppf(CHI2_P, len(FEATS)))

    targets = [c for c in ready if crew_ids is None or c in crew_ids]
    rows = 0
    for c in targets:
        d = ready[c]
        diff = Z[c] - lw.location_
        d2 = np.einsum("ij,jk,ik->i", diff, lw.precision_, diff)
        raw = d2 > thr
        db.execute(delete(AnomalyResult).where(AnomalyResult.model_version == MODEL_VERSION,
                                               AnomalyResult.crew_id == c))
        for i in range(LEARN_DAYS, len(d)):
            hits = int(raw[max(0, i - PERSIST_WINDOW + 1): i + 1].sum())
            flagged = hits >= PERSIST_K
            db.add(AnomalyResult(crew_id=c, metric=COMBINED, time_ms=d[i]["last_ms"], reading_id=None,
                                 score=round(float(d2[i] / thr), 4), flagged=flagged, model_version=MODEL_VERSION,
                                 reason=_reason(Z[c][i], bool(raw[i]), hits, flagged)))
            rows += 1
        status[c].update(scored_days=len(d) - LEARN_DAYS,
                         flagged_days=int(sum(1 for i in range(LEARN_DAYS, len(d))
                                              if raw[max(0, i - PERSIST_WINDOW + 1): i + 1].sum() >= PERSIST_K)))
    db.commit()
    return {"model_version": MODEL_VERSION, "threshold_d2": round(thr, 2), "crew": status, "rows_written": rows}


def _reason(z: np.ndarray, raw: bool, hits: int, flagged: bool) -> str:
    if not raw and not flagged:
        return "Within this astronaut's personal normal."
    top = np.argsort(-np.abs(z))[:4]
    parts = [f"{NAMES[FEATS[i]]} {z[i]:+.1f}σ" for i in top if abs(z[i]) >= 1.0]
    detail = ", ".join(parts) if parts else "several small shifts"
    if flagged:
        return (f"Early warning: pattern consistent with a sustained change from personal normal "
                f"({hits} of last {PERSIST_WINDOW} days unusual). Largest shifts: {detail}.")[:500]
    return (f"Watching: unusual day, not yet repeated ({hits} of last {PERSIST_WINDOW}). "
            f"Largest shifts: {detail}.")[:500]
