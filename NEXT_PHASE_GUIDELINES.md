# SwasthyaSetu AI — Next-Phase Implementation Guidelines ($0 Budget)

This document extends `GEMINI.md`. It does not replace any existing mandate — it adds
three new features and one new mandate, and every task below is scoped to run on
**free tiers only**: no paid API keys, no paid compute, no paid hosting.

Hand this file directly to your coding agent as a work order. Each section has:
**Goal → Free Stack → Steps → Files to touch → Acceptance Criteria (tests)**.

---

## 🏛️ New Mandate 2.5 — AI Flags Are Advisory, Never Authoritative

Add this to `GEMINI.md` § 2, immediately after 2.4:

> **Mandate:** Any learned/statistical model output (an "AI flag") may be *displayed*
> alongside a screening result, but must **never** alter the deterministic triage
> band computed by `risk_engine.dart`.
> **Practice:** AI flags are stored in a separate field (`aiAnomalyFlag`,
> `aiAnomalyScore`) from `riskBand`. `risk_engine.dart` must have zero import
> dependency on the AI module. A test must assert that feeding the same vitals
> with different AI flag values produces an identical `riskBand`.

This is the mandate that makes Section 1 below safe to build without breaking your
"screening, not diagnosis" story.

---

## 1. On-Device Learned Model (TFLite Anomaly Flag)

### Goal
Give the "edge AI" claim a real artifact: a small, quantized model that runs
locally on the ECG/PPG stream and flags *"rhythm pattern differs from baseline"* —
not a diagnosis, not a disease label. An anomaly-detection framing (not
classification) is the safer and more defensible clinical story, and it's also the
easier model to train well with a small free dataset.

### Free Stack
| Need | Free option |
|---|---|
| Training compute | Google Colab (free T4 GPU tier) |
| Framework | TensorFlow / Keras (free, open source) |
| Labeled ECG data | **PhysioNet MIT-BIH Arrhythmia Database** — fully open access, no payment, no institutional credentialing required for this particular dataset |
| PPG data (optional, for HR-anomaly variant) | **PhysioNet PPG-DaLiA**, also fully open |
| On-device inference | `tflite_flutter` (MIT-licensed Flutter/Dart package) |
| Optional Qualcomm-native bonus | Qualcomm AI Hub (ai-hub.qualcomm.com) has a free tier for profiling/optimizing models against real Snapdragon targets — worth a stretch-goal mention in your pitch: *"profiled on Qualcomm's own AI Hub"* is a strong sponsor-alignment line if you have time |

### Model design (keep it simple and defensible)
1. **Task:** train a small 1D-CNN **autoencoder** on normal-sinus-rhythm beats only
   from MIT-BIH. At inference, high reconstruction error = "differs from normal
   pattern" → anomaly flag. This avoids ever claiming to name a specific
   arrhythmia, which keeps you inside "screening support, not diagnosis."
2. **Input:** fixed-length windows of your existing 250 Hz ECG stream (e.g. 2–3
   second segments = 500–750 samples), normalized the same way your firmware's
   `dsp_pure.h` already filters the signal.
3. **Architecture:** 2–3 Conv1D layers down, symmetric up, <50k parameters. This
   is intentionally tiny — small enough to quantize to int8 and run in single-digit
   milliseconds on a phone CPU.
4. **Export:** `tf.lite.TFLiteConverter`, full-integer (int8) post-training
   quantization. Target model file size under ~200 KB.
5. **Threshold:** pick the anomaly-score cutoff using a held-out validation split,
   not a guess — document the chosen threshold and the false-positive rate you
   measured on held-out normal beats. Judges will ask.

### Integration into your existing codebase
- New file: `lib/core/services/edge_ai_service.dart` — separate from
  `qnn_service.dart`, which stays exactly as-is (it's already honest and correct
  for BP/glucose estimation). Don't conflate the two.
- Feed it from the same ECG buffer `ble_service.dart` already parses out of the
  20-byte telemetry frames — no protocol change needed.
