# Reflection Brief — Evaluation and Observability Capstone

**Name:** ROHITH KUMAR POLIPIREDDI
**Date:** 2026-09-23

> Ground every answer in your own run. When a question asks for a number, file name, or line, paste
> it from your artifacts — a reviewer should be able to find it. Answers that are correct in the
> abstract but cite nothing do not meet the bar. Keep it short and specific.

---

## 0. Environment

| Field | Value |
|---|---|
| OS & version | Microsoft Windows 11 (NT 10.0.26200.0, win32 x86_64) |
| Python version | Python 3.13.1 (CPython 64-bit at C:\Python313\python.exe) |
| Date run | 2026-09-23 |
| Ran any system live? (which) | None (all three systems executed in deterministic offline / replay modes) |

---

## 1. Validated, routed pipeline

| Evidence | Value |
|---|---|
| Passing test count | 45 passed, 3 skipped (live API tests) in `01-policy-pipeline/tests.txt` |
| Routing output file | `01-policy-pipeline/routing_decisions.json` |
| auto_approve / human_review / spot_check counts | 3 / 3 / 4 (in `01-policy-pipeline/pipeline-run.txt`) |

**1a. Retry boundary.** From your perturbation run (a required field removed), paste the escalation
record. How many API calls did the system make, and why is retrying a futile case worse than
escalating it?

> Escalation record from `tests/test_us01_retry.py::test_ac_01_04_missing_source_halts_immediately` (document `POL-2025-009`):
> ```python
> RetryFutileEscalation(
>     policy_id='POL-2025-009',
>     field='endorsements',
>     category='missing_source',
>     detected_pattern='endorsements_absent',
>     reason='Schedule A not enclosed'
> )
> ```
> The system made exactly **1 API call** (`client.call_count == 1`).
> Retrying a futile case is worse than escalating it because no amount of re-prompting can extract information that does not exist in the source document. Retrying wastes API budget and latency, and worse, repeatedly telling an LLM that a required field is missing actively pressures the model to hallucinate or fabricate believable endorsements to clear the prompt constraint. Escalating immediately halts futile execution, preserves data integrity, and alerts human operators to obtain the missing schedule.

**1b. Reading the router.** Pick one `human_review` record from your routing output. Which of the
three signals (confidence, reviewer, integration) sent it to a human? If you had trusted the model's
confidence alone, what would have happened?

> From `01-policy-pipeline/routing_decisions.json`, policy `POL-2025-010`:
> ```json
> {
>   "policy_id": "POL-2025-010",
>   "policy_type": "home",
>   "decision": "human_review",
>   "reason": "integration_failure=['premium_matches_components_sum']",
>   "fields_below_threshold": [],
>   "reviewer_disagreements": [],
>   "integration_failures": ["premium_matches_components_sum"],
>   "confidence_summary": {
>     "coverage_limit": 0.95,
>     "deductible": 0.95,
>     "endorsements": 0.95,
>     "exclusions": 0.95,
>     "policy_type": 0.95,
>     "premium_amount": 0.95
>   }
> }
> ```
> The signal that sent it to a human was **integration** (`integration_failures: ['premium_matches_components_sum']`).
> The model rated its own confidence at **0.95 across every single field**, including `premium_amount`. If we had trusted the model's confidence alone, this policy would have been auto-approved despite a $50 discrepancy between stated premium ($2,400.00) and the actual line-item sum ($2,350.00), introducing an accounting error into downstream financial systems.

**1c. Where the aggregate lies.** Run the calibration snippet. Quote the one cell whose accuracy lags
its confidence, plus the overall figure. What does slicing by `policy_type × field` catch that a
single number hides?

> From `01-policy-pipeline/calibration-report.txt`:
> ```
> umbrella  exclusions      n=2 conf=0.93 acc=0.00 brier=0.865
> OVERALL brier=0.291
> ```
> Sliced cell: `umbrella / exclusions` had `conf=0.93` but `acc=0.00` with `brier=0.865`.
> The overall Brier score of **0.291** appears moderate and acceptable because high-volume, well-performing cells (like `auto / premium_amount` at `acc=1.00, brier=0.003`) wash out the error. Slicing by `policy_type × field` catches catastrophic localized failure pockets where the model is severely overconfident yet completely wrong (0% accuracy), preventing dangerous blind spots from hiding behind aggregate averages.

---

## 2. Schema-enforced two-pass extraction

