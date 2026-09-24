#!/usr/bin/env bash
# Evaluation and Observability capstone validation/evidence runner.
# Run from repository root: bash run_commands.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYS1="$ROOT/systems/01-policy-pipeline"
SYS2="$ROOT/systems/02-mortgage-extraction"
SYS3="$ROOT/systems/03-supply-chain"
EV1="$ROOT/01-policy-pipeline"
EV2="$ROOT/02-mortgage-extraction"
EV3="$ROOT/03-supply-chain"

for d in "$SYS1" "$SYS2" "$SYS3" "$EV1" "$EV2" "$EV3"; do
  [ -d "$d" ] || { echo "Missing required directory: $d" >&2; exit 1; }
done

echo "Repository: $ROOT"
python3 --version
python3 -m pip --version

echo "=== System 1: policy pipeline ==="
cd "$SYS1"
python3 -m pip install -e ".[dev]" --quiet
python3 -m pytest tests/ -v 2>&1 | tee "$EV1/tests.txt"
{
  echo "=== mypy ==="
  python3 -m mypy policy_extractor/ 2>&1 || true
  echo
  echo "=== ruff ==="
  python3 -m ruff check policy_extractor/ tests/ 2>&1 || true
} | tee "$EV1/static-checks.txt"
cd "$ROOT"
PYTHONPATH="$SYS1" python3 calibration_report.py 2>&1 | tee "$EV1/calibration-report.txt"
cd "$SYS1"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  python3 -m policy_extractor pipeline data/policies/MANIFEST.json 2>&1 | tee "$EV1/pipeline-run.txt"
else
  python3 -m pytest tests/test_us04_routing.py -v 2>&1 | tee "$EV1/pipeline-run.txt"
fi

echo "=== System 2: mortgage extraction ==="
cd "$SYS2"
python3 -m pip install -e ".[dev]" --quiet
python3 -m pytest tests/ -v 2>&1 | tee "$EV2/tests.txt"
{
  echo "=== mypy ==="
  python3 -m mypy mortgage_extractor/ 2>&1 || true
  echo
  echo "=== ruff ==="
  python3 -m ruff check mortgage_extractor/ tests/ 2>&1 || true
} | tee "$EV2/static-checks.txt"
python3 -m mortgage_extractor extract fixtures/documents/appraisal_informal_sqft.txt --mode replay 2>&1 | tee "$EV2/extract-run.txt"
python3 -m mortgage_extractor extract fixtures/documents/income_missing_bonus.txt --mode replay 2>&1 | tee -a "$EV2/extract-run.txt"
python3 -m mortgage_extractor extract fixtures/documents/income_sum_mismatch.txt --mode replay 2>&1 | tee "$EV2/discrepancy-run.txt"

echo "=== System 3: supply chain ==="
cd "$SYS3"
python3 -m pip install -e ".[dev]" --quiet
export PYTHONIOENCODING=utf-8
python3 -m pytest tests/ -v 2>&1 | tee "$EV3/tests.txt"
{
  echo "=== mypy ==="
  python3 -m mypy supply_chain_risk/ 2>&1 || true
  echo
  echo "=== ruff ==="
  python3 -m ruff check supply_chain_risk/ tests/ 2>&1 || true
} | tee "$EV3/static-checks.txt"
python3 -m supply_chain_risk investigate meridian --offline 2>&1 | tee "$EV3/investigation-run.txt"
cp "$EV3/investigation-run.txt" "$EV3/briefing.md"
python3 -m supply_chain_risk investigate meridian --offline --simulate-timeout logistics 2>&1 | tee "$EV3/timeout-run.txt"

echo
echo "=== Validation complete ==="
echo "Evidence directories:"
printf '  %s\n' "$EV1" "$EV2" "$EV3"
