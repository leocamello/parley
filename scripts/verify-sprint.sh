#!/usr/bin/env bash
# Parley loop harness — unified verification gate.
#
# Phase 1: deterministic hard-ban linters (AGENTS.md §2). Exit 101-104.
# Phase 2: axiomatic SUnit suite via scripts/run-tests.st on gst 3.2.5.
#
# gst 3.2.5 exits 0 even on parse errors and unhandled fileIn exceptions,
# so passing requires BOTH exit code 0 AND the 'PARLEY-VERIFY: PASS' sentinel.
#
# Circuit breaker: consecutive failures are counted in .parley_loop_state.
# At MAX_SPINS the harness refuses to run (exit 100) until a HUMAN runs:
#   ./scripts/verify-sprint.sh --reset
#
# Usage:
#   ./scripts/verify-sprint.sh            # lint + test with default seed
#   ./scripts/verify-sprint.sh --seed N   # lint + test with explicit seed
#   ./scripts/verify-sprint.sh --reset    # HUMAN ONLY: reset circuit breaker
set -Eeuo pipefail

cd "$(dirname "$0")/.."

STATE_FILE=".parley_loop_state"
MAX_SPINS=3
SEED="${PARLEY_SEED:-20260718}"

# The banned legacy name is assembled dynamically so this linter never
# contains the literal it is banning.
BANNED_NAME="g""pm"

if [[ "${1:-}" == "--reset" ]]; then
  rm -f "$STATE_FILE"
  echo "🔓 Circuit breaker reset by human operator."
  exit 0
fi

if [[ "${1:-}" == "--seed" ]]; then
  SEED="${2:?--seed requires a value}"
fi

read_state() {
  if [[ -f "$STATE_FILE" ]]; then
    SPIN_COUNT=$(sed -n '1p' "$STATE_FILE")
    LAST_HASH=$(sed -n '2p' "$STATE_FILE")
  else
    SPIN_COUNT=0
    LAST_HASH=""
  fi
  [[ "$SPIN_COUNT" =~ ^[0-9]+$ ]] || SPIN_COUNT=0
}

write_state() { # $1 = count, $2 = failure hash
  printf '%s\n%s\n' "$1" "$2" > "$STATE_FILE"
}

fail_hard_ban() { # $1 = exit code, $2.. = message lines
  local code="$1"; shift
  {
    echo "<hard_ban_violation exit_code=\"$code\">"
    printf '%s\n' "$@"
    echo "</hard_ban_violation>"
  } >&2
  write_state $((SPIN_COUNT + 1)) "hard-ban-$code"
  exit "$code"
}

read_state

if (( SPIN_COUNT >= MAX_SPINS )); then
  {
    echo "🛑 CIRCUIT BREAKER TRIPPED: $MAX_SPINS consecutive verification failures."
    echo "You are forbidden from editing code or running further commands."
    echo "STOP and present to the human user: the failing law or ambiguity,"
    echo "the approaches attempted, and the architectural question to resolve."
    echo "(Human operators may reset with: ./scripts/verify-sprint.sh --reset)"
  } >&2
  exit 100
fi

echo "🛡️  Phase 1: Parley hard-ban guardrails..."

# Ban 101 — the legacy name must not appear anywhere in the codebase.
if MATCHES=$(grep -rni "$BANNED_NAME" src/ tests/ scripts/ 2>/dev/null); then
  fail_hard_ban 101 \
    "DEFECT: Prohibited legacy name '$BANNED_NAME' found. The project's only name is Parley." \
    "$MATCHES"
fi

# Ban 102 — never shadow or use the kernel class Interval in the domain model.
if MATCHES=$(grep -rnE '\bInterval\b' src/domain/ 2>/dev/null); then
  fail_hard_ban 102 \
    "DEFECT: Kernel class 'Interval' referenced in src/domain/. The version span class is 'VersionRange'." \
    "$MATCHES"
fi

# Ban 103 — no compilation/evaluation pathways anywhere in src/.
if MATCHES=$(grep -rnE '\bevaluate:|\bCompiler\b|\bdoIt\b|compile:' src/ 2>/dev/null); then
  fail_hard_ban 103 \
    "DEFECT: Prohibited runtime compilation or evaluation pathway detected." \
    "Third-party content is read ONLY by the literals-only reader; nothing reaches the compiler." \
    "$MATCHES"
fi

# Ban 104 — zero public setters in the domain model.
# Flags the canonical setter shape (selector name == assigned variable name),
# including the usual multiline layout:  name: aName [ name := aName ]
if MATCHES=$(grep -rPzl '\b(\w+):\s*(\w+)\s*\[\s*\1\s*:=\s*\2\s*\.?\s*\]' src/domain/ 2>/dev/null); then
  fail_hard_ban 104 \
    "DEFECT: Public mutation setter detected in src/domain/ (files listed below)." \
    "All domain objects are immutable: class-side constructors validate and normalize;" \
    "every operation answers a new instance." \
    "$MATCHES"
fi

echo "✅ Phase 1 passed: hard bans clear."
echo "🧪 Phase 2: Axiomatic SUnit suite on gst 3.2.5 (seed=$SEED)..."

set +e
TEST_OUTPUT=$(PARLEY_SEED="$SEED" gst -q scripts/run-tests.st 2>&1)
TEST_EXIT_CODE=$?
set -e

# gst exit codes are unreliable on fileIn errors; require the PASS sentinel too.
if [[ $TEST_EXIT_CODE -eq 0 ]] && grep -q '^PARLEY-VERIFY: PASS' <<< "$TEST_OUTPUT"; then
  echo "$TEST_OUTPUT"
  echo "🎉 Verification passed."
  rm -f "$STATE_FILE"
  exit 0
fi

FAILURE_HASH=$(sha1sum <<< "$TEST_OUTPUT" | cut -d' ' -f1)
if [[ -n "$LAST_HASH" && "$FAILURE_HASH" == "$LAST_HASH" ]]; then
  # Identical failure twice in a row: the last fix changed nothing. Fast-trip.
  NEW_SPIN=$MAX_SPINS
else
  NEW_SPIN=$((SPIN_COUNT + 1))
fi
write_state "$NEW_SPIN" "$FAILURE_HASH"

{
  echo "<execution_feedback status=\"FAILED\" exit_code=\"$TEST_EXIT_CODE\" spin=\"$NEW_SPIN\" max_spins=\"$MAX_SPINS\" seed=\"$SEED\">"
  # Reduce output: sentinel lines, per-test verdicts, and the first error
  # region (parse errors / MNU backtraces), truncated to protect attention.
  grep -E '^PARLEY-(VERIFY|SEED|LOAD|FAILURE|ERROR):' <<< "$TEST_OUTPUT" || true
  awk '
    /parse error|did not understand|error:/ { flag=1 }
    flag { print; if (++lines >= 15) { print "--- [trace truncated] ---"; exit } }
  ' <<< "$TEST_OUTPUT"
  echo "</execution_feedback>"
  echo "⚠️  Verification failed. Spin counter: $NEW_SPIN/$MAX_SPINS."
} >&2

exit $(( TEST_EXIT_CODE == 0 ? 1 : TEST_EXIT_CODE ))