- Add `aiAnomalyFlag` (bool) and `aiAnomalyScore` (double) columns to the
  screening record in `app_database.dart`. These fields **inherit `isDemo`** like
  every other field — an AI flag computed on demo data must be marked demo too.
- `risk_engine.dart` must not import or reference the AI service at all (this is
  what Mandate 2.5's test enforces).
- Surface it in `triage_result_screen.dart` as a clearly separate card, e.g.
  *"AI Pattern Check: rhythm pattern within your baseline"* / *"differs from your
  baseline — consider a professional check"* — never phrased as a diagnosis, never
  colored the same as the clinical risk band.
- In `qnn_service.dart`, only flip `isNpuAccelerated` to `true` if
  `tflite_flutter`'s NNAPI delegate confirms actual hardware delegation on that
  device — keep the same honesty discipline you already have there.

### Acceptance Criteria (write these tests)
- `test/edge_ai_service_test.dart`: model loads under a defined time budget;
  inference completes under a defined latency budget on the test harness; a fixed
  input always produces a fixed anomaly score (determinism of the *inference*
  itself, even though the score is a learned output).
- `test/risk_engine_invariant_test.dart`: identical vitals + different
  `aiAnomalyFlag` values → identical `riskBand`. This is the test that proves
  Mandate 2.5 holds.
- `test/overflow_test.dart`: extend to cover the new AI-flag card at
  `textScaleFactor: 2.0`, same invariant as everything else.

---

## 2. Validation Set: Device vs. Certified Reference

### Goal
One slide with real numbers: *"HR mean absolute error X bpm, SpO₂ mean absolute
error Y%, N=20 paired readings vs. a certified pulse oximeter."* This costs
nothing and is one of the highest trust-per-effort items you can add.

### Free Stack
- A commercial certified pulse oximeter + thermometer (borrow one — most families
  have one post-2020; a clinic/pharmacy will usually let you do a quick comparison
  reading too).
- Google Sheets for logging paired readings (free).
- Python in Google Colab (free) for the analysis — or Google Sheets' own chart
  tools if nobody wants to touch Python.

### Protocol
1. Recruit 15–25 volunteers (teammates, family, friends), spanning a few ages if
   possible.
2. For each volunteer, take a **simultaneous** paired reading: SSAI-SENSE device
   vs. certified reference, for HR, SpO₂, and temperature. Repeat at rest and
   optionally post-mild-activity to get some spread in the data, not just resting
   values clustered in one range.
3. Log to a spreadsheet: `volunteer_id, condition, device_HR, ref_HR, device_SpO2,
   ref_SpO2, device_temp, ref_temp`.
4. Compute, per metric: **Mean Absolute Error (MAE)** and a **Bland-Altman plot**
   (mean of the pair on x-axis, difference between the pair on y-axis — this is
   the standard clinical-agreement chart, trivial in Python with matplotlib, or
   doable as a scatter chart in Sheets).
5. Report MAE + the Bland-Altman limits of agreement, not just "looks close."

### Framing (important — don't overclaim)
This is an **internal engineering validation**, not a clinical trial. Say that
explicitly in your pitch: *"early accuracy check against a consumer-grade
reference, N=20, not a clinical validation study — next step for a real
deployment would be a proper clinical accuracy study."* Judges respect honesty
about the limits of a hackathon-scale validation far more than an inflated claim.

### Deliverable
- `validation/hr_spo2_temp_validation.csv` — the raw paired data, committed to the
  repo.
- `validation/VALIDATION.md` — a short write-up: protocol, N, MAE per metric, the
  Bland-Altman plot image, and the "not a clinical trial" framing above.
- Link this from the main `README.md` with the actual numbers in a small table —
  replace nothing else, just add a new section near the test badges.

### Acceptance Criteria
- The CSV and `VALIDATION.md` exist and are referenced from `README.md`.
- No test needed here — this is a data/documentation deliverable, not code.

---

## 3. Community / Aggregate Early-Warning View

### Goal
Close the loop back to the original problem statement's "healthcare providers,
disaster-response agencies, and public health programs" deployment bullet, which
is currently unaddressed — everything shipped so far is single-patient. This has
to be built **without violating your own privacy mandates**, so the design below
is deliberately conservative about what ever leaves the device.

### Free Stack
- **Firebase Firestore, Spark (free) tier** — generous free read/write/storage
  quota, official `cloud_firestore` Flutter package, fastest to integrate given
  your timeline. (Supabase's free tier is a reasonable alternative if you'd
  rather have Postgres/PostGIS, but Firebase is less setup work for a hackathon
  deadline.)
- Your existing offline map component (already in `lib/core/` per your directory
  structure) — reuse it for the hotspot overlay instead of adding a new mapping
  dependency.
- Your existing Netlify web workstation — extend it with a second page for the
  aggregate dashboard rather than standing up new hosting.

### Privacy-safe data model (this is the part to get right)
Only ever sync, per screening, **if the user opts in** (extend your existing
consent-gated sync toggle — don't add a second consent flow):

```
{
  riskBand: "orange",              // no raw vitals, ever
  category: "heat" | "respiratory" | "cardiac" | "general",
  geohashTruncated: "tdr1x",       // ~5 sensitivity, not device isDemo
  timeBucket: "2026-09-12T14:00Z", // hour-bucketed, not exact timestamp
  isDemo: true|false               // this field is mandatory, same as everywhere else
}
```

Explicitly **never** included: patient ID, name, exact GPS, raw vitals, device ID.
This mirrors exactly the discipline you already apply to on-device storage — you're
just extending the same rule to the one payload that leaves the phone.

### Steps
1. Add the opt-in toggle to the existing sync consent screen (reuse UI patterns
   you already have).
2. On screening save, if opted in: write the truncated-geohash + hour-bucket +
   riskBand + category document to Firestore. No Cloud Function needed for a
   hackathon demo — client-side writes with Firestore security rules restricting
   writes to this shape are enough.
3. New screen: `lib/features/dashboard/community_hotspot_screen.dart` (fits your
   existing `dashboard/` feature folder). Query Firestore for recent documents,
   bucket by geohash prefix, render colored circles sized/colored by red/orange
   count on your existing map widget.
4. Seed a handful of clearly `isDemo: true` entries for the demo itself — and
   make sure the UI visibly labels them as demo, exactly like every other demo
   surface in your app. This is a good opportunity to *show* Mandate 2.1 working
   live for judges, not just claim it in a README.

### Acceptance Criteria (write these tests)
- A privacy test asserting the outgoing sync payload never contains a field named
  anything vitals-related, patient-ID-related, or full-precision-location-related
  — i.e., a schema whitelist test on the sync payload builder.
- A test asserting the consent toggle defaults to **off** (opt-in, not opt-out).
- Extend `overflow_test.dart` to cover the new hotspot screen.

---

## 4. Make the Mandates Visible, Not Just Documented

This is cheap and high-leverage: add a small **"Trust & Provenance" panel**
(behind a long-press or a settings toggle, so it doesn't clutter the normal UI)
that shows, for the *current* reading, live proof of the mandates you already
enforce in code:

```
isDemo:        false
Source:        BLE hardware (SSAI-SENSE-01)
AI inference:  0.8 ms, on-device, CPU
AI flag:       none (baseline pattern)
Triage:        deterministic rule R12 (not AI-derived)
Storage key:   heart_rate_bpm=78 (English, regardless of UI language)
```

During the demo, pull this panel up live instead of just asserting the mandates
verbally. "Show, don't tell" is a much stronger moment for a judge than a README
bullet — and you already have every one of these values computed somewhere in the
app; this is UI work, not new logic.

---

## ✅ Coding Agent Checklist

Before marking any of the above "done," the same checklist from `GEMINI.md` §5.1
applies, plus:

1. `dart format .`
2. `flutter analyze` — zero issues
3. `flutter test` — all passing, including the new invariant tests above
4. New AI/community code must **not** be importable from `risk_engine.dart`
   (Mandate 2.5) or from anything in `lib/domain/` that must stay pure/offline
5. Every new synced or stored field passes through the same `isDemo` provenance
   rule as existing fields — no exceptions for "it's just aggregate data"
