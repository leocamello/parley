#!/usr/bin/env bash
# Honesty gate for docs/method/findings.md, in the spirit of wrap-sprint.sh's
# traceability gate: every finding must cite resolvable evidence from the sprint
# it covers. A citation is a commit sha, an issue reference, a sprint-notes path,
# a decision-log reference, or a src/tests/scripts/docs path. General musing
# about process cites nothing and fails here.
#
# THE CHECK IS SCOPED TO THE Evidence FIELD, not to the whole entry. A sha
# mentioned under "Change adopted" must not satisfy a claim made under
# "Evidence", or the gate collapses into "does an **Evidence** heading exist"
# — which the format already makes obvious, and which would pass while proving
# nothing. A gate that passes while proving nothing is worse than no gate: it
# converts an unchecked claim into a checked-looking one. Same disease as a
# test file that does not fail but silently fails to load, which is why
# verify-sprint.sh grew its load-integrity check.
set -euo pipefail

FINDINGS="${1:-docs/method/findings.md}"
if [[ ! -f "$FINDINGS" ]]; then
  echo "🛑 No $FINDINGS" >&2
  exit 1
fi

CITATION='([0-9a-f]{7,40}|#[0-9]+|sprint-[0-9]{2}-notes|§8 decisions? [0-9]+|(src|tests|scripts|docs)/[A-Za-z0-9_/.-]+)'
MISSING=0
TOTAL=0

# Each finding is one block, from its heading to the next.
while IFS= read -r -d '' BLOCK; do
  ID=$(head -1 <<<"$BLOCK")
  # A plain `[[ ... ]] && continue` is a complete command: when the test is
  # false the list returns 1 and `set -e` kills the script. A gate that can
  # exit non-zero for an unrelated reason is the defect it exists to catch.
  if [[ -z "${ID// }" ]]; then
    continue
  fi
  TOTAL=$((TOTAL + 1))

  if ! grep -qE '^\*\*Evidence' <<<"$BLOCK"; then
    echo "🛑 $ID: no **Evidence** field." >&2
    MISSING=1
    continue
  fi

  # The Evidence field alone: from its heading up to the next field heading.
  EV=$(awk '/^\*\*Evidence/{f=1} f&&/^\*\*(What caught it|Change adopted|Status)/{f=0} f' <<<"$BLOCK")
  if ! grep -qE "$CITATION" <<<"$EV"; then
    echo "🛑 $ID: Evidence cites nothing resolvable." >&2
    echo "   Need a commit sha, #issue, sprint-NN-notes, a §8 decision, or a src/tests path." >&2
    MISSING=1
  fi
done < <(awk '/^#+ F[0-9]+/{if(n)printf "%s\0",b; n=1; b=""} n{b=b $0 "\n"} END{if(n)printf "%s\0",b}' "$FINDINGS")

if [[ $TOTAL -eq 0 ]]; then
  echo "🛑 $FINDINGS declares no findings (expected headings like '## F1 — ...')." >&2
  exit 1
fi

if [[ $MISSING -ne 0 ]]; then
  echo "Every finding cites the sprint evidence it came from." >&2
  exit 1
fi

echo "✅ Method findings: $TOTAL entries, every one cites resolvable evidence."
