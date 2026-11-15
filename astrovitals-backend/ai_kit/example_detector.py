#!/usr/bin/env python3
"""A deliberately NAIVE detector, only to show how the files fit together and to give you a score to beat.

    python example_detector.py readings.csv results.csv

For every astronaut and metric it learns a normal mean and spread from the first 20 days, then flags any
single reading more than 3 standard deviations away. It looks at one metric at a time and has no memory,
so it cannot see a slow combined drift and it will flag harmless blips. Your model should do better.

cumulative_dose is skipped on purpose: it is a running total that only ever rises, so "far from the early
average" is always true. A real model must difference it or use dose_rate instead.
"""
import csv
import statistics
import sys
from collections import defaultdict

DAY = 86_400_000
LEARN_DAYS, THRESHOLD = 20, 3.0


def main(readings_path: str, results_path: str) -> None:
    rows = list(csv.DictReader(open(readings_path, encoding="utf-8")))
    start = min(int(r["time_ms"]) for r in rows)
    learn = defaultdict(list)
    for r in rows:
        if int(r["time_ms"]) < start + LEARN_DAYS * DAY:
            learn[(r["crew_id"], r["metric"])].append(float(r["value"]))
    normal = {}
    for k, v in learn.items():
        mean = statistics.fmean(v)
        sd = max(statistics.pstdev(v), 0.01 * abs(mean) + 1e-6)     # floor, so a flat series cannot explode
        normal[k] = (mean, sd)
    with open(results_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "flagged", "score"])
        for r in rows:
            if r["metric"] == "cumulative_dose":
                w.writerow([r["id"], 0, 0])
                continue
            mean, sd = normal[(r["crew_id"], r["metric"])]
            z = abs(float(r["value"]) - mean) / sd
            w.writerow([r["id"], int(z > THRESHOLD), round(z, 3)])
    print(f"wrote {results_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
