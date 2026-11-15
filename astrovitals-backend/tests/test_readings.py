import json
import time

import pytest
from sqlalchemy import func, select

from app.models import Reading
from tests.helpers import now_ms, reading


def count(db):
    db.expire_all()
    return db.scalar(select(func.count()).select_from(Reading))


# ---------------------------------------------------------------- saving ----
def test_single_reading_saved_and_returned_in_the_apps_shape(client, db):
    r = client.post("/v1/readings", json=reading())
    assert r.status_code == 200
    assert r.json()["accepted"] == 1 and r.json()["results"] == [{"id": "r_1", "status": "accepted"}]
    got = client.get("/v1/readings").json()
    assert got == [{**reading(time=got[0]["time"])}]            # identical to what was sent
    assert set(got[0]) == {"id", "seq", "crew_id", "metric", "field", "value", "unit", "time", "source",
                           "quality", "context"}


def test_list_and_wrapped_bodies(client, db):
    assert client.post("/v1/readings", json=[reading(id="a"), reading(id="b")]).json()["accepted"] == 2
    assert client.post("/v1/readings", json={"readings": [reading(id="c")]}).json()["accepted"] == 1
    assert count(db) == 3


def test_same_reading_sent_twice_is_saved_once(client, db):
    assert client.post("/v1/readings", json=reading()).json()["accepted"] == 1
    again = client.post("/v1/readings", json=reading())
    assert again.status_code == 200
    assert again.json()["duplicates"] == 1 and again.json()["accepted"] == 0
    assert count(db) == 1


def test_resending_a_whole_batch_adds_nothing(client, db):
    batch = [reading(id=f"r{i}", value=60 + i) for i in range(5)]
    client.post("/v1/readings", json=batch)
    rep = client.post("/v1/readings", json=batch).json()
    assert rep["duplicates"] == 5 and rep["accepted"] == 0 and count(db) == 5


def test_duplicate_inside_one_batch(client, db):
    rep = client.post("/v1/readings", json=[reading(id="x"), reading(id="x")]).json()
    assert (rep["accepted"], rep["duplicates"]) == (1, 1) and count(db) == 1


def test_one_bad_item_does_not_block_the_batch(client, db):
    rep = client.post("/v1/readings", json=[reading(id="ok1"), reading(id="bad", value=999), reading(id="ok2")])
    assert rep.status_code == 200
    j = rep.json()
    assert (j["accepted"], j["rejected"]) == (2, 1)
    assert [x["status"] for x in j["results"]] == ["accepted", "rejected", "accepted"]
    assert count(db) == 2


def test_everything_rejected_gives_422_and_stores_nothing(client, db):
    r = client.post("/v1/readings", json=[reading(value=999)])
    assert r.status_code == 422 and r.json()["rejected"] == 1 and count(db) == 0


# ------------------------------------------------------------ validation ----
BAD = [
    (dict(value=300), "Heart rate must be between 25 and 220"),
    (dict(value=10), "Heart rate must be between 25 and 220"),
    (dict(value="70"), "value must be a number"),
    (dict(value=True), "value must be a number"),
    (dict(value=None), "value must be a number"),
    (dict(metric="pulse"), "unknown metric"),
    (dict(unit="bps"), "unit for heart_rate must be 'bpm'"),
    (dict(field="pulse"), "field for heart_rate must be"),
    (dict(time=int(time.time())), "looks like seconds"),
    (dict(time=now_ms() + 3_600_000), "in the future"),
    (dict(time=1000), "looks like seconds"),
    (dict(time=946_684_800_000 - 5), "too far in the past"),
    (dict(time="today"), "UTC epoch milliseconds"),
    (dict(quality="great"), "quality must be"),
    (dict(source={"kind": "satellite"}), "source.kind"),
    (dict(source="manual"), "source must be an object"),
    (dict(crew_id="c999"), "unknown crew_id"),
    (dict(id=""), "id is required"),
    (dict(id=None), "id is required"),
    (dict(seq=-1), "seq must be"),
    (dict(context="x"), "context must be an object"),
]


@pytest.mark.parametrize("change,message", BAD)
def test_invalid_readings_are_rejected_with_a_clear_reason(client, db, change, message):
    r = client.post("/v1/readings", json=reading(**change))
    assert r.status_code == 422
    errors = r.json()["results"][0]["errors"]
    assert any(message in e for e in errors), errors
    assert count(db) == 0


def test_non_object_items_and_bad_bodies(client):
    assert client.post("/v1/readings", json=[5, "x"]).status_code == 422
    assert client.post("/v1/readings", json=5).status_code == 422
    assert client.post("/v1/readings", json=[]).status_code == 422
    assert client.post("/v1/readings", content="not json", headers={"content-type": "application/json"}).status_code == 422
    assert client.post("/v1/readings", json=[reading(id=f"r{i}") for i in range(501)]).status_code == 422


def test_unit_spelling_variants_are_accepted(client):
    spec = [("cabin_humidity", "%RH", 45), ("cabin_humidity", "% RH", 45),
            ("respiratory_rate", "/min", 14), ("respiratory_rate", "/ min", 14)]
    for i, (metric, unit, v) in enumerate(spec):
        r = client.post("/v1/readings", json=reading(id=f"u{i}", metric=metric, field=metric, unit=unit, value=v))
        assert r.status_code == 200, (metric, unit, r.json())


