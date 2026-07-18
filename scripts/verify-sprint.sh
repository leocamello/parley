#!/usr/bin/env bash
# Parley loop harness — unified verification gate (phase-aware).
#
# Phase 1: deterministic hard-ban linters (AGENTS.md §2). Exit 101-104.
# Phase 2: axiomatic SUnit suite via scripts/run-tests.st on gst 3.2.5.
#
# TDD phases (read from the 'phase:' line of .parley_sprint_scope; the
# human operator flips red -> green after reviewing the tests):
#   green (default): the suite must PASS ('PARLEY-VERIFY: PASS' + exit 0).
#   red:  the suite must FAIL for the right reasons — every test file loads
#         (PARLEY-TESTFILE per file), no parse errors anywhere, tests actually
#         ran (run>0) and failed. MNU on a not-yet-implemented class counts
#         as a valid red; a passing suite in red phase is a defect (the new
#         tests test nothing).
#
# gst 3.2.5 exits 0 even on parse errors and unhandled fileIn exceptions,
# so verdicts are based on the PARLEY-VERIFY sentinel, never exit codes alone.
#
# Circuit breaker: consecutive failures are counted in .parley_loop_state.
# The counter is PROGRESS-AWARE: a failing run whose passed= count is higher
# than the previous run's resets the streak to 1 (honest incremental progress
# never trips the breaker). An identical failure twice in a row fast-trips.
# At MAX_SPINS the harness refuses to run (exit 100) until a HUMAN runs:
#   ./scripts/verify-sprint.sh --reset
#
# Usage:
#   ./scripts/verify-sprint.sh                 # phase from .parley_sprint_scope
#   ./scripts/verify-sprint.sh --phase red     # explicit phase override
#   ./scripts/verify-sprint.sh --seed N        # explicit seed
#   ./scripts/verify-sprint.sh --reset         # HUMAN ONLY: reset breaker
set -Eeuo pipefail

cd "$(dirname "$0")/.."

STATE_FILE=".parley_loop_state"
SCOPE_FILE=".parley_sprint_scope"
MAX_SPINS=3
SEED="${PARLEY_SEED:-20260718}"

# The banned legacy name is assembled dynamically so this linter never
# contains the literal it is banning.
BANNED_NAME="g""pm"

PHASE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      rm -f "$STATE_FILE"
      echo "🔓 Circuit breaker reset by human operator."
      exit 0 ;;
    --seed)  SEED="${2:?--seed requires a value}"; shift 2 ;;
    --phase) PHASE="${2:?--phase requires red|green}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PHASE" && -f "$SCOPE_FILE" ]]; then
  PHASE=$(sed -n 's/^phase: *//p' "$SCOPE_FILE" | head -1)
fi
PHASE="${PHASE:-green}"
if [[ "$PHASE" != "red" && "$PHASE" != "green" ]]; then
  echo "Invalid phase '$PHASE' (expected red or green)." >&2
  exit 2
fi

read_state() {
  if [[ -f "$STATE_FILE" ]]; then
    SPIN_COUNT=$(sed -n '1p' "$STATE_FILE")
    LAST_HASH=$(sed -n '2p' "$STATE_FILE")
    LAST_PASSED=$(sed -n '3p' "$STATE_FILE")
  else
    SPIN_COUNT=0
    LAST_HASH=""
    LAST_PASSED=""
  fi
  [[ "$SPIN_COUNT" =~ ^[0-9]+$ ]] || SPIN_COUNT=0
  [[ "$LAST_PASSED" =~ ^[0-9]+$ ]] || LAST_PASSED=""
}

write_state() { # $1 = count, $2 = failure hash, $3 = passed count (may be empty)
  printf '%s\n%s\n%s\n' "$1" "$2" "${3:-}" > "$STATE_FILE"
}

