from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class Source(str, Enum):
    measured = "measured"
    model = "model"
    simulated = "simulated"


# ---- Vitals ---------------------------------------------------------------

class VitalType(str, Enum):
    heart_rate = "heart_rate"
    bp_systolic = "bp_systolic"
    bp_diastolic = "bp_diastolic"
    glucose = "glucose"
    temperature = "temperature"
    sleep_hours = "sleep_hours"
    mood = "mood"
    wbc = "wbc"


# type -> (expected unit, plausible min, plausible max)
# Plausibility ranges only reject impossible input (typos, wrong units).
# They are NOT clinical thresholds; those live in the rule engine.
VITAL_SPECS = {
    VitalType.heart_rate: ("bpm", 20, 250),
    VitalType.bp_systolic: ("mmHg", 50, 260),
    VitalType.bp_diastolic: ("mmHg", 30, 160),
    VitalType.glucose: ("mg/dL", 20, 600),
    VitalType.temperature: ("C", 30, 43),
    VitalType.sleep_hours: ("h", 0, 24),
    VitalType.mood: ("score_1_5", 1, 5),
    VitalType.wbc: ("10^9/L", 0, 100),
}


def to_utc(v: datetime) -> datetime:
    if v.tzinfo is None:
        return v.replace(tzinfo=timezone.utc)
    return v.astimezone(timezone.utc)


def not_in_future(v: datetime) -> datetime:
    v = to_utc(v)
    if v > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise ValueError("timestamp is in the future")
    return v


class AstronautCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    age: int = Field(ge=18, le=80)
    sex: str = Field(pattern="^(female|male|other)$")
    baseline_json: dict[str, float] = Field(default_factory=dict)
    career_dose_msv: float = Field(default=0.0, ge=0)


class AstronautOut(AstronautCreate):
    model_config = ConfigDict(from_attributes=True)
    id: int


class VitalCreate(BaseModel):
    astronaut_id: int
    timestamp: Optional[datetime] = None
    type: VitalType
    value: float
    unit: Optional[str] = None  # defaults to the expected unit
    source: Source = Source.measured

    @field_validator("timestamp")
    @classmethod
    def _ts(cls, v):
        return not_in_future(v) if v is not None else None

    @model_validator(mode="after")
    def _check(self):
        unit, lo, hi = VITAL_SPECS[self.type]
        if self.unit is None:
            self.unit = unit
        if self.unit != unit:
            raise ValueError(f"{self.type.value} must be in '{unit}', got '{self.unit}'")
        if not (lo <= self.value <= hi):
            raise ValueError(f"{self.type.value}={self.value} {unit} is outside plausible range {lo}-{hi}")
        if self.timestamp is None:
            self.timestamp = datetime.now(timezone.utc)
        return self


class VitalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    astronaut_id: int
    timestamp: datetime
    type: str
    value: float
    unit: str
    source: str


# ---- Radiation ------------------------------------------------------------

class DoseType(str, Enum):
    absorbed = "absorbed"      # Gy
    equivalent = "equivalent"  # Sv
    effective = "effective"    # Sv


class RadUnit(str, Enum):
    uGy_h = "uGy/h"
    mGy_day = "mGy/day"
    uSv_h = "uSv/h"
    mSv_day = "mSv/day"


# Gy-based units are absorbed dose; Sv-based units are equivalent/effective.
# We never let these be mixed (they are different physical quantities).
GY_UNITS = {RadUnit.uGy_h, RadUnit.mGy_day}


class RadiationCreate(BaseModel):
    device_id: str = Field(min_length=1, max_length=50)
    astronaut_id: Optional[int] = None
    timestamp: Optional[datetime] = None
    dose_rate: float = Field(ge=0, le=1_000_000)
    unit: RadUnit
    dose_type: Optional[DoseType] = None  # derived from unit if omitted
    location: str = "unknown"
    source: Source = Source.measured

    @field_validator("timestamp")
    @classmethod
    def _ts(cls, v):
        return not_in_future(v) if v is not None else None

    @model_validator(mode="after")
    def _check(self):
        is_gy = self.unit in GY_UNITS
        if self.dose_type is None:
            self.dose_type = DoseType.absorbed if is_gy else DoseType.effective
        if is_gy and self.dose_type != DoseType.absorbed:
            raise ValueError("Gy-based units must have dose_type 'absorbed'")
        if not is_gy and self.dose_type == DoseType.absorbed:
            raise ValueError("Sv-based units must have dose_type 'equivalent' or 'effective'")
        if self.timestamp is None:
            self.timestamp = datetime.now(timezone.utc)
        return self


class RadiationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    device_id: str
    astronaut_id: Optional[int]
    timestamp: datetime
    dose_rate: float
    unit: str
    dose_type: str
    location: str
    source: str
