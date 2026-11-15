import time

import pytest
from sqlalchemy.exc import IntegrityError

from app.models import (Alert, AlertAction, ContextConfirmation, Emergency, EmergencyEvent, Entry, GroundReport,
                        Reading, Session, User)

NOW = lambda: int(time.time() * 1000)  # noqa: E731


def reading(**kw):
    base = dict(id="r_1", seq=1, crew_id="c1", metric="heart_rate", field="heart_rate", value=70.0, unit="bpm",
                time_ms=NOW(), source_kind="device", source_device="Wrist strap", source_route="MEC",
                source_type="direct", quality="ok", context_json={"mission_day": 30, "location": "iss"},
                received_ms=NOW())
    base.update(kw)
    return Reading(**base)


def alert(**kw):
    base = dict(id="a_1", crew_id="c1", metric="spo2", field="spo2", lvl=4, tier=3, title="Low oxygen",
                obs="SpO2 88%", acts_json=["Re-measure"], contact="Call flight surgeon", state="raised",
                raised_ms=NOW(), updated_ms=NOW())
    base.update(kw)
    return Alert(**base)


def must_fail(db, *objs):
    db.add_all(objs)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_full_round_trip_of_every_table(db):
    db.add(User(email="lena@example.com", password_hash="x" * 60, name="Lena", role="Engineer",
                crew_id="c1", created_ms=NOW()))
    db.flush()
    uid = db.query(User).one().id
    db.add(Session(token_hash="a" * 64, user_id=uid, issued_ms=NOW(), expires_ms=NOW() + 86_400_000))
    db.add(reading())
    db.add(Entry(id="e_1", seq=2, crew_id="c1", field="mood_daily", payload_json={"mood": 4}, ts_ms=NOW(),
                 received_ms=NOW()))
    db.add(alert())
    db.flush()
    db.add(AlertAction(client_id="ack_a_1", alert_id="a_1", action="ack", time_ms=NOW()))
    db.add(Emergency(id="em_1", crew_id="c1", type="spo2", started_ms=NOW()))
    db.flush()
    db.add(EmergencyEvent(client_id="ev_e_1step_1", emergency_id="em_1", kind="answer", key="step_1",
                          value_json=True, time_ms=NOW()))
    db.add(ContextConfirmation(client_id="ctx_eva", crew_id="c1", suggested="eva", answer="yes",
                               signals_json={"hr": 110}, time_ms=NOW()))
    db.add(GroundReport(crew_id="c1", created_ms=NOW(), payload_json={"summary": "ok"}))
    db.commit()
    got = db.get(Reading, "r_1")
    assert got.context_json["mission_day"] == 30 and got.time_ms > 1_700_000_000_000


# ---- duplicate protection (the offline queue may resend) ----
def test_same_reading_id_cannot_be_saved_twice(db):
    db.add(reading())
    db.commit()
    must_fail(db, reading())


def test_same_alert_action_cannot_be_saved_twice(db):
    db.add(alert())
    db.commit()
    db.add(AlertAction(client_id="ack_a_1", alert_id="a_1", action="ack", time_ms=NOW()))
    db.commit()
    must_fail(db, AlertAction(client_id="ack_a_1", alert_id="a_1", action="ack", time_ms=NOW()))


def test_email_is_unique(db):
    mk = lambda: User(email="a@b.co", password_hash="h", name="A", crew_id="c1", created_ms=NOW())  # noqa: E731
    db.add(mk())
    db.commit()
    must_fail(db, mk())


# ---- links must point at something real ----
def test_reading_for_unknown_crew_rejected(db):
    must_fail(db, reading(crew_id="nobody"))


def test_reading_with_unknown_metric_rejected(db):
    must_fail(db, reading(metric="not_a_metric"))


def test_action_for_unknown_alert_rejected(db):
    must_fail(db, AlertAction(client_id="ack_zzz", alert_id="zzz", action="ack", time_ms=NOW()))


def test_user_for_unknown_crew_rejected(db):
    must_fail(db, User(email="x@y.co", password_hash="h", name="X", crew_id="nope", created_ms=NOW()))


# ---- allowed values ----
@pytest.mark.parametrize("bad", [dict(quality="great"), dict(source_kind="satellite")])
def test_reading_value_rules(db, bad):
    must_fail(db, reading(**bad))


@pytest.mark.parametrize("bad", [dict(lvl=6), dict(lvl=-1), dict(tier=5), dict(state="exploded")])
def test_alert_value_rules(db, bad):
    must_fail(db, alert(**bad))


def test_alert_action_name_rule(db):
    db.add(alert())
    db.commit()
    must_fail(db, AlertAction(client_id="x_a_1", alert_id="a_1", action="delete", time_ms=NOW()))


def test_alert_lifecycle_can_move_through_states(db):
    a = alert()
    db.add(a)
    db.commit()
    for s in ["shown", "acknowledged", "started", "cleared"]:
        a.state = s
        db.commit()
    assert db.get(Alert, "a_1").state == "cleared"


def test_pattern_alert_may_have_no_metric(db):
    db.add(alert(id="a_pat", metric=None, field="pattern_hr_sleep_mood"))
    db.commit()
    assert db.get(Alert, "a_pat").metric is None


def test_deleting_an_alert_removes_its_actions(db):
    db.add(alert())
    db.commit()
    db.add(AlertAction(client_id="ack_a_1", alert_id="a_1", action="ack", time_ms=NOW()))
    db.commit()
    db.delete(db.get(Alert, "a_1"))
    db.commit()
    assert db.query(AlertAction).count() == 0


# ---- AI test tables ----
from app.models import AnomalyLabel, AnomalyResult  # noqa: E402


def test_label_window_must_be_forward(db):
    must_fail(db, AnomalyLabel(crew_id="c1", metric="heart_rate", start_ms=2000, end_ms=1000, scenario="x"))
    db.add(AnomalyLabel(crew_id="c1", metric="heart_rate", start_ms=1000, end_ms=2000, scenario="x"))
    db.commit()


def test_label_needs_a_real_crew(db):
    must_fail(db, AnomalyLabel(crew_id="nobody", metric="heart_rate", start_ms=1, end_ms=2, scenario="x"))


def test_result_rules(db):
    ok = dict(crew_id="c1", metric="heart_rate", time_ms=1000, score=0.4, flagged=False, model_version="v1")
    db.add(AnomalyResult(**ok))
    db.commit()
    must_fail(db, AnomalyResult(**ok))                                   # same model, same point
    db.add(AnomalyResult(**{**ok, "model_version": "v2"}))               # another model version is fine
    db.commit()
    must_fail(db, AnomalyResult(**{**ok, "time_ms": 2000, "score": -1}))
    must_fail(db, AnomalyResult(**{**ok, "time_ms": 3000, "reading_id": "no_such_reading"}))
