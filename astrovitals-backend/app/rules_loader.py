"""Load the app's rules (app/rules/rules_data.json) into the database.

Safe to run any number of times: it replaces the rule tables with the file's content.
It never touches readings, entries, alerts or users.

    python -m app.rules_loader
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Optional

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from .database import Base, SessionLocal, engine
from .models import (Baseline, Crew, DeviceSpec, EnvProfile, FieldDef, InputLimit, MetricDef, Mission, RuleMeta,
                     ZoneBand, ZoneTable)

RULES_PATH = Path(__file__).parent / "rules" / "rules_data.json"

# Contract identities (api_contract.dart: ContractIdentity)
DEMO_CREW_ID = "c1"
DEMO_MISSION_ID = "m_astrovitals_demo"


def read_rules_file(path: Path = RULES_PATH) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def rules_loaded(db: Session) -> bool:
    return (db.scalar(select(func.count()).select_from(EnvProfile)) or 0) > 0


def load_rules(db: Session, data: Optional[dict] = None) -> dict:
    """Replace all rule tables with `data` (default: the JSON file). Returns row counts."""
    data = data or read_rules_file()

    # children first (zone_bands references zone_tables)
    for model in (ZoneBand, ZoneTable, MetricDef, FieldDef, InputLimit, Baseline, DeviceSpec, RuleMeta):
        db.execute(delete(model))
    # env_profiles may be referenced by missions, so update in place instead of deleting
    keep = {e["key"] for e in data["environments"]}
    for e in data["environments"]:
        row = db.get(EnvProfile, e["key"])
        if row is None:
            db.add(EnvProfile(**e))
        else:
            for k, v in e.items():
                setattr(row, k, v)
    for row in db.scalars(select(EnvProfile)).all():
        if row.key not in keep and not db.scalar(select(Mission).where(Mission.env_key == row.key)):
            db.delete(row)

    db.add_all(MetricDef(**{k: v for k, v in m.items() if k != "extra"}) for m in data["metrics"])
    db.add_all(FieldDef(**f) for f in data["fields"])
    for key, z in data["zones"].items():
        bar = z["bar"] or [None, None]
        db.add(ZoneTable(series_key=key, bar_min=bar[0], bar_max=bar[1]))
    db.flush()
    for key, z in data["zones"].items():
        db.add_all(ZoneBand(series_key=key, band_order=i, from_value=b[0], to_value=b[1], level=b[2])
                   for i, b in enumerate(z["bands"]))
    db.add_all(InputLimit(series_key=k, min_value=v["min"], max_value=v["max"], label=v["label"], step=v["step"])
               for k, v in data["limits"].items())
    db.add_all(Baseline(series_key=k, value=v) for k, v in data["baselines"].items())
    db.add_all(DeviceSpec(series_key=k, device=v["device"], route=v["route"], kind=v["kind"], age_min=v["age_min"])
               for k, v in data["devices"].items())
    meta = dict(data["meta"])
    meta["source_sha256"] = data["source"]["sha256"]
    db.add_all(RuleMeta(key=k, value_json=v) for k, v in meta.items())

    ensure_demo_identity(db)
    db.commit()
    return rule_counts(db)


def ensure_demo_identity(db: Session) -> None:
    """The app's fixed demo identities (crew 'c1', mission 'm_astrovitals_demo')."""
    db.flush()
    if db.get(Mission, DEMO_MISSION_ID) is None:
        db.add(Mission(id=DEMO_MISSION_ID, name="AstroVitals demo mission", env_key="iss", total_days=180))
        db.flush()
    if db.get(Crew, DEMO_CREW_ID) is None:
        db.add(Crew(id=DEMO_CREW_ID, name="Lena Ortiz", role="Flight engineer", mission_id=DEMO_MISSION_ID))


def rule_counts(db: Session) -> dict:
    count = lambda m: db.scalar(select(func.count()).select_from(m))  # noqa: E731
    return {"environments": count(EnvProfile), "metrics": count(MetricDef), "zone_tables": count(ZoneTable),
            "zone_bands": count(ZoneBand), "fields": count(FieldDef), "limits": count(InputLimit), "baselines": count(Baseline),
            "devices": count(DeviceSpec), "meta": count(RuleMeta)}


if __name__ == "__main__":
    Base.metadata.create_all(engine)
    with SessionLocal() as session:
        print("Rules loaded:", load_rules(session))
