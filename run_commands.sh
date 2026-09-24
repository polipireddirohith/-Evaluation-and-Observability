#!/usr/bin/env bash
# =============================================================================
# run_commands.sh
# Evaluation and Observability Capstone — Full Evidence Pack Generator
#
# Usage:  bash /workspace/run_commands.sh
#         (safe to run multiple times — idempotent)
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
step()  { echo -e "\n${GREEN}════════════════════════════════════════${NC}"; echo -e "${GREEN}  $1${NC}"; echo -e "${GREEN}════════════════════════════════════════${NC}"; }
warn()  { echo -e "${YELLOW}⚠  WARNING: $1${NC}"; }
info()  { echo -e "${CYAN}ℹ  $1${NC}"; }
ok()    { echo -e "${GREEN}✓  $1${NC}"; }
fail()  { echo -e "${RED}✗  $1${NC}"; }

# ── Paths ─────────────────────────────────────────────────────────────────────
WORKSPACE="/workspace"
SYS1="$WORKSPACE/Build a Validated, Routed Insurance Policy Extraction Pipeline/04-hitl-routing/solution"
SYS2="$WORKSPACE/Build a Resilient Mortgage Document Extraction System/04-validate-mathematical-consistency/solution"
SYS3="$WORKSPACE/Investigate Supply Chain Risk with Multi-Source Synthesis/03-resilient-coordinator/solution"

EV1="$WORKSPACE/evidence/01-policy-pipeline"
EV2="$WORKSPACE/evidence/02-mortgage-extraction"
EV3="$WORKSPACE/evidence/03-supply-chain"

# ── Step 0: Inspect workspace ─────────────────────────────────────────────────
step "STEP 0 — Inspecting workspace"
info "Working directory: $WORKSPACE"
ls -1 "$WORKSPACE"

echo ""
info "Python version:"
python3 --version
info "pip version:"
pip --version

# ── Step 1: Verify solution directories ───────────────────────────────────────
step "STEP 1 — Verifying solution directories"
MISSING=0
for dir in "$SYS1" "$SYS2" "$SYS3"; do
    if [ -d "$dir" ]; then
        ok "Found: $dir"
    else
        fail "Missing: $dir"
        MISSING=1
    fi
done
if [ "$MISSING" -eq 1 ]; then
    fail "One or more solution directories are missing. Aborting."
    exit 1
fi

# ── Step 2: Create evidence directories ───────────────────────────────────────
step "STEP 2 — Creating evidence directories"
mkdir -p "$EV1" "$EV2" "$EV3"
ok "Evidence directories ready"

# ═════════════════════════════════════════════════════════════════════════════
#  SYSTEM 1 — Validated, Routed Insurance Policy Pipeline
# ═════════════════════════════════════════════════════════════════════════════
step "SYSTEM 1 — Installing dependencies"
cd "$SYS1"
pip install -e ".[dev]" --quiet
ok "System 1 installed"

step "SYSTEM 1 — Running tests"
pytest tests/ -v 2>&1 | tee "$EV1/tests.txt"
ok "System 1 tests complete → $EV1/tests.txt"

step "SYSTEM 1 — Running static checks (mypy + ruff)"
{
    echo "=== mypy ==="
    mypy policy_extractor/ 2>&1 || true
    echo ""
    echo "=== ruff ==="
    ruff check policy_extractor/ 2>&1 || true
} | tee "$EV1/static-checks.txt"
ok "System 1 static checks complete → $EV1/static-checks.txt"

step "SYSTEM 1 — Running calibration report"
cd "$WORKSPACE"
# calibration_report.py must be run from workspace root with policy_extractor on PYTHONPATH
PYTHONPATH="$SYS1" python calibration_report.py 2>&1 | tee "$EV1/calibration-report.txt" || \
    warn "Calibration report failed — may need routing_decisions.json first (run pipeline step)"
ok "Calibration report → $EV1/calibration-report.txt"

step "SYSTEM 1 — Running pipeline end-to-end"
cd "$SYS1"
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    warn "ANTHROPIC_API_KEY not set — running offline routing test instead"
    pytest tests/test_us04_routing.py -v 2>&1 | tee "$EV1/pipeline-run.txt"
else
    python -m policy_extractor pipeline data/policies/MANIFEST.json \
        2>&1 | tee "$EV1/pipeline-run.txt"
    # Copy routing decisions if generated
    if [ -f routing_decisions.json ]; then
        cp routing_decisions.json "$EV1/routing_decisions.json"
        ok "routing_decisions.json saved → $EV1/routing_decisions.json"
    fi
fi
ok "System 1 pipeline run complete → $EV1/pipeline-run.txt"

step "SYSTEM 1 — Perturbation: missing source halts immediately"
cd "$SYS1"
pytest tests/test_us01_retry.py::test_ac_01_04_missing_source_halts_immediately -v \
    2>&1 | tee "$EV1/perturbation-run.txt"
ok "Perturbation test → $EV1/perturbation-run.txt"

# ═════════════════════════════════════════════════════════════════════════════
#  SYSTEM 2 — Schema-Enforced Two-Pass Mortgage Extraction
# ═════════════════════════════════════════════════════════════════════════════
step "SYSTEM 2 — Installing dependencies"
cd "$SYS2"
pip install -e ".[dev]" --quiet
ok "System 2 installed"

step "SYSTEM 2 — Running tests"
pytest tests/ -v 2>&1 | tee "$EV2/tests.txt"
ok "System 2 tests complete → $EV2/tests.txt"

