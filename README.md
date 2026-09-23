# Evaluation and Observability — Capstone Project Submission

**Author:** ROHITH KUMAR POLIPIREDDI  
**Date:** 2026-09-23  
**Repository:** [https://github.com/polipireddirohith/-Evaluation-and-Observability](https://github.com/polipireddirohith/-Evaluation-and-Observability)  

This repository contains the full evidence pack, perturbation experiments, reflection brief, and runnable source code for all three production-grade LLM reliability systems:
1. **Validated, Routed Insurance Policy Pipeline:** Retry boundaries (`missing_source` escalation vs. format retries), batch processing, deterministic HITL routing on `(confidence ∧ reviewer ∧ integration)`, and sliced `policy_type × field` calibration analysis.
2. **Schema-Enforced Two-Pass Mortgage Document Extraction:** Strict Pydantic tool calling, nullable non-fabrication guarantees, unit normalization (`"about 2,400 sq ft"` → `2400`), and post-extraction mathematical consistency validation.
3. **Provenance-Preserving Supply Chain Risk Investigation:** Multi-source synthesis across heterogeneous inputs (`supplier_audit`, `internal_quality`, `logistics`, `industry_news`), conflict preservation with timestamps in `## Contested`, and graceful degradation under source outage (`--simulate-timeout`).

---

## Submission Checklist & Deliverables

| Deliverable | Location | Description |
|---|---|---|
| **Environment Documentation** | [`environment.txt`](./environment.txt) | Python 3.13.1, Windows 11, venv isolation, offline/replay execution notes |
| **Completed Reflection Brief** | [`reflection-brief.md`](./reflection-brief.md) | Every question answered and grounded in exact cited artifacts |
| **Perturbation Experiment Log** | [`perturbation-log.md`](./perturbation-log.md) | Controlled failure experiments and predictions for all 3 systems |
| **System 1 Evidence** | [`01-policy-pipeline/`](./01-policy-pipeline/) | `tests.txt` (45 passed), `static-checks.txt` (mypy/ruff 0 errors), `pipeline-run.txt`, `routing_decisions.json`, `calibration-report.txt`, terminal screenshot |
| **System 2 Evidence** | [`02-mortgage-extraction/`](./02-mortgage-extraction/) | `tests.txt` (25 passed), `static-checks.txt` (mypy/ruff 0 errors), `extract-run.txt`, `discrepancy-run.txt`, terminal screenshot |
| **System 3 Evidence** | [`03-supply-chain/`](./03-supply-chain/) | `tests.txt` (34 passed), `static-checks.txt` (mypy/ruff 0 errors), `investigation-run.txt`, `briefing.md`, `timeout-run.txt`, terminal screenshot |
| **Source Systems** | [`systems/`](./systems/) | Full runnable solutions, schemas, prompts, fixtures, and test suites |

---

## Directory Layout

```
.
├── README.md                      # Project overview and submission guide
├── environment.txt                # System and Python environment specifications
├── perturbation-log.md            # Controlled perturbations for systems 1, 2, and 3
├── reflection-brief.md            # Completed reflection brief with grounded evidence
├── calibration_report.py          # Script for sliced policy_type x field calibration report
│
├── 01-policy-pipeline/
│   ├── tests.txt                  # Full pytest output (45 passed, 3 live skipped)
│   ├── static-checks.txt          # mypy (0 issues) + ruff (clean)
│   ├── pipeline-run.txt           # Pipeline routing execution capture
│   ├── routing_decisions.json     # Generated routing decisions JSON (10 records)
│   ├── calibration-report.txt     # Sliced calibration report (exposing umbrella/exclusions)
│   └── screenshots/
│       └── system1_verification.png
│
├── 02-mortgage-extraction/
│   ├── tests.txt                  # Full pytest output (25 passed)
│   ├── static-checks.txt          # mypy (0 issues) + ruff (clean)
│   ├── extract-run.txt            # Clean runs (appraisal_informal_sqft, income_missing_bonus)
│   ├── discrepancy-run.txt        # Arithmetic discrepancy run (income_sum_mismatch: -$1250)
│   └── screenshots/
│       └── system2_verification.png
│
├── 03-supply-chain/
│   ├── tests.txt                  # Full pytest output (34 passed)
│   ├── static-checks.txt          # mypy (0 issues) + ruff (clean)
│   ├── investigation-run.txt      # supply-chain-investigate meridian --offline
│   ├── briefing.md                # Generated executive briefing with 3 sections
│   ├── timeout-run.txt            # Run with --simulate-timeout showing graceful degradation
│   └── screenshots/
│       └── system3_verification.png
│
└── systems/
    ├── 01-policy-pipeline/        # Insurance policy pipeline package and tests
    ├── 02-mortgage-extraction/    # Mortgage document extraction package and tests
    └── 03-supply-chain/           # Supply chain risk investigation package and tests
```

---

## Quickstart & Reproduction

Each system can be reproduced in its own virtual environment using Python 3.11+:

### System 1: Policy Pipeline
```bash
cd systems/01-policy-pipeline
.venv\Scripts\pytest tests/ -v
.venv\Scripts\mypy policy_extractor/
.venv\Scripts\ruff check policy_extractor/ tests/
.venv\Scripts\python ../../calibration_report.py
```

### System 2: Mortgage Document Extraction
```bash
cd systems/02-mortgage-extraction
.venv\Scripts\pytest tests/ -v
.venv\Scripts\mypy mortgage_extractor/
.venv\Scripts\ruff check mortgage_extractor/ tests/
.venv\Scripts\mortgage-extract fixtures/documents/income_sum_mismatch.txt --mode replay
```

### System 3: Supply Chain Risk Investigation
```bash
cd systems/03-supply-chain
.venv\Scripts\pytest tests/ -v
.venv\Scripts\mypy supply_chain_risk/
.venv\Scripts\ruff check supply_chain_risk/ tests/
.venv\Scripts\supply-chain-investigate meridian --offline
.venv\Scripts\supply-chain-investigate meridian --offline --simulate-timeout
```
