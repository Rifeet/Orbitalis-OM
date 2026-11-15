from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Astronaut, RadiationReading
from ..schemas import RadiationCreate, RadiationOut
from ..utils import range_start

router = APIRouter(prefix="/radiation", tags=["radiation"])


@router.post("", response_model=RadiationOut, status_code=201)
def add_reading(body: RadiationCreate, db: Session = Depends(get_db)):
    if body.astronaut_id is not None and not db.get(Astronaut, body.astronaut_id):
        raise HTTPException(404, "astronaut not found")
    r = RadiationReading(**body.model_dump(mode="python"))
    r.unit = body.unit.value
    r.dose_type = body.dose_type.value
    r.source = body.source.value
    db.add(r)
    db.commit()
    return r


@router.get("/current", response_model=list[RadiationOut])
def current(db: Session = Depends(get_db)):
    """Latest reading per device."""
    latest = (
        select(RadiationReading.device_id, func.max(RadiationReading.timestamp).label("ts"))
        .group_by(RadiationReading.device_id)
        .subquery()
    )
    q = select(RadiationReading).join(
        latest,
        (RadiationReading.device_id == latest.c.device_id)
        & (RadiationReading.timestamp == latest.c.ts),
    )
    return db.scalars(q.order_by(RadiationReading.device_id)).all()


@router.get("", response_model=list[RadiationOut])
def history(
    device_id: Optional[str] = None,
    astronaut_id: Optional[int] = None,
    range: str = "24h",
    db: Session = Depends(get_db),
):
    q = select(RadiationReading).where(RadiationReading.timestamp >= range_start(range))
    if device_id:
        q = q.where(RadiationReading.device_id == device_id)
    if astronaut_id is not None:
        q = q.where(RadiationReading.astronaut_id == astronaut_id)
    return db.scalars(q.order_by(RadiationReading.timestamp)).all()
