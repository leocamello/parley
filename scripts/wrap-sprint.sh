#!/usr/bin/env bash
# Parley loop harness — milestone wrap & transition.
#
# Run ONLY after ./scripts/verify-sprint.sh exits 0 in the green phase.
# Usage: ./scripts/wrap-sprint.sh <sprint-number> [issue-number]
#
# 1. Requires phase green in .parley_sprint_scope (human-flipped after
#    red-phase test review).
# 2. Traceability gate: with an issue number, every numbered Given/When/Then
#    scenario (S1..Sn) in that issue must map to an acceptance test selector
#    containing it (testS3_...). Gaps block the wrap.
# 3. Re-runs verification as a final audit and captures seed + case counts.
# 4. Writes the audit record to .parley_verification_audit (for SPRINT notes).
# 5. Stages the sprint's in-scope paths (the pre-commit scope sentinel
#    provides the enforcement backstop).
#
# It does NOT commit: the agent writes SPRINT<N>-NOTES.md, stages it, and
# commits with message format 'feat(domain): implement [Class] per Doc A laws'.
set -Eeuo pipefail

cd "$(dirname "$0")/.."

SPRINT="${1:?Usage: ./scripts/wrap-sprint.sh <sprint-number> [issue-number]}"
ISSUE="${2:-}"
AUDIT_FILE=".parley_verification_audit"
SCOPE_FILE=".parley_sprint_scope"

PHASE=$(sed -n 's/^phase: *//p' "$SCOPE_FILE" | head -1)
if [[ "$PHASE" != "green" ]]; then
  echo "🛑 Wrap aborted: phase is '$PHASE', not green. The human operator flips" >&2
  echo "   the phase in $SCOPE_FILE after reviewing the red-phase tests." >&2
  exit 1
fi

# Scenario <-> test traceability gate: every numbered scenario Sn declared in
# the milestone tracking issue must map to at least one acceptance test whose
# selector contains 'Sn' (convention: testS3_...). Hard block on gaps.
if [[ -n "$ISSUE" ]]; then
  echo "🔗 Traceability gate against issue #$ISSUE..."
  SCENARIOS=$(gh issue view "$ISSUE" --json body --jq .body 2>/dev/null \
    | grep -oE '\bS[0-9]+\b' | sort -u -V || true)
  if [[ -z "$SCENARIOS" ]]; then
    echo "🛑 Wrap aborted: issue #$ISSUE declares no numbered scenarios (S1..Sn)." >&2
    exit 1
  fi
  MISSING=0
  for S in $SCENARIOS; do
    if ! grep -rqE "test${S}[_A-Z]" tests/acceptance/ 2>/dev/null; then
      echo "🛑 TRACEABILITY GAP: scenario $S has no acceptance test (expected a selector matching test${S}_*)." >&2
      MISSING=1
    fi
  done
  if [[ $MISSING -ne 0 ]]; then
    echo "Every numbered scenario in issue #$ISSUE requires a matching test in tests/acceptance/." >&2
    exit 1
  fi
  echo "✅ Traceability: every scenario in issue #$ISSUE has a matching acceptance test."
else
  echo "ℹ️  No issue number given — skipping the scenario↔test traceability gate."
fi

echo "🔎 Final verification audit for Sprint $SPRINT..."

set +e
AUDIT_OUTPUT=$(./scripts/verify-sprint.sh 2>&1)
AUDIT_EXIT=$?
set -e

if [[ $AUDIT_EXIT -ne 0 ]]; then
  echo "🛑 Wrap aborted: verification is not green (exit $AUDIT_EXIT)." >&2
  echo "$AUDIT_OUTPUT" >&2
  exit 1
fi

VERIFY_LINE=$(grep '^PARLEY-VERIFY: PASS' <<< "$AUDIT_OUTPUT")
SEED_LINE=$(grep '^PARLEY-SEED:' <<< "$AUDIT_OUTPUT" | head -1)
GST_VERSION=$(gst --version 2>/dev/null | head -1)

{
  echo "sprint: $SPRINT"
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "toolchain: $GST_VERSION"
  echo "$SEED_LINE"
  echo "$VERIFY_LINE"
} > "$AUDIT_FILE"

echo "📋 Audit recorded in $AUDIT_FILE:"
cat "$AUDIT_FILE"

echo "📦 Staging Sprint $SPRINT workspace..."
git add src/ tests/ scripts/ 2>/dev/null || true
[[ -f "SPRINT${SPRINT}-NOTES.md" ]] && git add "SPRINT${SPRINT}-NOTES.md"

git status --short

cat <<EOF

✅ Sprint $SPRINT wrap complete. Remaining agent steps:
  1. Write SPRINT${SPRINT}-NOTES.md (built classes, ambiguities resolved or
     questions asked, the seed/verify lines from $AUDIT_FILE, and the exact
     toolchain line above), then: git add SPRINT${SPRINT}-NOTES.md
  2. Commit: feat(domain): implement [Class] per Doc A laws
  3. HALT and report completion to the human user.
EOF
