# Which anomaly model for AstroVitals?  (tested on the simulated crew)

Reproduce: `pip install -r requirements.txt` then `python compare_models.py <folder with readings.csv + truth.json>`.
Averages of 3 simulated datasets (seeds 7, 8, 9). Same protocol for every model: learn only from each astronaut's first 20
normal days, personal z-scores, thresholds fixed in advance (nothing tuned on the test days).

## Recommendation
1. **Personal baseline z-scores** (median + robust spread, shrunk toward the crew-wide spread) are the foundation.
2. **Slow layer, for drifts like c2:** a multivariate distance on the 15-metric personal z-vector. **Mahalanobis** (shrinkage
   covariance, chi-square threshold) as the main detector because it is explainable (which metrics pushed the score), has no
   randomness, and needs no tuning. **KNN distance** as a second opinion. Alert only when flagged on **2 of the last 3 days**.
3. **Acute layer, for storms and emergencies:** personal z-score with 2 readings in a row. ML adds nothing here.
4. **Isolation Forest is not the main model** (default settings, ~80 learning rows): it flagged about 18 % of normal days and the
   result changes with its random seed. **MEWMA** (the textbook slow-drift method), as configured, flagged over half of normal days.

## Slow layer: c2 quiet drift (drift began 19 days before the end; the app's rules never alerted)
Persistent alert (2 of 3 days). `first alert` = days before the end the drift was first flagged (a value above ~17 is a false alarm
before any real signal). False-alarm days are out of 57 normal test days; blips are c1's 6 harmless blips in the test region.
| Detector | first alert | false-alarm days / 57 | blips flagged / 6 |
|---|---|---|---|
| KNN distance | 11.3 | 0.3 | 0.3 |
| LOF | 12.3 | 1.0 | 1.0 |
| **Mahalanobis** | 12.7 | 1.0 | 1.0 |
| max z-score > 3.5 | 14.3 (range 12-19) | 1.7 | 1.0 |
| sum of z-squared | 15.0 (range 12-19) | 2.3 | 1.3 |
| Isolation Forest | 17.3 | 10.3 | 2.0 |
| Isolation Forest on raw values (no personal baseline) | 13.7 | 13.7 | 1.3 |
| MEWMA | 18.0 | 32.7 | 4.0 |

Every detector flagged all of c2's last 7 days. The "earlier" first alerts of Isolation Forest and MEWMA are false alarms, not
early detection.

## Acute layer (minutes before the end; persistent = 2 readings in a row)
| Detector | c4 emergency first alert | false alarms | c3 storm first alert |
|---|---|---|---|
| max z-score > 3.5 | 45 | 0 | 540 |
| sum of z-squared | 45 | 0 | 540 |
| Mahalanobis | 43 | 0 | n/a (1 metric) |
| KNN | 42 | 0 | 540 |
| LOF | 67 (some before onset = false) | 0.3 | 580 |
| Isolation Forest | 77 (some before onset = false) | 1.3 | 600 |
| *App rules, for comparison* | level 2 at 25, level 5 at 10 | | level 2 at 540 |

The emergency began 50 minutes before the end, so any first alert above 50 is a false alarm. The simple z-score is about 20 minutes
ahead of the rules' level 2 for c4 and equal to the rules for c3.

## What to take away
* Personal baseline + combining metrics + persistence matter far more than the algorithm.
* A day-level persistence rule hides single-day events: c3 and c4 are flagged on raw day vectors but not when persistence is
  required. That is why the acute layer exists separately.
* No algorithm here is "untrained": each needs about 3 weeks of normal data per astronaut. Plan a calibration period at mission
  start (or pre-mission baselines) and fall back to crew-wide values until then.

## Limits of this test (say this if asked)
* The data is simulated by us, with one drifting astronaut and one smooth drift shape. Real data will be messier (gaps, medication,
  exercise cycles, non-normal noise). Differences of 1-2 days or about 1 false-alarm day between Mahalanobis, KNN and LOF are
  within noise: do not rank them from this test.
* Thresholds were fixed in advance, not tuned. Tuning on simulated data would just fit our own generator.
* The drift is only detectable about a week after it starts, because its first days are tiny.