fail_hard_ban() { # $1 = exit code, $2.. = message lines
  local code="$1"; shift
  {
    echo "<hard_ban_violation exit_code=\"$code\">"
    printf '%s\n' "$@"
    echo "</hard_ban_violation>"
  } >&2
  write_state $((SPIN_COUNT + 1)) "hard-ban-$code" "$LAST_PASSED"
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
echo "🧪 Phase 2: Axiomatic SUnit suite on gst 3.2.5 (phase=$PHASE seed=$SEED)..."

set +e
TEST_OUTPUT=$(PARLEY_SEED="$SEED" gst -q scripts/run-tests.st 2>&1)
TEST_EXIT_CODE=$?
set -e

VERIFY_LINE=$(grep '^PARLEY-VERIFY:' <<< "$TEST_OUTPUT" | head -1 || true)
PARSE_ERRORS=$(grep -c 'parse error' <<< "$TEST_OUTPUT" || true)

verdict_pass=false
red_reason=""
if [[ "$PHASE" == "green" ]]; then
  # Green: exit 0 AND the PASS sentinel.
  if [[ $TEST_EXIT_CODE -eq 0 ]] && grep -q '^PARLEY-VERIFY: PASS' <<< "$TEST_OUTPUT"; then
    verdict_pass=true
  fi
else
  # Red: the suite must fail for the RIGHT reasons.
  RUN=$(sed -n 's/.* run=\([0-9]*\).*/\1/p' <<< "$VERIFY_LINE")
  FAILED=$(sed -n 's/.* failed=\([0-9]*\).*/\1/p' <<< "$VERIFY_LINE")
  ERRORS=$(sed -n 's/.* errors=\([0-9]*\).*/\1/p' <<< "$VERIFY_LINE")
  # Every .st under tests trees must have produced a PARLEY-TESTFILE marker.
  EXPECTED_TESTFILES=$(find tests -name '*.st' 2>/dev/null | wc -l)
  LOADED_TESTFILES=$(grep -c '^PARLEY-TESTFILE:' <<< "$TEST_OUTPUT" || true)
  if [[ "$PARSE_ERRORS" -gt 0 ]]; then
    red_reason="parse errors present — red must fail on missing behavior, not broken syntax"
  elif [[ "$LOADED_TESTFILES" -lt "$EXPECTED_TESTFILES" ]]; then
    red_reason="only $LOADED_TESTFILES of $EXPECTED_TESTFILES test files loaded cleanly"
  elif [[ -z "$RUN" || "$RUN" -eq 0 ]]; then
    red_reason="no tests ran — red requires runnable failing tests"
  elif [[ "$((FAILED + ERRORS))" -eq 0 ]]; then
    red_reason="suite PASSED — new tests must fail before implementation (they currently test nothing)"
  else
    verdict_pass=true
  fi
fi

if $verdict_pass; then
  echo "$TEST_OUTPUT"
  if [[ "$PHASE" == "red" ]]; then
    echo "🔴 Red gate satisfied: tests load cleanly and fail on missing behavior."
    echo "   Awaiting HUMAN review of the tests; the operator flips 'phase:' to green in $SCOPE_FILE."
  else
    echo "🎉 Verification passed."
  fi
  rm -f "$STATE_FILE"
  exit 0
fi

FAILURE_HASH=$(sha1sum <<< "$TEST_OUTPUT" | cut -d' ' -f1)
PASSED_NOW=$(sed -n 's/.* passed=\([0-9]*\).*/\1/p' <<< "$VERIFY_LINE")
PROGRESS_NOTE=""
if [[ -n "$LAST_HASH" && "$FAILURE_HASH" == "$LAST_HASH" ]]; then
  # Identical failure twice in a row: the last fix changed nothing. Fast-trip.
  NEW_SPIN=$MAX_SPINS
elif [[ "$PHASE" == "green" && -n "$PASSED_NOW" && -n "$LAST_PASSED" \
        && "$PASSED_NOW" -gt "$LAST_PASSED" ]]; then
  # Progress-aware: more tests pass than last run — honest incremental work.
  # Reset the streak so stepwise implementation never trips the breaker.
  NEW_SPIN=1
  PROGRESS_NOTE=" (progress detected: passed $LAST_PASSED -> $PASSED_NOW; spin streak reset)"
else
  NEW_SPIN=$((SPIN_COUNT + 1))
fi
write_state "$NEW_SPIN" "$FAILURE_HASH" "${PASSED_NOW:-$LAST_PASSED}"

{
  echo "<execution_feedback status=\"FAILED\" phase=\"$PHASE\" exit_code=\"$TEST_EXIT_CODE\" spin=\"$NEW_SPIN\" max_spins=\"$MAX_SPINS\" seed=\"$SEED\">"
  [[ -n "$red_reason" ]] && echo "<red_gate_violation>$red_reason</red_gate_violation>"
  # Reduce output: sentinel lines, per-test verdicts, and the first error
  # region (parse errors / MNU backtraces), truncated to protect attention.
  grep -E '^PARLEY-(VERIFY|SEED|LOAD|TESTFILE|FAILURE|ERROR):' <<< "$TEST_OUTPUT" || true
  awk '
    /parse error|did not understand|error:/ { flag=1 }
    flag { print; if (++lines >= 15) { print "--- [trace truncated] ---"; exit } }
  ' <<< "$TEST_OUTPUT"
  echo "</execution_feedback>"
  echo "⚠️  Verification failed. Spin counter: $NEW_SPIN/$MAX_SPINS.$PROGRESS_NOTE"
} >&2

exit $(( TEST_EXIT_CODE == 0 ? 1 : TEST_EXIT_CODE ))
