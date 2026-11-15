"""Seed the database with 30 days of SIMULATED data for 4 astronauts.

    python -m app.seed --reset

Everything is tagged source="simulated". Values are plausible but invented:
they exist to develop and demo the software, not to represent real crew data.
"""
import argparse
import random
from datetime import datetime, timedelta, timezone

from .database import Base, SessionLocal, engine
from .models import Astronaut, RadiationEvent, RadiationReading, Vital

DAYS = 30
CREW = [
    ("Astronaut A", 41, "female", 0.0),
    ("Astronaut B", 46, "male", 120.0),
    ("Astronaut C", 38, "male", 0.0),
    ("Astronaut D", 44, "female", 210.0),
]


def make_baseline(rng: random.Random) -> dict:
    return {
        "heart_rate": round(rng.uniform(55, 70), 1),
        "bp_systolic": round(rng.uniform(105, 125), 1),
        "bp_diastolic": round(rng.uniform(65, 80), 1),
        "glucose": round(rng.uniform(78, 98), 1),
        "temperature": round(rng.uniform(36.4, 36.9), 2),
        "sleep_hours": round(rng.uniform(7.0, 8.0), 1),
        "mood": 4.0,
        "wbc": round(rng.uniform(5.0, 8.0), 2),
    }


def seed(reset: bool = False, rng_seed: int = 42) -> None:
    rng = random.Random(rng_seed)
    if reset:
        Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
    start = now - timedelta(days=DAYS)

    with SessionLocal() as db:
        if db.query(Astronaut).count() and not reset:
            print("Database already has data. Use --reset to re-seed.")
            return

        astronauts = []
        for name, age, sex, career in CREW:
            a = Astronaut(
                name=name, age=age, sex=sex,
                baseline_json=make_baseline(rng), career_dose_msv=career,
            )
            db.add(a)
            astronauts.append(a)
        db.flush()

        vitals, readings = [], []
        for a in astronauts:
            b = a.baseline_json
            for d in range(DAYS):
                ts = start + timedelta(days=d, hours=8)
                for t, noise, lo, hi in [
                    ("heart_rate", 3, 30, 200), ("bp_systolic", 5, 70, 220),
                    ("bp_diastolic", 4, 40, 140), ("glucose", 6, 40, 400),
                    ("temperature", 0.15, 35, 41), ("sleep_hours", 0.7, 3, 10),
                ]:
                    val = min(hi, max(lo, rng.gauss(b[t], noise)))
                    unit = {"heart_rate": "bpm", "bp_systolic": "mmHg", "bp_diastolic": "mmHg",
                            "glucose": "mg/dL", "temperature": "C", "sleep_hours": "h"}[t]
                    vitals.append(Vital(astronaut_id=a.id, timestamp=ts, type=t,
                                        value=round(val, 2), unit=unit, source="simulated"))
                mood = min(5, max(1, round(rng.gauss(b["mood"], 0.6))))
                vitals.append(Vital(astronaut_id=a.id, timestamp=ts, type="mood",
                                    value=mood, unit="score_1_5", source="simulated"))
                if d % 7 == 0:  # weekly blood panel
                    vitals.append(Vital(astronaut_id=a.id, timestamp=ts, type="wbc",
                                        value=round(max(1, rng.gauss(b["wbc"], 0.5)), 2),
                                        unit="10^9/L", source="simulated"))

            # personal dosimeter (CAD-like), hourly, ~0.4-0.5 mSv/day ISS-like
            for h in range(DAYS * 24):
                ts = start + timedelta(hours=h)
                readings.append(RadiationReading(
                    device_id=f"CAD-{a.id}", astronaut_id=a.id, timestamp=ts,
                    dose_rate=round(max(0, rng.gauss(18, 2.5)), 3), unit="uSv/h",
                    dose_type="effective", location="crew_quarters", source="simulated"))

        # area monitors, hourly, absorbed dose rate with an occasional bump
        for dev, loc, base in [("HERA-1", "node_2", 14.0), ("REM-1", "lab_module", 12.0)]:
            for h in range(DAYS * 24):
                ts = start + timedelta(hours=h)
                bump = 6 if (h % 95) in (0, 1, 2) else 0  # crude passes through the radiation belt
                readings.append(RadiationReading(
                    device_id=dev, astronaut_id=None, timestamp=ts,
                    dose_rate=round(max(0, rng.gauss(base + bump, 1.5)), 3), unit="uGy/h",
                    dose_type="absorbed", location=loc, source="simulated"))

        db.add_all(vitals)
        db.add_all(readings)
        db.add(RadiationEvent(event_type="SPE", severity="none",
                              start_time=start - timedelta(days=60),
                              end_time=start - timedelta(days=59)))  # historical placeholder
        db.commit()
        print(f"Seeded {len(astronauts)} astronauts, {len(vitals)} vitals, {len(readings)} radiation readings.")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--reset", action="store_true", help="drop all tables first")
    seed(reset=p.parse_args().reset)
