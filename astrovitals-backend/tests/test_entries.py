from sqlalchemy import func, select

from app.models import Entry
from tests.helpers import entry, now_ms


def count(db):
    db.expire_all()
    return db.scalar(select(func.count()).select_from(Entry))


def test_the_apps_stamp_entry_with_empty_payload_is_accepted(client, db):
    r = client.post("/v1/entries", json=entry())
    assert r.status_code == 200 and r.json()["accepted"] == 1
    got = client.get("/v1/entries").json()
    assert got == [{"id": "e_1", "seq": 1, "crew_id": "c1", "field": "mood_daily", "payload": {},
                    "ts": got[0]["ts"]}]


def test_entry_with_a_real_answer_keeps_it(client):
    e = entry(id="e_sym", field="symptom_checklist", payload={"symptoms": ["Nausea", "Fatigue"], "severity": 3})
    client.post("/v1/entries", json=e)
    assert client.get("/v1/entries?field=symptom_checklist").json()[0]["payload"] == e["payload"]


def test_list_wrapped_and_duplicates(client, db):
    assert client.post("/v1/entries", json=[entry(id="a"), entry(id="b")]).json()["accepted"] == 2
    assert client.post("/v1/entries", json={"entries": [entry(id="c")]}).json()["accepted"] == 1
    dup = client.post("/v1/entries", json=entry(id="a")).json()
    assert dup["duplicates"] == 1 and count(db) == 3


def test_every_known_field_is_accepted(client):
    fields = [f["id"] for f in client.get("/v1/profiles").json()["fields"]]
    assert len(fields) == 40
    rep = client.post("/v1/entries", json=[entry(id=f"e_{f}", field=f) for f in fields]).json()
    assert rep["accepted"] == 40


BAD = [
    (dict(field="horoscope"), "unknown field"),
    (dict(field=None), "unknown field"),
    (dict(ts=None), "ts must be"),
    (dict(ts=int(now_ms() / 1000)), "looks like seconds"),
    (dict(ts=now_ms() + 3_600_000), "in the future"),
    (dict(payload="text"), "payload must be an object"),
    (dict(payload={"x": "y" * 25_000}), "payload is too large"),
    (dict(id=""), "id is required"),
    (dict(crew_id="nobody"), "unknown crew_id"),
]


def test_invalid_entries_are_rejected_with_a_reason(client, db):
    import pytest  # noqa: F401
    for change, message in BAD:
        r = client.post("/v1/entries", json=entry(**change))
        assert r.status_code == 422, change
        assert any(message in e for e in r.json()["results"][0]["errors"]), (change, r.json())
    assert count(db) == 0


def test_bad_bodies(client):
    assert client.post("/v1/entries", json="x").status_code == 422
    assert client.post("/v1/entries", json=[]).status_code == 422


def test_entry_history_filters(client):
    t = now_ms() - 5_000_000
    client.post("/v1/entries", json=[entry(id="a", ts=t), entry(id="b", ts=t + 1000, field="journal"),
                                     entry(id="c", ts=t + 2000)])
    assert [e["id"] for e in client.get("/v1/entries").json()] == ["a", "b", "c"]
    assert [e["id"] for e in client.get("/v1/entries?field=mood_daily").json()] == ["a", "c"]
    assert [e["id"] for e in client.get(f"/v1/entries?from={t + 1000}").json()] == ["b", "c"]
    assert [e["id"] for e in client.get("/v1/entries?order=desc&limit=1").json()] == ["c"]
    assert client.get("/v1/entries?field=nope").status_code == 422
    assert client.get("/v1/entries?crew_id=nobody").status_code == 404
