from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Astronaut
from ..schemas import AstronautCreate, AstronautOut

router = APIRouter(prefix="/astronauts", tags=["astronauts"])


@router.post("", response_model=AstronautOut, status_code=201)
def create_astronaut(body: AstronautCreate, db: Session = Depends(get_db)):
    a = Astronaut(**body.model_dump())
    db.add(a)
    db.commit()
    return a


@router.get("", response_model=list[AstronautOut])
def list_astronauts(db: Session = Depends(get_db)):
    return db.scalars(select(Astronaut).order_by(Astronaut.id)).all()


@router.get("/{astronaut_id}", response_model=AstronautOut)
def get_astronaut(astronaut_id: int, db: Session = Depends(get_db)):
    a = db.get(Astronaut, astronaut_id)
    if not a:
        raise HTTPException(404, "astronaut not found")
    return a