| Evidence | Value |
|---|---|
| Passing test count | 25 passed in `02-mortgage-extraction/tests.txt` |
| Document run | `fixtures/documents/income_sum_mismatch.txt` (and `appraisal_informal_sqft.txt`) |
| Classified type | `paystub` (income extraction) / `appraisal` (property extraction) |

**2a. Two guarantees.** Paste your discrepancy-run output. Tool use already forces valid JSON, yet the
validator still catches a bad sum. Why are these two different guarantees? Name one error each cannot
catch.

> From `02-mortgage-extraction/discrepancy-run.txt`:
> ```json
> "validation": {
>   "consistent": false,
>   "discrepancies": [
>     {
>       "field": "total_monthly_income",
>       "calculated": 9642.17,
>       "stated": 10892.17,
>       "delta": -1250.0
>     }
>   ]
> }
> ```
> Tool use guarantees **syntactic and structural validity** (the output conforms to the Pydantic schema types, floats, and keys), whereas the validator guarantees **internal semantic and arithmetic consistency** (the mathematical invariant that components sum to the stated total).
> - Tool use *cannot* catch internal arithmetic contradictions where every value is a syntactically valid float ($5,416.67 + $1,250.00 + $2,140.00 + $385.50 + $450.00 = $9,642.17 vs stated $10,892.17).
> - The arithmetic validator *cannot* catch structural JSON schema violations or malformed response formats that occur prior to successful object instantiation (e.g. unparseable JSON or type collisions).

**2b. Refusing to fabricate.** Run on a document missing a field. Paste that field's output. Why null
instead of an invented value? Point to the schema choice that allows it.

> From `02-mortgage-extraction/extract-run.txt` (`income_missing_bonus.txt`):
> ```json
> "bonus_monthly": null,
> "bonus_ytd": null,
> "commission_monthly": null
> ```
> The extractor returns `null` because the source document does not mention bonus or commission income. Returning `null` explicitly signals absence of evidence without falsely assuming zero earnings or fabricating a plausible amount, preventing distorted debt-to-income (DTI) underwriting decisions.
> Schema choice: In `mortgage_extractor/schemas.py`, the field is defined with an optional type:
> `bonus_monthly: float | None = Field(default=None, description="...")` (JSON Schema type `["number", "null"]`).
> This allows the model to cleanly return `null` without failing Pydantic schema validation.

**2c. Normalization.** Quote one field where the source text and extracted value differ in format
("about 2,400 sq ft" → `2400`). Why normalize at extraction time rather than downstream?

> In `fixtures/documents/appraisal_informal_sqft.txt`:
> Source text: `"Estimated Gross Living Area: about 2,400 sq ft across two levels"`
> Extracted value in `02-mortgage-extraction/extract-run.txt`:
> ```json
> "gross_living_area_sqft": 2400
> ```
> Normalizing at extraction time grounds the transformation in the context of the source document where linguistic nuances ("about", "sq ft", "two levels") can be interpreted by the LLM. If raw conversational text were emitted downstream, every downstream microservice, database table, and pricing model would require custom regex parsers, scattering fragile normalization logic across the entire architecture.

---

## 3. Multi-source synthesis

| Evidence | Value |
|---|---|
| Passing test count | 34 passed in `03-supply-chain/tests.txt` |
| Briefing file | `03-supply-chain/briefing.md` |
| Section the conflict landed in | `## Contested` |

**3a. Annotate, don't arbitrate.** Quote one conflicting-metric pair from your briefing — both values,
sources, dates. Give one way a reader is better served by the preserved conflict than by a single
reconciled number.

> From `03-supply-chain/briefing.md`:
> ```markdown
> ### on_time_delivery_rate  _[2 sources, conflicting]_  ⚠️ ESCALATE
> - escalation: high-impact metric is contested across sources
> - Reported values by source:
>     - 95.0 percent — supplier_audit (as of 2026-04-10)
>     - 78.0 percent — logistics (as of 2026-04-05)
> ```
> Metric: `on_time_delivery_rate`
> - Value 1: **95.0 percent** from `supplier_audit` (as of **2026-04-10**)
> - Value 2: **78.0 percent** from `logistics` (as of **2026-04-05**)
> A reader is far better served because averaging them (e.g. 86.5%) would destroy actionable business intelligence: the supplier claims an excellent 95% delivery record during scheduled audits, but real-time telemetry from shipping logistics records a dismal 78% following the Long Beach port strike. Preserving both values with dates surfaces potential vendor reporting bias or hidden logistics friction that warrants immediate procurement scrutiny.

**3b. Source goes dark.** Run with `--simulate-timeout`. Paste the part of the briefing showing the
failed source. How is "unreachable" handled differently from "nothing to report," and why does the run
still finish?

