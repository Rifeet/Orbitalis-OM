from typing import Any, Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..ingest import DEFAULT_CREW, ingest, validate_reading
from ..models import Crew, MetricDef, Reading

router = APIRouter(prefix="/v1", tags=["readings"])


def reading_json(r: Reading) -> dict:
    """Same shape as the app's Reading.toJson()/fromJson()."""
    return {"id": r.id, "seq": r.seq, "crew_id": r.crew_id, "metric": r.metric, "field": r.field,
            "value": r.value, "unit": r.unit, "time": r.time_ms,
            "source": {"kind": r.source_kind, "device": r.source_device, "route": r.source_route,
                       "type": r.source_type},
            "quality": r.quality, "context": r.context_json}


@router.post("/readings")
def post_readings(response: Response, body: Any = Body(...), db: Session = Depends(get_db)):
    """Save one reading, a list of readings, or {"readings": [...]}.

    Every item gets its own result. The same id twice is saved once ('duplicate').
    422 only when NOTHING could be stored; otherwise 200 with the per-item report.
    """
    report = ingest(db, body, "readings", Reading, validate_reading)
    if report["accepted"] == 0 and report["duplicates"] == 0:
        response.status_code = 422
    return report


@router.get("/readings")
def get_readings(
    crew_id: str = DEFAULT_CREW,
    metric: Optional[str] = None,
    from_ms: Optional[int] = Query(None, alias="from", description="UTC epoch ms, inclusive"),
    to_ms: Optional[int] = Query(None, alias="to", description="UTC epoch ms, inclusive"),
    limit: int = Query(500, ge=1, le=5000),
    order: str = Query("asc", pattern="^(asc|desc)$"),
    db: Session = Depends(get_db),
):
    if db.get(Crew, crew_id) is None:
        raise HTTPException(404, "crew not found")
    q = select(Reading).where(Reading.crew_id == crew_id)
    if metric:
        if not db.scalar(select(MetricDef.api_metric).where(MetricDef.api_metric == metric)):
            raise HTTPException(422, f"unknown metric {metric!r}")
        q = q.where(Reading.metric == metric)
    if from_ms is not None:
        q = q.where(Reading.time_ms >= from_ms)
    if to_ms is not None:
        q = q.where(Reading.time_ms <= to_ms)
    q = q.order_by(Reading.time_ms.desc() if order == "desc" else Reading.time_ms, Reading.id).limit(limit)
    return [reading_json(r) for r in db.scalars(q)]
