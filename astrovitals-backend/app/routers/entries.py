from typing import Any, Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..ingest import DEFAULT_CREW, ingest, validate_entry
from ..models import Crew, Entry, FieldDef

router = APIRouter(prefix="/v1", tags=["entries"])


def entry_json(e: Entry) -> dict:
    """Same shape as the app's CrewEntry.toJson() (+ crew_id)."""
    return {"id": e.id, "seq": e.seq, "crew_id": e.crew_id, "field": e.field, "payload": e.payload_json,
            "ts": e.ts_ms}


@router.post("/entries")
def post_entries(response: Response, body: Any = Body(...), db: Session = Depends(get_db)):
    """Save one check-in entry, a list, or {"entries": [...]}. Same per-item report as /v1/readings.

    `payload` may be empty ({}): the app currently only stamps that a field was touched."""
    report = ingest(db, body, "entries", Entry, validate_entry)
    if report["accepted"] == 0 and report["duplicates"] == 0:
        response.status_code = 422
    return report


@router.get("/entries")
def get_entries(
    crew_id: str = DEFAULT_CREW,
    field: Optional[str] = None,
    from_ms: Optional[int] = Query(None, alias="from"),
    to_ms: Optional[int] = Query(None, alias="to"),
    limit: int = Query(500, ge=1, le=5000),
    order: str = Query("asc", pattern="^(asc|desc)$"),
    db: Session = Depends(get_db),
):
    if db.get(Crew, crew_id) is None:
        raise HTTPException(404, "crew not found")
    q = select(Entry).where(Entry.crew_id == crew_id)
    if field:
        if db.get(FieldDef, field) is None:
            raise HTTPException(422, f"unknown field {field!r}")
        q = q.where(Entry.field == field)
    if from_ms is not None:
        q = q.where(Entry.ts_ms >= from_ms)
    if to_ms is not None:
        q = q.where(Entry.ts_ms <= to_ms)
    q = q.order_by(Entry.ts_ms.desc() if order == "desc" else Entry.ts_ms, Entry.id).limit(limit)
    return [entry_json(e) for e in db.scalars(q)]
