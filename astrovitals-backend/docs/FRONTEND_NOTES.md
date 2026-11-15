# Notes for the Flutter side (found while reading the app's code)

The backend already accepts the app's real payloads. These are the places where the app and its own contract disagree
or lose information. None blocks the demo; the first three matter for the AI.

1. **Blood pressure loses the diastolic value.** `_readingDef('dia')` returns null ("reported with systolic"), so only
   systolic is posted. The backend accepts an optional `context: {"diastolic": 76}` on the `blood_pressure` reading
   (checked against the diastolic limits, and must be lower than systolic). Suggest adding it to `context`.
2. **Entries are posted with an empty payload.** `stamp(fieldId)` posts `payload: {}`, so symptoms, severity, journal text,
   medications etc. never reach the server. The backend stores any JSON object payload; send the real answer.
3. **Radiation is posted as `dose_rate` (mSv/day)**, but the app's registry (`kMetrics`) declares `cumulative_dose` (mSv).
   The backend accepts BOTH as different metrics. Decide which the app should send (ideally both).
4. **Unit spelling differs** between the registry and the posts (`% RH` vs `%RH`, `/ min` vs `/min`). The backend ignores
   spaces and case when comparing units.
5. **Time must be UTC epoch milliseconds.** Seconds, or a time more than 5 minutes ahead, is rejected.
6. **Same id twice is safe.** Resending a queued item returns `duplicate`, not an error. A batch answers per item; only a
   fully rejected request returns 422, so the queue should keep items marked `rejected` for a human to look at.
7. **Rules from the server:** `GET /v1/profiles` (use `If-None-Match` with the last ETag; 304 = unchanged). Keep the built-in
   tables as the fallback when the server is unreachable.
8. **Reaching the server:** Android emulator `http://10.0.2.2:8000`, iOS simulator `http://localhost:8000`, real phone
   `http://<computer-ip>:8000` with `uvicorn ... --host 0.0.0.0`. Flutter web needs its port added to `CORS_ORIGINS`.
   Plain `http://` on a real Android device may need a debug-only cleartext exception.