def test_blood_pressure_as_the_app_sends_it(client):
    bp = dict(metric="blood_pressure", field="blood_pressure", unit="mmHg", value=118)
    assert client.post("/v1/readings", json=reading(id="bp1", **bp)).status_code == 200   # systolic only


def test_blood_pressure_with_diastolic_in_context(client):
    bp = dict(metric="blood_pressure", field="blood_pressure", unit="mmHg", value=118)
    ok = reading(id="bp2", context={"mission_day": 30, "diastolic": 76}, **bp)
    assert client.post("/v1/readings", json=ok).status_code == 200
    for dia, msg in [(130, "Diastolic must be lower than systolic"), (500, "must be between"), ("x", "must be a number")]:
        r = client.post("/v1/readings", json=reading(id=f"bp_{dia}", context={"diastolic": dia}, **bp))
        assert r.status_code == 422 and any(msg in e for e in r.json()["results"][0]["errors"])


def test_radiation_dose_rate_and_cumulative_dose_are_different_metrics(client):
    rate = reading(id="d1", metric="dose_rate", field="radiation_dose_msv", unit="mSv/day", value=0.7)
    cum = reading(id="d2", metric="cumulative_dose", field="radiation_dose_msv", unit="mSv", value=12.4)
    assert client.post("/v1/readings", json=[rate, cum]).json()["accepted"] == 2
    too_high = dict(rate, id="d3", value=60)                       # daily dose limit is 50 mSv
    assert client.post("/v1/readings", json=too_high).status_code == 422
    negative = dict(cum, id="d4", value=-1)
    assert client.post("/v1/readings", json=negative).status_code == 422
    wrong_unit = dict(cum, id="d5", unit="mSv/day")                # a total cannot be a rate
    assert client.post("/v1/readings", json=wrong_unit).status_code == 422


def test_mood_uses_its_zone_range(client):
    mood = dict(metric="mood_daily", field="mood_daily", unit="/ 5")
    assert client.post("/v1/readings", json=reading(id="m1", value=4, **mood)).status_code == 200
    assert client.post("/v1/readings", json=reading(id="m2", value=9, **mood)).status_code == 422
    assert client.post("/v1/readings", json=reading(id="m3", value=0, **mood)).status_code == 422


def test_every_metric_the_app_posts_is_accepted(client):
    """Build the payloads from what app_state.dart's _readingDef() really sends."""
    rules = json.load(open("app/rules/rules_data.json", encoding="utf-8"))
    batch = []
    for series, d in rules["reading_defs"].items():
        lim = rules["limits"].get(series)
        value = rules["baselines"].get(series, (lim["min"] + lim["max"]) / 2 if lim else 3)
        batch.append(reading(id=f"p_{series}", metric=d["metric"], field=d["field"], unit=d["unit"], value=value))
    rep = client.post("/v1/readings", json=batch).json()
    assert rep["rejected"] == 0, rep
    assert rep["accepted"] == len(rules["reading_defs"]) == 15


# --------------------------------------------------------------- history ----
def seed(client):
    t = now_ms() - 10_000_000
    rows = [reading(id=f"h{i}", value=60 + i, time=t + i * 1000) for i in range(6)]
    rows.append(reading(id="g1", metric="blood_glucose", field="blood_glucose", unit="mg/dL", value=90, time=t + 500))
    client.post("/v1/readings", json=rows)
    return t


def test_history_is_oldest_first_and_filterable(client):
    t = seed(client)
    allr = client.get("/v1/readings").json()
    assert [r["time"] for r in allr] == sorted(r["time"] for r in allr) and len(allr) == 7
    hr = client.get("/v1/readings?metric=heart_rate").json()
    assert [r["value"] for r in hr] == [60, 61, 62, 63, 64, 65]
    window = client.get(f"/v1/readings?metric=heart_rate&from={t + 2000}&to={t + 4000}").json()
    assert [r["value"] for r in window] == [62, 63, 64]
    assert [r["value"] for r in client.get("/v1/readings?metric=heart_rate&order=desc&limit=2").json()] == [65, 64]


def test_history_errors(client):
    assert client.get("/v1/readings?crew_id=nobody").status_code == 404
    assert client.get("/v1/readings?metric=pulse").status_code == 422
    assert client.get("/v1/readings?limit=0").status_code == 422
    assert client.get("/v1/readings?order=sideways").status_code == 422
    assert client.get("/v1/readings").json() == []


def test_history_separates_crew(client, db):
    from app.models import Crew
    db.add(Crew(id="c2", name="Other", role="", mission_id="m_astrovitals_demo"))
    db.commit()
    client.post("/v1/readings", json=[reading(id="a"), reading(id="b", crew_id="c2")])
    assert [r["id"] for r in client.get("/v1/readings?crew_id=c2").json()] == ["b"]
    assert [r["id"] for r in client.get("/v1/readings").json()] == ["a"]