> From `03-supply-chain/timeout-run.txt`:
> ```markdown
> > Sources unavailable: logistics unavailable (timeout)
> ...
> ## Incomplete
> ### late_shipment_count  _[missing source: timeout reading logistics]_
> - missing source: timeout reading logistics
> ```
> "Unreachable" indicates an infrastructure or network failure—data exists in the physical world but could not be inspected. In contrast, "nothing to report" means the source was successfully queried and confirmed the absence of negative signals. Treating an unreachable source as "nothing to report" would create a hazardous false sense of security.
> The run still finishes because the coordinator wraps source readers in error handlers, recording partial results and categorizing unread metrics into `## Incomplete` with diagnostic tags, delivering graceful degradation instead of a catastrophic crash.

**3c. Dates as a guardrail.** Quote two claims about the same supplier with different dates. How does
requiring a date stop a time difference from reading as a contradiction?

> From `03-supply-chain/briefing.md`:
> 1. `field_quality_concern` (date **2026-02-19**, source `industry_news`):
>    > Meridian Components issued a voluntary precautionary recall of a single capacitor-assembly lot in Q1 2026...
> 2. `port_disruption` (date **2026-03-17**, source `industry_news`):
>    > A 72-hour dockworker strike at the Port of Long Beach beginning March 16, 2026 stranded Meridian Components' inbound container shipments...
> Also observed in `average_lead_time_days`: **2026-04-05** (`logistics`) and **2026-04-10** (`supplier_audit`).
> Requiring an ISO `source_date` ensures that sequential historical developments (e.g. a February recall followed by a March shipping strike) are understood as chronological events rather than contradictory simultaneous states of the supplier.

---

## 4. Synthesis

**4a. One principle.** Name the single moment in your runs (system + artifact) where *evaluate the
output, don't trust the model's word* most clearly caught something a trusting design would have
shipped.

> In **System 1**, `01-policy-pipeline/routing_decisions.json`, record `POL-2025-010`:
> The extraction model self-rated its confidence at **0.95 across all fields**. A trusting system would have automatically approved the policy. However, the deterministic integration validator executed code to calculate whether `stated_premium == sum(components)`. It caught a $50 discrepancy ($2,400 stated vs $2,350 component sum) and forced the decision to `human_review`. External code-based evaluation caught what the model's confidence concealed.

**4b. Confidence ≠ correctness.** Pick the system where this mattered most, and explain why using
something you observed.

> In **System 1**, `01-policy-pipeline/calibration-report.txt`:
> Slicing by `policy_type × field` revealed that for `umbrella / exclusions`:
> - Mean predicted confidence: **0.93 (93%)**
> - Observed accuracy: **0.00 (0%)**
> - Brier score: **0.865**
> The model was 93% confident while being wrong 100% of the time on umbrella policy exclusions. Relying on self-reported confidence as a release gate would have approved 100% of these corrupted extractions without a single human review.

**4c. Apply it.** Describe a real workflow where an LLM pulls structured results from messy input.
Which pattern — validated retry with escalation, independent review with deterministic routing, or
provenance-preserving conflict annotation — would you reach for first, and what would you instrument
to know when it broke?

> **Workflow:** Ingesting multimodal commercial freight invoices and bills of lading into an automated enterprise accounts-payable system.
> **Pattern Chosen:** **Independent review with deterministic routing combined with validated retry with escalation.**
> - An extraction model pulls carrier details, line-item freight charges, fuel surcharges, and total due into structured JSON.
> - An arithmetic validator computes `sum(freight_charges) + fuel_surcharge == total_due`.
> - If an arithmetic or format error occurs, the system retries with the error appended (up to 2 times). If the document genuinely lacks an invoice number or tariff schedule, it hits the retry boundary and immediately escalates (`missing_source`).
> - A distinct reviewer model cross-verifies vendor payment terms against the contract database. Clean invoices auto-pay; any arithmetic mismatch, tax ID discrepancy, or reviewer disagreement is deterministically routed to human accounts-payable auditors.
> **Instrumentation to know when it broke:**
> 1. *Sliced Calibration & Brier Tracking:* Slice extraction accuracy and Brier score by `vendor × charge_type` to catch formatting drift whenever a carrier updates their invoice layout.
> 2. *Retry Pattern Telemetry:* Monitor the ratio of format retries to `missing_source` futile escalations. An anomalous spike in `missing_source` escalations immediately indicates an upstream scanning or ingestion failure (such as missing multi-page attachments).
