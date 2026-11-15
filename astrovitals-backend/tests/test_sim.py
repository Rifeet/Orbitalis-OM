import csv
import io
import json
import time
from collections import Counter

import pytest
from sqlalchemy import func, select

from app.models import Alert, AnomalyLabel, Crew, Entry, Reading
from sim.generate import CREW, MIN_MS, HOUR_MS, csv_rows, generate
from sim.load import export, load_dataset, main as sim_main

DAY = 86_400_000


@pytest.fixture(scope="module")
def end():
    return int(time.time() * 1000) - 120_000


@pytest.fixture(scope="module")
def data(end):
    return generate(end)


def rows(data, crew, metric=None):
    return [r for r in data["readings"] if r["crew_id"] == crew and (metric is None or r["metric"] == metric)]


def lvls(data, crew, metric=None):
    return [data["levels"][r["id"]] for r in rows(data, crew, metric)]


# ------------------------------------------------------------------ basics
def test_is_deterministic_and_seed_changes_it(end):
    assert generate(end) == generate(end)
    assert generate(end, seed=8)["readings"] != generate(end)["readings"]


def test_ids_unique_and_marked_simulated(data):
    ids = [r["id"] for r in data["readings"]]
    assert len(ids) == len(set(ids)) and all(i.startswith("sim_") for i in ids)
    assert all(r["context"]["simulated"] is True for r in data["readings"])


def test_needs_at_least_30_days(end):
    with pytest.raises(ValueError):
        generate(end, days=20)


def test_longer_history_keeps_the_scenarios_at_the_end(end):
    d = generate(end, days=60)
    assert len(rows(d, "c1", "heart_rate")) == 60
    t = d["truth"]["c2"]
    assert t["max_rule_level_before_window"] == 0 and t["window_start_ms"] == end - 19 * DAY


def test_no_reading_in_the_future(data, end):
    assert max(r["time"] for r in data["readings"]) <= end


# ------------------------------------------------------------------ c1: normal
def test_c1_has_a_few_harmless_watch_blips_and_nothing_worse(data):
    L = lvls(data, "c1")
    assert max(L) == 1 and 6 <= L.count(1) <= 10
    assert not [a for a in data["alerts"] if a["crew_id"] == "c1"]


def test_c1_blips_are_isolated_and_all_labelled_as_not_anomalies(data):
    blips = [r for r in rows(data, "c1") if data["levels"][r["id"]] == 1]
    labels = [l for l in data["labels"] if l["crew_id"] == "c1"]
    assert len(labels) == len(blips) and all(l["expected"] is False for l in labels)
    for r in blips:
        assert any(l["metric"] == r["metric"] and l["start_ms"] <= r["time"] <= l["end_ms"] for l in labels)
        same = sorted(x["time"] for x in rows(data, "c1", r["metric"]) if data["levels"][x["id"]] >= 1)
        assert all(b - a > 2 * DAY for a, b in zip(same, same[1:]))      # never two days in a row


# ------------------------------------------------------------------ c2: quiet drift
def test_c2_rules_stay_quiet_but_the_combination_moves(data):
    assert max(lvls(data, "c2")) == 1 and lvls(data, "c2").count(1) <= 20
    assert data["truth"]["c2"]["max_rule_level_before_window"] == 0
    assert not [a for a in data["alerts"] if a["crew_id"] == "c2"]
    first = lambda m: [r["value"] for r in rows(data, "c2", m)][:10]   # noqa: E731
    last = lambda m: [r["value"] for r in rows(data, "c2", m)][-7:]    # noqa: E731
    mean = lambda x: sum(x) / len(x)                                   # noqa: E731
    shift = {m: mean(last(m)) - mean(first(m)) for m in
             ("heart_rate", "sleep_hours", "body_temperature", "spo2", "respiratory_rate", "exercise_minutes")}
    assert shift["heart_rate"] >= 6 and shift["sleep_hours"] <= -0.9 and shift["body_temperature"] >= 0.25
    assert shift["spo2"] <= -1.0 and shift["respiratory_rate"] >= 1.5 and shift["exercise_minutes"] <= -12


