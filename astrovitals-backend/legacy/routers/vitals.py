from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Astronaut, Vital
from ..schemas import VitalCreate, VitalOut, VitalType
from ..utils import range_start

router = APIRouter(prefix="/vitals", tags=["vitals"])


@router.post("", response_model=VitalOut, status_code=201)
def add_vital(body: VitalCreate, db: Session = Depends(get_db)):
    if not db.get(Astronaut, body.astronaut_id):
        raise HTTPException(404, "astronaut not found")
    v = Vital(**body.model_dump(mode="python"))
    v.type = body.type.value
    v.source = body.source.value
    db.add(v)
    db.commit()
    return v


@router.get("/{astronaut_id}", response_model=list[VitalOut])
def get_vitals(
    astronaut_id: int,
    range: str = "7d",
    type: Optional[VitalType] = None,
    db: Session = Depends(get_db),
):
    if not db.get(Astronaut, astronaut_id):
        raise HTTPException(404, "astronaut not found")
    q = select(Vital).where(
        Vital.astronaut_id == astronaut_id, Vital.timestamp >= range_start(range)
    )
    if type:
        q = q.where(Vital.type == type.value)
    return db.scalars(q.order_by(Vital.timestamp)).all()
