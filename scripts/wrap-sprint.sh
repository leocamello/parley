#!/usr/bin/env bash
# Parley loop harness — milestone wrap & transition.
#
# Run ONLY after ./scripts/verify-sprint.sh exits 0.
# Usage: ./scripts/wrap-sprint.sh <sprint-number>
#
# 1. Re-runs verification as a final audit and captures seed + case counts.
# 2. Writes the audit record to .parley_verification_audit (for SPRINT notes).
# 3. Stages the sprint's in-scope paths (the pre-commit scope sentinel
#    provides the enforcement backstop).
#
# It does NOT commit: the agent writes SPRINT<N>-NOTES.md, stages it, and
# commits with message format 'feat(domain): implement [Class] per Doc A laws'.
set -Eeuo pipefail

cd "$(dirname "$0")/.."

SPRINT="${1:?Usage: ./scripts/wrap-sprint.sh <sprint-number>}"
AUDIT_FILE=".parley_verification_audit"

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
