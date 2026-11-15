"""Load the simulated crew into the database THROUGH THE REAL API, then export files for the AI notebook.

    python -m sim.load --reset-sim                      # in-process, no server needed
    python -m sim.load --reset-sim --api http://localhost:8000
    python -m sim.load --days 60 --end 2026-11-14T12:00:00Z --out sim_output

Readings and entries go through POST /v1/readings and /v1/entries (the same door the Flutter app uses),
so the API's validation also checks the generated data. Crew, labels and the rule alerts are written to
the database directly (no endpoints exist for them yet), so run this on the machine that holds the database.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import delete, func, select

from app.database import Base, SessionLocal, engine
from app.models import Alert, AnomalyLabel, AnomalyResult, Crew, Entry, Reading
from app.rules_loader import DEMO_MISSION_ID, load_rules, rules_loaded

from .generate import CREW, csv_rows, generate, utc

BATCH = 400


def ensure_crew(db) -> None:
    for c in CREW:
        if db.get(Crew, c["id"]) is None:
            db.add(Crew(id=c["id"], name=c["name"], role=c["role"], mission_id=DEMO_MISSION_ID))
    db.commit()


def _like(col):
    return col.like("sim\\_%", escape="\\")


def sim_row_count(db) -> int:
    return db.scalar(select(func.count()).select_from(Reading).where(_like(Reading.id))) or 0


def purge(db) -> None:
    """Remove everything this simulator created (and nothing else)."""
    db.execute(delete(AnomalyResult).where(_like(AnomalyResult.reading_id)))
    db.execute(delete(Alert).where(Alert.id.like("sim\\_alert\\_%", escape="\\")))
    db.execute(delete(Entry).where(_like(Entry.id)))
    db.execute(delete(Reading).where(_like(Reading.id)))
    db.execute(delete(AnomalyLabel).where(AnomalyLabel.dataset == "demo"))
    db.commit()


def post_all(client, url: str, items: list) -> dict:
    total, problems = Counter(), []
    for i in range(0, len(items), BATCH):
        r = client.post(url, json=items[i:i + BATCH])
        rep = r.json()
        if "results" not in rep:
            raise RuntimeError(f"{url}: unexpected answer {r.status_code}: {str(rep)[:300]}")
        for k in ("accepted", "duplicates", "rejected"):
            total[k] += rep[k]
        problems += [x for x in rep["results"] if x["status"] == "rejected"]
    return {**total, "problems": problems}


def load_dataset(client, data: dict, reset: bool = False) -> dict:
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        if not rules_loaded(db):
            load_rules(db)
        ensure_crew(db)
        if reset:
            purge(db)
        elif sim_row_count(db):
            print("warning: simulated rows already exist. If the end time differs they will overlap; "
                  "use --reset-sim for a clean start.", file=sys.stderr)
    readings = post_all(client, "/v1/readings", data["readings"])
    entries = post_all(client, "/v1/entries", data["entries"])
    with SessionLocal() as db:
        db.execute(delete(AnomalyLabel).where(AnomalyLabel.dataset == data["meta"]["dataset"]))
        db.add_all(AnomalyLabel(**l) for l in data["labels"])
        for a in data["alerts"]:
            db.merge(Alert(**a))
        db.commit()
    return {"readings": readings, "entries": entries, "labels": len(data["labels"]), "alerts": len(data["alerts"])}


def _write_csv(path: Path, rows: list[dict]) -> Path:
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return path


def export(data: dict, out: Path) -> list[Path]:
    """One CSV per important table (plus truth.json), so a notebook can use them without the backend."""
    from .levels import load_rules
    rules = load_rules()
    out.mkdir(parents=True, exist_ok=True)
    tables = {
        "crew.csv": [{"id": c["id"], "name": c["name"], "role": c["role"], "story": c["story"]} for c in CREW],
        "readings.csv": csv_rows(data),
        "entries.csv": [{"id": e["id"], "seq": e["seq"], "crew_id": e["crew_id"], "field": e["field"],
                         "ts": e["ts"], "time_utc": utc(e["ts"]), "payload_json": json.dumps(e["payload"])}
                        for e in data["entries"]],
        "alerts.csv": [{"id": a["id"], "crew_id": a["crew_id"], "metric": a["metric"], "lvl": a["lvl"],
                        "tier": a["tier"], "title": a["title"], "obs": a["obs"], "state": a["state"],
                        "raised_ms": a["raised_ms"], "raised_utc": utc(a["raised_ms"])} for a in data["alerts"]],
        "anomaly_labels.csv": [{**l, "start_utc": utc(l["start_ms"]), "end_utc": utc(l["end_ms"])}
                               for l in data["labels"]],
        "zone_bands.csv": [{"series_key": k, "band_order": i, "from_value": b[0], "to_value": b[1], "level": b[2]}
                           for k, z in rules["zones"].items() for i, b in enumerate(z["bands"])],
        "baselines.csv": [{"series_key": k, "value": v} for k, v in rules["baselines"].items()],
        "metrics.csv": [{k: v for k, v in m.items() if k != "extra"} for m in rules["metrics"]],
    }
    paths = []
    p = out / "truth.json"
    p.write_text(json.dumps({"meta": data["meta"], "crew": data["truth"]}, indent=1) + "\n", encoding="utf-8")
    paths.append(p)
    paths += [_write_csv(out / name, rows) for name, rows in tables.items()]
    return paths


def parse_end(s: str | None) -> int:
    if not s:
        return int(time.time() * 1000) - 120_000          # 2 minutes ago: never 'in the future'
    return int(datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc).timestamp() * 1000)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--days", type=int, default=30, help="history length, at least 30")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--env", default="iss", choices=["iss", "moon", "mars_transit", "mars_surface"])
    ap.add_argument("--end", help="end time, ISO 8601 UTC (default: 2 minutes ago)")
    ap.add_argument("--api", help="base URL of a running server (default: run the app in-process)")
    ap.add_argument("--reset-sim", action="store_true", help="delete earlier simulated rows first")
    ap.add_argument("--out", default="sim_output", help="folder for truth.json and one CSV per table")
    a = ap.parse_args(argv)

    if a.days > 40:
        print("warning: with more than ~40 days the running dose (cumulative_dose) passes 50 % of the app's 50 mSv "
              "mission limit, so the app's rules start raising radiation alerts for EVERY astronaut, including the "
              "normal one. Fine for model training; not for the 'rules stay quiet' story.", file=sys.stderr)
    data = generate(parse_end(a.end), days=a.days, seed=a.seed, env=a.env)
    if a.api:
        import httpx
        with httpx.Client(base_url=a.api, timeout=60) as client:
            summary = load_dataset(client, data, a.reset_sim)
    else:
        from fastapi.testclient import TestClient
        from app.main import app
        with TestClient(app) as client:
            summary = load_dataset(client, data, a.reset_sim)

    paths = export(data, Path(a.out))
    r, e = summary["readings"], summary["entries"]
    print(f"readings: {r['accepted']} saved, {r['duplicates']} already there, {r['rejected']} rejected")
    print(f"entries:  {e['accepted']} saved, {e['duplicates']} already there, {e['rejected']} rejected")
    print(f"labels: {summary['labels']}   rule alerts: {summary['alerts']}   crew: {', '.join(c['id'] for c in CREW)}")
    print("wrote " + ", ".join(str(p) for p in paths))
    bad = r["problems"] + e["problems"]
    for p in bad[:5]:
        print("REJECTED", p, file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
