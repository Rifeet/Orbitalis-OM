from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import JSON, Float, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base, UTCDateTime


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Astronaut(Base):
    __tablename__ = "astronauts"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    age: Mapped[int] = mapped_column(Integer)
    sex: Mapped[str] = mapped_column(String(10))
    # pre-mission baseline, e.g. {"heart_rate": 62, "wbc": 6.5, ...}
    baseline_json: Mapped[dict] = mapped_column(JSON, default=dict)
    career_dose_msv: Mapped[float] = mapped_column(Float, default=0.0)  # prior missions


class Vital(Base):
    __tablename__ = "vitals"
    __table_args__ = (Index("ix_vitals_astro_time", "astronaut_id", "timestamp"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    astronaut_id: Mapped[int] = mapped_column(ForeignKey("astronauts.id"))
    timestamp: Mapped[datetime] = mapped_column(UTCDateTime)
    type: Mapped[str] = mapped_column(String(30))
    value: Mapped[float] = mapped_column(Float)
    unit: Mapped[str] = mapped_column(String(20))
    source: Mapped[str] = mapped_column(String(20), default="measured")


class RadiationReading(Base):
    __tablename__ = "radiation_readings"
    __table_args__ = (Index("ix_rad_device_time", "device_id", "timestamp"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    device_id: Mapped[str] = mapped_column(String(50))
    # set for personal dosimeters (CAD); null for area monitors (HERA, REM)
    astronaut_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("astronauts.id"), nullable=True
    )
    timestamp: Mapped[datetime] = mapped_column(UTCDateTime)
    dose_rate: Mapped[float] = mapped_column(Float)
    unit: Mapped[str] = mapped_column(String(20))
    dose_type: Mapped[str] = mapped_column(String(20))  # absorbed | equivalent | effective
    location: Mapped[str] = mapped_column(String(50), default="unknown")
    source: Mapped[str] = mapped_column(String(20), default="measured")


class RadiationEvent(Base):
    __tablename__ = "radiation_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    event_type: Mapped[str] = mapped_column(String(20))  # e.g. "SPE"
    start_time: Mapped[datetime] = mapped_column(UTCDateTime)
    end_time: Mapped[Optional[datetime]] = mapped_column(UTCDateTime, nullable=True)
    severity: Mapped[str] = mapped_column(String(20), default="unknown")


class Symptom(Base):
    __tablename__ = "symptoms"

    id: Mapped[int] = mapped_column(primary_key=True)
    astronaut_id: Mapped[int] = mapped_column(ForeignKey("astronauts.id"))
    timestamp: Mapped[datetime] = mapped_column(UTCDateTime)
    symptom: Mapped[str] = mapped_column(String(50))  # nausea, vomiting, fatigue...
    severity: Mapped[int] = mapped_column(Integer)  # 1-5


class Assessment(Base):
    __tablename__ = "assessments"

    id: Mapped[int] = mapped_column(primary_key=True)
    astronaut_id: Mapped[int] = mapped_column(ForeignKey("astronauts.id"))
    timestamp: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    acute_status: Mapped[str] = mapped_column(String(20))
    cumulative_status: Mapped[str] = mapped_column(String(20))
    reasons_json: Mapped[list] = mapped_column(JSON, default=list)
    rule_version: Mapped[str] = mapped_column(String(20))


class Alert(Base):
    __tablename__ = "alerts"

    id: Mapped[int] = mapped_column(primary_key=True)
    astronaut_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("astronauts.id"), nullable=True
    )
    timestamp: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    level: Mapped[str] = mapped_column(String(20))  # info | yellow | red
    message: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="open")
