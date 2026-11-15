#!/usr/bin/env python3
"""Score an anomaly model against the simulated crew. Standard library only.

    python evaluate.py readings.csv truth.json results.csv

results.csv needs two columns:  id (a reading id from readings.csv)  and  flagged (1/0, true/false).
Readings missing from results.csv count as "not flagged". An optional `score` column is ignored here.

What it reports
  * overall: anomalies found / missed, and false alarms among readings that are NOT part of any scenario
  * harmless blips (astronaut c1): the model should NOT flag these
  * per scenario (c2 quiet drift, c3 solar storm, c4 emergency): when the model first flagged, and how that
    compares with when the app's RULES first reached level 2 and level 3 ("lead time")
"""
import csv
import json
import sys
from collections import defaultdict

MIN = 60_000
DAY = 86_400_000


def truthy(v: str) -> bool:
    return str(v).strip().lower() in ("1", "true", "yes", "y")


def fmt_gap(ms: int) -> str:
    return f"{ms / DAY:.1f} days" if abs(ms) >= DAY else f"{ms / MIN:.0f} min"


def main(readings_path: str, truth_path: str, results_path: str) -> None:
    readings = list(csv.DictReader(open(readings_path, encoding="utf-8")))
    truth = json.load(open(truth_path, encoding="utf-8"))
    flagged = {}
    for r in csv.DictReader(open(results_path, encoding="utf-8")):
        flagged[r["id"]] = truthy(r["flagged"])
    known = {r["id"] for r in readings}
    stray = [i for i in flagged if i not in known]
    if stray:
        print(f"warning: {len(stray)} ids in results.csv are not in readings.csv (ignored), e.g. {stray[:2]}")
    missing = len(known) - len(known & set(flagged))
    if missing:
        print(f"note: {missing} readings had no result; counted as not flagged")

    end = truth["meta"]["end_ms"]
    tp = fn = fp = tn = 0
    blips_total = blips_flagged = 0
    for r in readings:
        is_anom = r["truth_label"] == "1"
        f = flagged.get(r["id"], False)
        tp += is_anom and f
        fn += is_anom and not f
        fp += (not is_anom) and f
        tn += (not is_anom) and not f
        if r["crew_id"] == "c1" and int(r["rule_level"]) >= 1:
            blips_total += 1
            blips_flagged += f

    print("\n=== OVERALL ===")
    print(f"anomalous readings found:   {tp} of {tp + fn}  (recall {tp / max(1, tp + fn):.0%})")
    print(f"false alarms:               {fp} of {fp + tn} normal readings  ({fp / max(1, fp + tn):.1%})")
    print(f"harmless blips flagged:     {blips_flagged} of {blips_total}   (c1; lower is better)")

    print("\n=== PER SCENARIO (when did the model first flag?) ===")
    by_crew = defaultdict(list)
    for r in readings:
        by_crew[r["crew_id"]].append(r)
    for cid in ("c2", "c3", "c4"):
        t = truth["crew"][cid]
        ws, we = t["window_start_ms"], t["window_end_ms"]
        rows = by_crew[cid]
        in_win = [r for r in rows if r["truth_label"] == "1"]
        hits = sorted(int(r["time_ms"]) for r in in_win if flagged.get(r["id"], False))
        early_fp = sum(1 for r in rows if int(r["time_ms"]) < ws and flagged.get(r["id"], False))
        print(f"\n{cid} {t['name']}  ({t['story']})")
        print(f"  flagged {len(hits)} of {len(in_win)} anomalous readings; {early_fp} false alarms before the scenario began")
        if not hits:
            print("  MISSED: the model never flagged this scenario")
            continue
        first = hits[0]
        print(f"  first flag: {fmt_gap(end - first)} before the end  ({fmt_gap(first - ws)} after the scenario began)")
        for lvl in (2, 3):
            rt = t["rules_first_reached_level_ms"].get(f"ge{lvl}")
            if rt is None:
                print(f"  app rules: never reached level {lvl}  -> model flagged it, rules did not")
            else:
                d = rt - first
                word = "EARLIER" if d > 0 else "later"
                print(f"  app rules reached level {lvl}: {fmt_gap(end - rt)} before the end -> model was {fmt_gap(abs(d))} {word}")
    print("\n(c1 is normal: any flag on c1 is a false alarm.)")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
