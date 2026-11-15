from datetime import datetime, timedelta, timezone


def iso(dt):
    return dt.astimezone(timezone.utc).isoformat()


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_create_and_get_astronaut(client, astro):
    assert client.get(f"/astronauts/{astro['id']}").json()["name"] == "Test"
    assert len(client.get("/astronauts").json()) == 1
    assert client.get("/astronauts/999").status_code == 404


def test_invalid_astronaut_rejected(client):
    r = client.post("/astronauts", json={"name": "X", "age": 5, "sex": "female"})
    assert r.status_code == 422


# ---- vitals ----

def test_add_vital_defaults_unit_and_time(client, astro):
    r = client.post("/vitals", json={"astronaut_id": astro["id"], "type": "heart_rate", "value": 64})
    assert r.status_code == 201
    body = r.json()
    assert body["unit"] == "bpm" and body["timestamp"]


def test_vital_wrong_unit_rejected(client, astro):
    r = client.post("/vitals", json={"astronaut_id": astro["id"], "type": "glucose",
                                     "value": 90, "unit": "mmol/L"})
    assert r.status_code == 422


def test_vital_implausible_value_rejected(client, astro):
    r = client.post("/vitals", json={"astronaut_id": astro["id"], "type": "heart_rate", "value": -5})
    assert r.status_code == 422
    r = client.post("/vitals", json={"astronaut_id": astro["id"], "type": "temperature", "value": 98.6})
    assert r.status_code == 422  # Fahrenheit typo caught


def test_vital_future_timestamp_rejected(client, astro):
    ts = iso(datetime.now(timezone.utc) + timedelta(hours=2))
    r = client.post("/vitals", json={"astronaut_id": astro["id"], "type": "heart_rate",
                                     "value": 60, "timestamp": ts})
    assert r.status_code == 422


def test_vital_unknown_astronaut(client):
    r = client.post("/vitals", json={"astronaut_id": 999, "type": "heart_rate", "value": 60})
    assert r.status_code == 404


def test_vitals_range_and_type_filter(client, astro):
    now = datetime.now(timezone.utc)
    for days_ago, val in [(10, 58), (2, 61), (1, 63)]:
        client.post("/vitals", json={"astronaut_id": astro["id"], "type": "heart_rate",
                                     "value": val, "timestamp": iso(now - timedelta(days=days_ago))})
    client.post("/vitals", json={"astronaut_id": astro["id"], "type": "glucose", "value": 90})
    week = client.get(f"/vitals/{astro['id']}?range=7d&type=heart_rate").json()
    assert [v["value"] for v in week] == [61, 63]  # ordered, 10-day-old excluded
    assert client.get(f"/vitals/{astro['id']}?range=banana").status_code == 422


# ---- radiation ----

def test_radiation_dose_type_derived(client):
    r = client.post("/radiation", json={"device_id": "CAD-1", "dose_rate": 18, "unit": "uSv/h"})
    assert r.status_code == 201 and r.json()["dose_type"] == "effective"
    r = client.post("/radiation", json={"device_id": "HERA-1", "dose_rate": 14, "unit": "uGy/h"})
    assert r.json()["dose_type"] == "absorbed"


def test_radiation_gy_sv_mixing_rejected(client):
    r = client.post("/radiation", json={"device_id": "X", "dose_rate": 5, "unit": "uGy/h",
                                        "dose_type": "effective"})
    assert r.status_code == 422
    r = client.post("/radiation", json={"device_id": "X", "dose_rate": 5, "unit": "mSv/day",
                                        "dose_type": "absorbed"})
    assert r.status_code == 422


def test_radiation_negative_rejected(client):
    r = client.post("/radiation", json={"device_id": "X", "dose_rate": -1, "unit": "uSv/h"})
    assert r.status_code == 422


def test_radiation_current_returns_latest_per_device(client):
    now = datetime.now(timezone.utc)
    for mins_ago, rate in [(30, 10), (5, 12)]:
        client.post("/radiation", json={"device_id": "HERA-1", "dose_rate": rate, "unit": "uGy/h",
                                        "timestamp": iso(now - timedelta(minutes=mins_ago))})
    client.post("/radiation", json={"device_id": "REM-1", "dose_rate": 9, "unit": "uGy/h"})
    cur = {r["device_id"]: r["dose_rate"] for r in client.get("/radiation/current").json()}
    assert cur == {"HERA-1": 12, "REM-1": 9}


def test_radiation_history_filter_by_astronaut(client, astro):
    client.post("/radiation", json={"device_id": "CAD-1", "astronaut_id": astro["id"],
                                    "dose_rate": 18, "unit": "uSv/h"})
    client.post("/radiation", json={"device_id": "HERA-1", "dose_rate": 14, "unit": "uGy/h"})
    rows = client.get(f"/radiation?astronaut_id={astro['id']}").json()
    assert len(rows) == 1 and rows[0]["device_id"] == "CAD-1"
