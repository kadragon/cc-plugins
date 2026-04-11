#!/bin/bash
# validate-harness.sh — Verify harness artifacts are complete and consistent
# Usage: bash validate-harness.sh [project-root]
#
# Checks:
#   1. Required files exist
#   2. AGENTS.md is under 100 lines
#   3. All files referenced in AGENTS.md docs index exist
#   4. Golden principles have enforcement references
#   5. Delegation table is present and non-empty

set -euo pipefail

PROJ_DIR="${1:-.}"
cd "$PROJ_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

pass()  { PASS=$((PASS + 1)); echo -e "  ${GREEN}PASS${NC}  $1"; }
warn()  { WARN=$((WARN + 1)); echo -e "  ${YELLOW}WARN${NC}  $1"; }
fail()  { FAIL=$((FAIL + 1)); echo -e "  ${RED}FAIL${NC}  $1"; }

echo "=== Harness Validation ==="
echo "  Project: $(pwd)"
echo ""

# ── 1. Required files ──────────────────────────────────────
echo "--- Required Files ---"

for f in AGENTS.md CLAUDE.md; do
    [[ -f "$f" ]] && pass "$f exists" || fail "$f missing"
done

for f in docs/architecture.md docs/conventions.md docs/workflows.md docs/delegation.md docs/eval-criteria.md docs/runbook.md; do
    [[ -f "$f" ]] && pass "$f exists" || warn "$f missing"
done

# ── 2. AGENTS.md line count ────────────────────────────────
echo ""
echo "--- AGENTS.md Size ---"

if [[ -f "AGENTS.md" ]]; then
    lines=$(wc -l < AGENTS.md | tr -d ' ')
    if [[ $lines -le 100 ]]; then
        pass "AGENTS.md is $lines lines (limit: 100)"
    elif [[ $lines -le 120 ]]; then
        warn "AGENTS.md is $lines lines (limit: 100, slightly over)"
    else
        fail "AGENTS.md is $lines lines (limit: 100, too long)"
    fi
fi

# ── 3. Reference integrity ─────────────────────────────────
echo ""
echo "--- Reference Integrity ---"

if [[ -f "AGENTS.md" ]]; then
    referenced_docs=$(grep -oP '`docs/[a-zA-Z0-9_./-]+`' AGENTS.md 2>/dev/null | tr -d '`' || true)
    if [[ -z "$referenced_docs" ]]; then
        warn "No docs/ references found in AGENTS.md"
    else
        for doc in $referenced_docs; do
            [[ -f "$doc" ]] && pass "Referenced $doc exists" || fail "Referenced $doc missing"
        done
    fi
fi

# ── 4. Golden principles section ───────────────────────────
echo ""
echo "--- Golden Principles ---"

if [[ -f "AGENTS.md" ]]; then
    if grep -q "Golden Principles" AGENTS.md 2>/dev/null; then
        principle_count=$(grep -cP '^\d+\.' <(sed -n '/Golden Principles/,/^##/p' AGENTS.md) 2>/dev/null || echo "0")
        if [[ $principle_count -ge 3 && $principle_count -le 7 ]]; then
            pass "$principle_count golden principles defined (ideal: 3-7)"
        elif [[ $principle_count -gt 0 ]]; then
            warn "$principle_count golden principles (recommend 3-7)"
        else
            warn "Golden Principles section exists but no numbered items found"
        fi
    else
        fail "No Golden Principles section in AGENTS.md"
    fi
fi

# ── 5. Delegation table ────────────────────────────────────
echo ""
echo "--- Delegation ---"

if [[ -f "AGENTS.md" ]]; then
    if grep -q "Delegation" AGENTS.md 2>/dev/null; then
        pass "Delegation section exists in AGENTS.md"
    else
        warn "No Delegation section in AGENTS.md"
    fi
fi

if [[ -f "docs/delegation.md" ]]; then
    pass "docs/delegation.md exists with detailed routing"
else
    warn "docs/delegation.md missing — delegation details not documented"
fi

# ── 6. Enforcement check ───────────────────────────────────
echo ""
echo "--- Enforcement ---"

has_enforcement=false
[[ -f ".claude/settings.json" ]] && { pass ".claude/settings.json (hooks) exists"; has_enforcement=true; }
[[ -f ".pre-commit-config.yaml" ]] && { pass ".pre-commit-config.yaml exists"; has_enforcement=true; }
[[ -f ".husky/pre-commit" ]] && { pass ".husky/pre-commit exists"; has_enforcement=true; }
[[ -d ".github/workflows" ]] && { pass ".github/workflows/ exists"; has_enforcement=true; }

$has_enforcement || warn "No enforcement layer detected (hooks, pre-commit, or CI)"

# ── Summary ─────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo -e "  ${GREEN}PASS: $PASS${NC}  ${YELLOW}WARN: $WARN${NC}  ${RED}FAIL: $FAIL${NC}"

if [[ $FAIL -gt 0 ]]; then
    echo -e "  ${RED}Harness incomplete — fix FAIL items before proceeding${NC}"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "  ${YELLOW}Harness functional but has gaps — consider addressing WARN items${NC}"
    exit 0
else
    echo -e "  ${GREEN}Harness complete${NC}"
    exit 0
fi