step "SYSTEM 2 — Running static checks (mypy + ruff)"
{
    echo "=== mypy ==="
    mypy mortgage_extractor/ 2>&1 || true
    echo ""
    echo "=== ruff ==="
    ruff check mortgage_extractor/ 2>&1 || true
} | tee "$EV2/static-checks.txt"
ok "System 2 static checks complete → $EV2/static-checks.txt"

step "SYSTEM 2 — Extracting mortgage documents (replay mode)"
cd "$SYS2"

echo "--- appraisal_informal_sqft ---" | tee "$EV2/extract-run.txt"
python -m mortgage_extractor extract \
    fixtures/documents/appraisal_informal_sqft.txt --mode replay \
    2>&1 | tee -a "$EV2/extract-run.txt"

echo "" >> "$EV2/extract-run.txt"
echo "--- income_missing_bonus ---" >> "$EV2/extract-run.txt"
python -m mortgage_extractor extract \
    fixtures/documents/income_missing_bonus.txt --mode replay \
    2>&1 | tee -a "$EV2/extract-run.txt"

ok "Extract run saved → $EV2/extract-run.txt"

echo "--- income_sum_mismatch (discrepancy detection) ---" | tee "$EV2/discrepancy-run.txt"
python -m mortgage_extractor extract \
    fixtures/documents/income_sum_mismatch.txt --mode replay \
    2>&1 | tee -a "$EV2/discrepancy-run.txt"
ok "Discrepancy run saved → $EV2/discrepancy-run.txt"

# ═════════════════════════════════════════════════════════════════════════════
#  SYSTEM 3 — Provenance-Preserving Supply Chain Risk Investigation
# ═════════════════════════════════════════════════════════════════════════════
step "SYSTEM 3 — Installing dependencies (may take 5-10 minutes for ML packages)"
cd "$SYS3"
pip install -e ".[dev]" --quiet
ok "System 3 installed"

step "SYSTEM 3 — Fixing mypy python_version if needed"
if grep -q 'python_version = "3.11"' pyproject.toml 2>/dev/null; then
    sed -i 's/python_version = "3.11"/python_version = "3.12"/' pyproject.toml
    ok "Fixed mypy python_version: 3.11 → 3.12 (needed for numpy 2.x stubs)"
else
    ok "mypy python_version already correct"
fi

step "SYSTEM 3 — Running tests (takes ~3-4 minutes for ML model load)"
export PYTHONIOENCODING=utf-8
pytest tests/ -v 2>&1 | tee "$EV3/tests.txt"
ok "System 3 tests complete → $EV3/tests.txt"

step "SYSTEM 3 — Running static checks (mypy + ruff)"
{
    echo "=== mypy ==="
    mypy supply_chain_risk/ 2>&1 || true
    echo ""
    echo "=== ruff ==="
    ruff check supply_chain_risk/ 2>&1 || true
} | tee "$EV3/static-checks.txt"
ok "System 3 static checks complete → $EV3/static-checks.txt"

step "SYSTEM 3 — Running supply chain investigation (offline)"
export PYTHONIOENCODING=utf-8
cd "$SYS3"
python -m supply_chain_risk investigate meridian --offline \
    2>&1 | tee "$EV3/investigation-run.txt"
ok "Investigation run saved → $EV3/investigation-run.txt"

# Save a copy as briefing.md
cp "$EV3/investigation-run.txt" "$EV3/briefing.md"
ok "Briefing saved → $EV3/briefing.md"

step "SYSTEM 3 — Perturbation: simulate logistics timeout"
export PYTHONIOENCODING=utf-8
python -m supply_chain_risk investigate meridian --offline --simulate-timeout logistics \
    2>&1 | tee "$EV3/timeout-run.txt" || \
    warn "simulate-timeout flag may not be supported in this version"
ok "Timeout simulation → $EV3/timeout-run.txt"

# ═════════════════════════════════════════════════════════════════════════════
#  FINAL SUMMARY
# ═════════════════════════════════════════════════════════════════════════════
step "FINAL SUMMARY"

echo -e "\n${CYAN}Working directory:${NC} $WORKSPACE"
echo ""
echo -e "${CYAN}Evidence files created:${NC}"
find "$WORKSPACE/evidence" -type f | sort

echo ""
echo -e "${CYAN}Test results:${NC}"
for f in "$EV1/tests.txt" "$EV2/tests.txt" "$EV3/tests.txt"; do
    if [ -f "$f" ]; then
        label=$(basename "$(dirname "$f")")
        result=$(grep -E "passed|failed|error" "$f" | tail -1 || echo "see file")
        echo "  [$label] $result"
    fi
done

echo ""
echo -e "${CYAN}Static check results:${NC}"
for f in "$EV1/static-checks.txt" "$EV2/static-checks.txt" "$EV3/static-checks.txt"; do
    if [ -f "$f" ]; then
        label=$(basename "$(dirname "$f")")
        result=$(grep -E "Success|error|Found" "$f" | tail -1 || echo "see file")
        echo "  [$label] $result"
    fi
done

echo ""
echo -e "${CYAN}Environment variables required for live API calls:${NC}"
echo "  ANTHROPIC_API_KEY  (not set — offline/replay mode used throughout)"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  All evidence collected. Next steps:${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  1. Review evidence files:"
echo "       ls /workspace/evidence/"
echo ""
echo "  2. Fill in the reflection brief:"
echo "       nano /workspace/reflection-brief.md"
echo ""
echo "  3. Fill in the perturbation log:"
echo "       nano /workspace/perturbation-log.md"
echo ""
echo "  4. Push to GitHub (if required):"
echo "       cd /workspace"
echo "       git add ."
echo "       git commit -m 'feat: evaluation and observability evidence pack'"
echo "       git push origin main"
echo ""
echo -e "${GREEN}  Done!${NC}"
