"""Replay the simulated mission into a RUNNING backend, day by day, as if it were being recorded from day 1.

    python -m sim.replay --reset                       # all 40 days at once
    python -m sim.replay --reset --through-day 25      # stop after day 25 (then run the model, then continue)
    python -m sim.replay --from-day 26                 # continue where you stopped
    python -m sim.replay --reset --day-seconds 2 --live-model   # one day every 2 s, model re-run after each day

Readings and entries go through POST /v1/readings and /v1/entries (the real API). The app's rule alerts of each
day are added directly to the database (no endpoint yet), so run this on the machine that holds the database.
The answer key (anomaly_labels) is stored too, but the model never reads it; only /v1/anomalies/overview does.

Same data as astrovitals_fake_data (end 1794708838548, 40 days, seed 7).
"""
from __future__ import annotations

import argparse
import sys
import time

import httpx
from sqlalchemy import delete

from app.database import Base, SessionLocal, engine
from app.models import Alert, AnomalyLabel
from app.rules_loader import load_rules, rules_loaded

from .generate import generate
from .load import ensure_crew, post_all, purge

DAY = 86_400_000
DEFAULT_END = 1794708838548


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--api", default="http://localhost:8000")
    ap.add_argument("--reset", action="store_true", help="delete earlier simulated rows (and model results) first")
    ap.add_argument("--days", type=int, default=40)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--end", type=int, default=DEFAULT_END, help="end time, UTC epoch ms (default = the zip's data)")
    ap.add_argument("--from-day", type=int, default=1)
    ap.add_argument("--through-day", type=int)
    ap.add_argument("--day-seconds", type=float, default=0, help="pause between days, to watch it fill")
    ap.add_argument("--live-model", action="store_true", help="run the model after each day")
    a = ap.parse_args(argv)

    data = generate(a.end, days=a.days, seed=a.seed)
    t0 = min(r["time"] for r in data["readings"])
    last_day = min(a.through_day or a.days, a.days)

    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        if not rules_loaded(db):
            load_rules(db)
        ensure_crew(db)
        if a.reset:
            purge(db)
        db.execute(delete(AnomalyLabel).where(AnomalyLabel.dataset == data["meta"]["dataset"]))
        db.add_all(AnomalyLabel(**l) for l in data["labels"])
        db.commit()

    with httpx.Client(base_url=a.api, timeout=60) as client:
        try:
            client.get("/health").raise_for_status()
        except httpx.HTTPError:
            print(f"Cannot reach the server at {a.api}. Start it first:  uvicorn app.main:app --port 8000", file=sys.stderr)
            return 1
        for day in range(a.from_day, last_day + 1):
            lo, hi = t0 + (day - 1) * DAY, t0 + day * DAY
            last = day == a.days                       # the very last reading sits exactly on the end
            inside = (lambda t: lo <= t <= hi) if last else (lambda t: lo <= t < hi)
            rs = sorted((r for r in data["readings"] if inside(r["time"])), key=lambda r: r["time"])
            es = [e for e in data["entries"] if inside(e["ts"])]
            al = [x for x in data["alerts"] if inside(x["raised_ms"])]
            rr = post_all(client, "/v1/readings", rs) if rs else {"accepted": 0, "duplicates": 0, "rejected": 0, "problems": []}
            post_all(client, "/v1/entries", es) if es else None
            if al:
                with SessionLocal() as db:
                    for x in al:
                        db.merge(Alert(**x))
                    db.commit()
            line = f"day {day:2d}: +{rr['accepted']} readings" + (f", {rr['duplicates']} already there" if rr["duplicates"] else "")
            if rr["rejected"]:
                line += f", {rr['rejected']} REJECTED {rr['problems'][:1]}"
            if al:
                line += "   app rules raised: " + ", ".join(f"{x['crew_id']} level {x['lvl']}" for x in al)
            if a.live_model:
                out = client.post("/v1/anomalies/run").json()
                line += "   model: " + " ".join(f"{c}:{s.get('flagged_days', '-')}" for c, s in out["crew"].items()
                                                  if s["status"] == "scoring") if out["rows_written"] else "   model: still learning"
            print(line, flush=True)
            if a.day_seconds:
                time.sleep(a.day_seconds)
    print(f"\nDone through day {last_day}. Next:  POST {a.api}/v1/anomalies/run   or open {a.api}/demo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