def test_c2_never_triggers_the_apps_pattern_alert(data):
    """The app's pattern needs heart rate, sleep AND mood at level 1+ on the same day."""
    hr_levels = lvls(data, "c2", "heart_rate")
    assert max(hr_levels) == 0                     # heart rate never leaves the normal band


def test_c2_dose_is_quietly_higher_than_the_normal_astronaut(data):
    assert all(l == 0 for l in lvls(data, "c2", "dose_rate"))
    c1 = rows(data, "c1", "cumulative_dose")[-1]["value"]
    c2 = rows(data, "c2", "cumulative_dose")[-1]["value"]
    assert c2 > c1 * 1.08


# ------------------------------------------------------------------ c3: solar storm
def test_c3_storm(data, end):
    t = data["truth"]["c3"]
    assert t["max_rule_level_before_window"] == 0
    dose = rows(data, "c3", "dose_rate")
    last = dose[-1]
    assert last["time"] == end and data["levels"][last["id"]] == 4
    assert t["rules_first_reached_level_ms"]["ge2"] > end - 12 * HOUR_MS
    assert t["rules_first_reached_level_ms"]["ge4"] <= end - 3 * HOUR_MS
    cum = [r["value"] for r in rows(data, "c3", "cumulative_dose")]
    assert cum == sorted(cum)                       # a running total never goes down
    raised = [a for a in data["alerts"] if a["crew_id"] == "c3" and a["state"] == "raised"]
    assert {a["lvl"] for a in raised} >= {3, 4}


# ------------------------------------------------------------------ c4: emergency
def test_c4_emergency(data, end):
    t = data["truth"]["c4"]
    assert t["max_rule_level_before_window"] == 0
    f = t["rules_first_reached_level_ms"]
    assert end - 20 * MIN_MS <= f["ge5"] <= end - 5 * MIN_MS            # oxygen below 90 %
    assert f["ge1"] <= f["ge5"] - 20 * MIN_MS                           # early signs well before level 5
    assert f["ge1"] < f["ge2"] < f["ge3"] <= f["ge5"]
    spo2 = rows(data, "c4", "spo2")[-1]
    assert spo2["time"] == end and spo2["value"] < 90 and data["levels"][spo2["id"]] == 5
    assert data["levels"][rows(data, "c4", "heart_rate")[-1]["id"]] >= 4
    assert any(a["crew_id"] == "c4" and a["lvl"] == 5 and a["state"] == "raised" for a in data["alerts"])


def test_c4_blood_pressure_carries_a_valid_diastolic(data):
    for r in rows(data, "c4", "blood_pressure"):
        assert r["context"]["diastolic"] < r["value"]


# ------------------------------------------------------------------ labels, alerts, csv
def test_labels_are_well_formed(data):
    metrics = {m["api_metric"] for m in json.load(open("app/rules/rules_data.json", encoding="utf-8"))["metrics"]}
    for l in data["labels"]:
        assert l["start_ms"] < l["end_ms"] and (l["metric"] in metrics or l["metric"] == "_combined_")
    by = Counter((l["crew_id"], l["expected"]) for l in data["labels"])
    assert by[("c1", False)] == 8 and by[("c2", True)] == 10 and by[("c3", True)] == 2 and by[("c4", True)] == 5


def test_alerts_follow_the_apps_tiers(data):
    for a in data["alerts"]:
        assert 2 <= a["lvl"] <= 5 and a["tier"] == (a["lvl"] if a["lvl"] <= 2 else 3 if a["lvl"] <= 4 else 4)


def test_csv_truth_labels(data, end):
    table = csv_rows(data)
    assert len(table) == len(data["readings"])
    assert all(r["truth_label"] == 0 for r in table if r["crew_id"] == "c1")           # blips are not anomalies
    drift = [r for r in table if r["crew_id"] == "c2" and r["metric"] == "heart_rate"]
    assert [r["truth_label"] for r in drift[:10]] == [0] * 10 and drift[-1]["truth_label"] == 1
    assert all(r["truth_label"] == 0 for r in table if r["metric"] == "co2_ppm")       # unaffected sensor
    assert [r for r in table if r["crew_id"] == "c4" and r["metric"] == "spo2"][-1]["scenario"] == "respiratory_emergency"


