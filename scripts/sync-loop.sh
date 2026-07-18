#!/usr/bin/env bash
# Parley loop harness — mirror the local TDD phase to the milestone issue.
#
# The machine-enforced phase lives in .parley_sprint_scope (offline,
# deterministic). This script mirrors it to a phase-red/phase-green label on
# the given issue so GitHub stays an accurate dashboard. Mirroring is
# one-way: labels never drive the gate.
#
# Usage: ./scripts/sync-loop.sh <issue-number>
set -Eeuo pipefail

cd "$(dirname "$0")/.."

ISSUE="${1:?Usage: ./scripts/sync-loop.sh <issue-number>}"
PHASE=$(sed -n 's/^phase: *//p' .parley_sprint_scope | head -1)

case "$PHASE" in
  red)   ADD="phase-red";   REMOVE="phase-green" ;;
  green) ADD="phase-green"; REMOVE="phase-red" ;;
  *) echo "Unknown phase '$PHASE' in .parley_sprint_scope" >&2; exit 1 ;;
esac

gh issue edit "$ISSUE" --add-label "$ADD" --remove-label "$REMOVE" >/dev/null
echo "🔄 Issue #$ISSUE labeled $ADD (mirror of local phase '$PHASE')."
