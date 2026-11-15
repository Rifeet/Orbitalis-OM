import pytest
from sqlalchemy import func, select

from app.models import AnomalyResult
from sim.generate import generate
from sim.load import ensure_crew, load_dataset, post_all
from sim.replay import DEFAULT_END, DAY

from app.anomaly import LEARN_DAYS


@pytest.fixture()
def loaded(client, db):
    data = generate(DEFAULT_END, days=40, seed=7)
    load_dataset(client, data, reset=True)
    return data


def test_model_waits_until_it_has_learned(client, db):
    data = generate(DEFAULT_END, days=40, seed=7)
    t0 = min(r["time"] for r in data["readings"])
    early = [r for r in data["readings"] if r["time"] < t0 + 15 * DAY]
    ensure_crew(db)
    assert post_all(client, "/v1/readings", early)["rejected"] == 0
    out = client.post("/v1/anomalies/run").json()
    assert out["rows_written"] == 0
    assert all(c["status"] == "learning" for c in out["crew"].values())


def test_early_warning_for_the_drift_and_quiet_for_the_normal_astronaut(client, loaded):
    out = client.post("/v1/anomalies/run").json()
    assert out["rows_written"] == 4 * (40 - LEARN_DAYS)
    ov = {c["crew_id"]: c["summary"] for c in client.get("/v1/anomalies/overview").json()["crew"]}
    assert ov["c2"]["max_rule_level"] == 0                       # the app's rules never alerted
    assert ov["c2"]["first_flag_day"] is not None
    assert 0 < ov["c2"]["first_flag_day"] - ov["c2"]["first_true_day"] <= 9
    assert ov["c2"]["false_alarm_days"] == 0
    assert ov["c1"]["flagged_days"] <= 2                         # false alarms stay rare
    r = client.get("/v1/anomalies", params={"crew_id": "c2", "flagged_only": True}).json()
    assert r and "consistent with" in r[0]["reason"]


def test_run_is_repeatable(client, loaded, db):
    client.post("/v1/anomalies/run")
    n = db.scalar(select(func.count()).select_from(AnomalyResult))
    client.post("/v1/anomalies/run")
    assert db.scalar(select(func.count()).select_from(AnomalyResult)) == n