# ------------------------------------------------------------------ through the real API
def test_every_generated_reading_and_entry_is_accepted_by_the_api(client, data):
    out = load_dataset(client, data, reset=True)
    assert out["readings"]["accepted"] == len(data["readings"]) and out["readings"]["rejected"] == 0
    assert out["entries"]["accepted"] == len(data["entries"]) and out["entries"]["rejected"] == 0
    from app.database import SessionLocal
    with SessionLocal() as db:
        count = lambda m: db.scalar(select(func.count()).select_from(m))   # noqa: E731
        assert count(Reading) == len(data["readings"]) and count(Entry) == len(data["entries"])
        assert count(AnomalyLabel) == len(data["labels"]) and count(Alert) == len(data["alerts"])
        assert {c.id for c in db.scalars(select(Crew))} >= {"c1", "c2", "c3", "c4"}
    latest = client.get("/v1/readings?crew_id=c4&metric=spo2&order=desc&limit=1").json()[0]
    assert latest["value"] < 90 and latest["context"]["simulated"] is True


def test_loading_again_adds_nothing_and_reset_restores_the_same_counts(client, data):
    load_dataset(client, data, reset=True)
    again = load_dataset(client, data, reset=False)
    assert again["readings"]["accepted"] == 0 and again["readings"]["duplicates"] == len(data["readings"])
    from app.database import SessionLocal
    load_dataset(client, data, reset=True)
    with SessionLocal() as db:
        assert db.scalar(select(func.count()).select_from(Reading)) == len(data["readings"])
        assert db.scalar(select(func.count()).select_from(AnomalyLabel)) == len(data["labels"])


def test_reset_leaves_real_data_alone(client, data):
    load_dataset(client, data, reset=True)
    real = {"id": "r_real", "seq": 1, "crew_id": "c1", "metric": "heart_rate", "field": "heart_rate", "value": 70,
            "unit": "bpm", "time": int(time.time() * 1000) - 1000,
            "source": {"kind": "manual", "device": "Manual entry", "route": "", "type": "manual"}}
    assert client.post("/v1/readings", json=real).status_code == 200
    load_dataset(client, data, reset=True)
    ids = [r["id"] for r in client.get("/v1/readings?crew_id=c1&metric=heart_rate&limit=5000").json()]
    assert "r_real" in ids and len(ids) == 31          # 30 simulated days + the one real reading


def test_command_line_and_export_files(client, tmp_path, capsys):
    code = sim_main(["--reset-sim", "--out", str(tmp_path / "o")])
    out = capsys.readouterr().out
    assert code == 0 and "0 rejected" in out
    truth = json.loads((tmp_path / "o" / "truth.json").read_text())
    assert set(truth["crew"]) >= {"c1", "c2", "c3", "c4"}
    table = list(csv.DictReader(io.StringIO((tmp_path / "o" / "readings.csv").read_text())))
    assert set(table[0]) == {"id", "crew_id", "metric", "time_ms", "time_utc", "value", "unit", "diastolic",
                             "rule_level", "truth_label", "scenario", "source_kind"}
    assert len(table) > 2000 and table[0]["time_utc"].endswith("+00:00")
    files = {p.name for p in (tmp_path / "o").iterdir()}
    assert files == {"truth.json", "crew.csv", "readings.csv", "entries.csv", "alerts.csv", "anomaly_labels.csv",
                     "zone_bands.csv", "baselines.csv", "metrics.csv"}
    labels = list(csv.DictReader(io.StringIO((tmp_path / "o" / "anomaly_labels.csv").read_text())))
    assert len(labels) == 25 and {"start_utc", "end_utc", "expected"} <= set(labels[0])
