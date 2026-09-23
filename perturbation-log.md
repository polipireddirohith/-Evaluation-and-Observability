# Perturbation Log

For each system, make one deliberate change to an input or configuration, predict the outcome, run
it, and record what actually happened. See the starters in the Instructions, or design your own (your
own experiment earns more credit).

---

### System 1 — validated, routed pipeline

- **Change I made (file + what I changed):**
  Evaluated the retry boundary safeguard on document `POL-2025-009` (in `tests/test_us01_retry.py::test_ac_01_04_missing_source_halts_immediately`), where the policy text refers to "Schedule A" for endorsements but Schedule A is completely unattached. The tool extraction returns `"endorsements": None` with low confidence (0.2) and the validation classifies it as `category="missing_source"` with `detected_pattern="endorsements_absent"`.
- **Command I ran:**
  `pytest tests/test_us01_retry.py -k "test_ac_01_04_missing_source_halts_immediately" -v`
- **What I predicted:**
  Because the requested data does not exist in the source document, prompting the model to retry is futile and risks hallucination or unnecessary API costs. I predicted the retry controller would halt immediately after exactly 1 API call (`call_count == 1`) and return a `RetryFutileEscalation` record rather than consuming the 3 configured retries.
- **What actually happened (paste the key output line):**
  `tests/test_us01_retry.py::test_ac_01_04_missing_source_halts_immediately PASSED [100%]`
  Escalation record created:
  `RetryFutileEscalation(policy_id='POL-2025-009', field='endorsements', category='missing_source', detected_pattern='endorsements_absent', reason='Schedule A not enclosed')` with `client.call_count == 1`.
- **How this differs from the unperturbed run:**
  On recoverable format or arithmetic errors (such as `negative_premium` in `test_ac_01_03_format_failure_retries_with_error_appended` or `premium_does_not_match_components` in `test_ac_01_03_consistency_failure_also_retries`), the system retries up to `max_retries=3` by appending the specific validation error to the message history. In contrast, when the input document is genuinely missing the source information, the system immediately recognizes the futility boundary and escalates with zero retries.

---

### System 2 — schema-enforced two-pass extraction

- **Change I made (file + what I changed):**
  Supplied `fixtures/documents/income_sum_mismatch.txt` to the extraction pipeline, where the paystub lists monthly income components ($5,416.67 base + $1,250.00 bonus + $2,140.00 commission + $385.50 overtime + $450.00 other = $9,642.17 calculated sum) but states the monthly total as $10,892.17 (a $1,250 discrepancy).
- **Command I ran:**
  `mortgage-extract fixtures/documents/income_sum_mismatch.txt --mode replay`
- **What I predicted:**
  Even though the LLM tool use adheres strictly to the Pydantic schema and produces valid JSON types, the second-pass arithmetic validator will compute the line-item sum, compare it against the stated total, detect that the delta exceeds the $1.00 tolerance, set `consistent: false`, and output the exact discrepancy.
- **What actually happened (paste the key output line):**
  ```json
  "validation": {
    "consistent": false,
    "discrepancies": [
      {
        "field": "total_monthly_income",
        "calculated": 9642.17,
        "stated": 10892.17,
        "delta": -1250.0
      }
    ]
  }
  ```
- **How this differs from the unperturbed run:**
  In the clean unperturbed run (`fixtures/documents/appraisal_informal_sqft.txt`), validation returned `"consistent": true` and `"discrepancies": []`. The perturbed run caught a subtle numerical discrepancy of -$1,250.00 that schema validation alone cannot detect, preventing bad financial data from entering the loan origination system.

---

### System 3 — multi-source synthesis

- **Change I made (file + what I changed):**
  Added the `--simulate-timeout` flag when investigating supplier `meridian`, which forces an artificial timeout when attempting to query the `logistics` data reader.
- **Command I ran:**
  `supply-chain-investigate meridian --offline --simulate-timeout`
- **What I predicted:**
  The investigation coordinator would intercept the read timeout, record `logistics` as unavailable in an alert banner, continue processing the remaining responsive sources (`supplier_audit`, `internal_quality`, `industry_news`), move `late_shipment_count` to the `## Incomplete` section, and reclassify `on_time_delivery_rate` from `## Contested` to `## Well-Established` (since only `supplier_audit` remains to report it).
- **What actually happened (paste the key output line):**
  Header banner: `> Sources unavailable: logistics unavailable (timeout)`
  Incomplete section: `### late_shipment_count  _[missing source: timeout reading logistics]_`
  Contested section: `_none_`
  Well-Established section: `### on_time_delivery_rate  _[single source only]_ (95.0 percent — supplier_audit)`
- **How this differs from the unperturbed run:**
  In the unperturbed run (`supply-chain-investigate meridian --offline`), all 4 sources responded. `late_shipment_count` was populated in `## Well-Established` (11.0 shipments as of 2026-04-05 from logistics), and `on_time_delivery_rate` was placed in `## Contested` citing conflicting values (95.0% from supplier_audit vs. 78.0% from logistics). The perturbed run finished cleanly and highlighted the blind spot rather than crashing or guessing.
