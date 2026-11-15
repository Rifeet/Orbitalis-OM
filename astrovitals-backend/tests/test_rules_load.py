import json
import os
import subprocess
import sys
from pathlib import Path

import pytest
from sqlalchemy import func, select

from app.models import (Baseline, Crew, DeviceSpec, EnvProfile, InputLimit, MetricDef, Mission, RuleMeta,
                        ZoneBand, ZoneTable)
from app.rules_loader import load_rules, rule_counts, rules_loaded

ROOT = Path(__file__).resolve().parent.parent


def bands(db, key):
    rows = db.scalars(select(ZoneBand).where(ZoneBand.series_key == key).order_by(ZoneBand.band_order)).all()
    return [[r.from_value, r.to_value, r.level] for r in rows]


def test_counts_match_the_app(db):
    assert rule_counts(db) == {"environments": 4, "metrics": 16, "zone_tables": 16, "zone_bands": 110,
                               "fields": 40, "limits": 15, "baselines": 9, "devices": 15, "meta": 8}


def test_heart_rate_zones_exactly_as_in_the_app(db):
    assert bands(db, "hr") == [[30, 35, 4], [35, 40, 3], [40, 45, 2], [45, 50, 1], [50, 90, 0],
                               [90, 100, 1], [100, 110, 2], [110, 130, 3], [130, 200, 4]]


def test_other_zone_spot_checks(db):
    assert bands(db, "spo2")[0] == [70, 90, 5]            # below 90% = emergency level
    assert bands(db, "mood") == [[1, 2, 3], [2, 3, 2], [3, 4, 1], [4, 5.1, 0]]
    assert bands(db, "co2")[-1] == [10000, 40000, 5]
    assert bands(db, "temp")[3] == [36.1, 37.3, 0]
    z = db.get(ZoneTable, "hr")
    assert (z.bar_min, z.bar_max) == (35, 130)
    z = db.get(ZoneTable, "dia")
    assert (z.bar_min, z.bar_max) == (None, None)


def test_every_zone_table_is_contiguous_and_sorted(db):
    for t in db.scalars(select(ZoneTable)).all():
        b = bands(db, t.series_key)
        assert b, t.series_key
        for prev, nxt in zip(b, b[1:]):
            assert prev[1] == nxt[0], f"{t.series_key}: gap/overlap between {prev} and {nxt}"
        assert all(x[0] < x[1] and 0 <= x[2] <= 5 for x in b)


def test_environments(db):
    envs = {e.key: e for e in db.scalars(select(EnvProfile)).all()}
    assert set(envs) == {"iss", "moon", "mars_transit", "mars_surface"}
    iss = envs["iss"]
    assert (iss.dose_rate_msv_day, iss.limit_msv, iss.delay_min, iss.total_days) == (0.6, 50.0, 0.0, 180)
    assert envs["moon"].delay_min == 0.02 and envs["moon"].limit_msv == 100.0
    assert envs["mars_transit"].delay_min == 20.0 and envs["mars_transit"].limit_msv == 250.0
    assert envs["mars_transit"].dose_rate_msv_day == 1.8
    assert envs["mars_surface"].gravity == "0.38 g"


def test_metric_names_one_metric_three_names(db):
    hr = db.get(MetricDef, "hr")
    assert (hr.api_metric, hr.field, hr.unit) == ("heart_rate", "heart_rate", "bpm")
    sleep = db.get(MetricDef, "sleep")
    assert (sleep.api_metric, sleep.field) == ("sleep_hours", "sleep_hours_wakeups")
    rad = db.get(MetricDef, "rad")
    assert (rad.api_metric, rad.unit, rad.series_key) == ("cumulative_dose", "mSv", "radTotal")
    assert db.get(MetricDef, "bp").series_key == "sys"
    assert {m.id for m in db.scalars(select(MetricDef)).all()} == {
        "hr", "bp", "spo2", "glu", "temp", "sleep", "mood", "ex", "rad", "co2", "hum", "ctemp", "noise", "resp", "mass",
        "dose_rate"}   # dose_rate: posted by the app, missing from its own registry
    dr = db.get(MetricDef, "dose_rate")
    assert (dr.api_metric, dr.unit, dr.series_key) == ("dose_rate", "mSv/day", "rad")


def test_input_limits_baselines_devices(db):
    hr = db.get(InputLimit, "hr")
    assert (hr.min_value, hr.max_value, hr.label) == (25, 220, "Heart rate")
    assert db.get(InputLimit, "temp").step == 0.1
    assert db.get(InputLimit, "rad").max_value == 50
    assert db.get(Baseline, "hr").value == 68 and db.get(Baseline, "mass").value == 74.0
    assert db.get(Baseline, "temp").value == 36.6
    d = db.get(DeviceSpec, "rad")
    assert (d.device, d.kind, d.age_min) == ("Crew Active Dosimeter", "direct", 55)
    assert db.get(DeviceSpec, "glu").kind == "partial"


def test_meta_values(db):
    meta = {m.key: m.value_json for m in db.scalars(select(RuleMeta)).all()}
    assert meta["plan_bed"] == "22:30" and meta["plan_up"] == "06:30"
    assert meta["health_score"] == [100, 85, 65, 40, 20, 0]
    assert meta["health_cap"] == [100, 89, 79, 64, 49, 34]
    assert meta["tier_names"][0] == "Normal" and meta["tier_names"][5] == "Emergency"
    assert meta["radiation_rate_bands"] == [[0, 1.5, 0], [1.5, 3, 2], [3, 6, 3], [6, None, 4]]
    assert len(meta["source_sha256"]) == 64
    assert meta["unsent_series"] == ["dia"]


def test_loading_twice_is_safe_and_changes_nothing(db):
    before = rule_counts(db)
    load_rules(db)
    load_rules(db)
    assert rule_counts(db) == before
    assert db.scalar(select(func.count()).select_from(Mission)) == 1
    assert db.scalar(select(func.count()).select_from(Crew)) == 1


def test_demo_identity_exists(db):
    assert db.get(Crew, "c1").name == "Lena Ortiz"
    assert db.get(Mission, "m_astrovitals_demo").env_key == "iss"


def test_reload_changes_a_value_without_touching_missions(db):
    data = json.loads((ROOT / "app/rules/rules_data.json").read_text(encoding="utf-8"))
    data["environments"][0]["limit_msv"] = 77.0
    load_rules(db, data)
    assert db.get(EnvProfile, "iss").limit_msv == 77.0
    assert db.get(Mission, "m_astrovitals_demo") is not None


def test_server_loads_rules_on_first_start(client):
    assert client.get("/health").json() == {"status": "ok", "rules_loaded": True}


def test_rules_loaded_false_on_empty_database():
    from app.database import SessionLocal, Base, engine
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with SessionLocal() as s:
        assert rules_loaded(s) is False


@pytest.mark.skipif(not os.getenv("FLUTTER_LIB"), reason="set FLUTTER_LIB=path/to/lib to check drift against the app")
def test_json_is_not_stale_compared_to_the_dart_source():
    r = subprocess.run([sys.executable, str(ROOT / "tools/extract_rules.py"), os.environ["FLUTTER_LIB"], "--check"],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
