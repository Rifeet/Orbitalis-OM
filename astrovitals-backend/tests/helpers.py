import time


def now_ms() -> int:
    return int(time.time() * 1000)


def reading(**kw):
    """A reading shaped exactly like the app's Reading.toJson()."""
    d = {"id": "r_1", "seq": 1, "crew_id": "c1", "metric": "heart_rate", "field": "heart_rate", "value": 70,
         "unit": "bpm", "time": now_ms() - 1000,
         "source": {"kind": "manual", "device": "Manual entry", "route": "", "type": "manual"},
         "quality": "ok", "context": {"mission_day": 30, "location": "iss"}}
    d.update(kw)
    return d


def entry(**kw):
    """An entry shaped like the app's CrewEntry.toJson() (the app currently sends an empty payload)."""
    d = {"id": "e_1", "seq": 1, "field": "mood_daily", "payload": {}, "ts": now_ms() - 1000}
    d.update(kw)
    return d
