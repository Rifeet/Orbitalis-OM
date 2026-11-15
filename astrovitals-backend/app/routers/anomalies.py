from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..anomaly import COMBINED, DAY_MS, LEARN_DAYS, MODEL_VERSION, run_model
from ..database import get_db
from ..models import Alert, AnomalyLabel, AnomalyResult, Crew, Reading

router = APIRouter(tags=["anomalies"])
PAGE = Path(__file__).resolve().parent.parent / "static" / "demo.html"


def _t0(db: Session, crew_id: str) -> Optional[int]:
    return db.scalar(select(Reading.time_ms).where(Reading.crew_id == crew_id).order_by(Reading.time_ms).limit(1))


@router.post("/v1/anomalies/run")
def run(body: Optional[dict] = Body(None), db: Session = Depends(get_db)):
    """Run the early-warning model on the readings stored so far; replaces the previous results of this model."""
    return run_model(db, (body or {}).get("crew_ids"))


@router.get("/v1/anomalies")
def list_results(crew_id: Optional[str] = None, flagged_only: bool = False, db: Session = Depends(get_db)):
    q = select(AnomalyResult).where(AnomalyResult.model_version == MODEL_VERSION)
    if crew_id:
        q = q.where(AnomalyResult.crew_id == crew_id)
    if flagged_only:
        q = q.where(AnomalyResult.flagged.is_(True))
    out = []
    for r in db.scalars(q.order_by(AnomalyResult.crew_id, AnomalyResult.time_ms)):
        t0 = _t0(db, r.crew_id)
        out.append({"crew_id": r.crew_id, "day": (r.time_ms - t0) // DAY_MS + 1, "time": r.time_ms,
                    "score": r.score, "flagged": r.flagged, "reason": r.reason, "model_version": r.model_version})
    return out


@router.get("/v1/anomalies/overview")
def overview(db: Session = Depends(get_db)):
    """Per astronaut: the model's day-by-day result next to the app's rule level and the (hidden) answer key."""
    crews = []
    for c in db.scalars(select(Crew).order_by(Crew.id)):
        t0 = _t0(db, c.id)
        if t0 is None:
            continue
        last = db.scalar(select(Reading.time_ms).where(Reading.crew_id == c.id).order_by(Reading.time_ms.desc()).limit(1))
        n_days = (last - t0) // DAY_MS + 1
        day_of = lambda ms: (ms - t0) // DAY_MS + 1                                    # noqa: E731
        res = {day_of(r.time_ms): r for r in db.scalars(
            select(AnomalyResult).where(AnomalyResult.crew_id == c.id, AnomalyResult.model_version == MODEL_VERSION))}
        rule = {}
        for a in db.scalars(select(Alert).where(Alert.crew_id == c.id)):
            rule[day_of(a.raised_ms)] = max(rule.get(day_of(a.raised_ms), 0), a.lvl)
        truth, harmless = set(), set()
        labels = list(db.scalars(select(AnomalyLabel).where(AnomalyLabel.crew_id == c.id)))
        for r in res.values():            # a day counts as "really abnormal" if its last reading is inside a window
            for l in labels:
                if l.start_ms <= r.time_ms <= l.end_ms:
                    if not l.expected:
                        harmless.add(day_of(r.time_ms))
                    elif l.metric == COMBINED:
                        truth.add(day_of(r.time_ms))
        days = []
        for d in range(1, n_days + 1):
            r = res.get(d)
            days.append({"day": d, "learning": d <= LEARN_DAYS, "scored": r is not None,
                         "score": r.score if r else None, "flagged": bool(r and r.flagged),
                         "reason": r.reason if r else ("Learning this astronaut's normal." if d <= LEARN_DAYS else None),
                         "rule_level": rule.get(d, 0), "truth": d in truth, "harmless_blip": d in harmless})
        flagged = [x["day"] for x in days if x["flagged"]]
        crews.append({"crew_id": c.id, "name": c.name, "role": c.role, "days": days,
                      "summary": {"scored_days": sum(x["scored"] for x in days), "flagged_days": len(flagged),
                                  "first_flag_day": flagged[0] if flagged else None,
                                  "first_true_day": min(truth) if truth else None,
                                  "false_alarm_days": sum(1 for x in days if x["flagged"] and x["day"] not in truth),
                                  "harmless_blips_flagged": sum(1 for x in days if x["flagged"] and x["harmless_blip"]),
                                  "harmless_blips_total": len(harmless),
                                  "max_rule_level": max(rule.values(), default=0)}})
    return {"model_version": MODEL_VERSION, "learn_days": LEARN_DAYS, "crew": crews}


@router.get("/demo", response_class=HTMLResponse, include_in_schema=False)
def demo():
    if not PAGE.exists():
        raise HTTPException(404, "demo page missing")
    return PAGE.read_text(encoding="utf-8")
