#!/bin/bash
# Marty SessionStart Hook
# Reads QA_HANDOFF.md and checkpoint state to inject resume context
# when the coordinator starts a new session after a disconnect.

set -euo pipefail

# Consume stdin (hook input JSON)
cat > /dev/null

HANDOFF_FILE="QA_HANDOFF.md"
CHECKPOINT_FILE=".marty-checkpoint.json"

# No checkpoint = fresh session, nothing to inject
if [ ! -f "$CHECKPOINT_FILE" ]; then
  echo '{}'
  exit 0
fi

CHECKPOINT=$(cat "$CHECKPOINT_FILE")
STATUS=$(grep -oP '(?<=status: )\S+' "$HANDOFF_FILE" 2>/dev/null || echo "idle")
COMMIT=$(grep -oP '(?<=commit: )\S+' "$HANDOFF_FILE" 2>/dev/null || echo "—")

if [ "$STATUS" = "idle" ] || [ "$STATUS" = "—" ]; then
  echo '{}'
  exit 0
fi

# Build resume context from checkpoint + handoff state
SCOPE=$(echo "$CHECKPOINT" | grep -oP '"scope"\s*:\s*"\K[^"]+' || echo "unknown")
SPRINT=$(echo "$CHECKPOINT" | grep -oP '"sprint"\s*:\s*\K[0-9]+' || echo "?")
ITERATION=$(echo "$CHECKPOINT" | grep -oP '"iteration"\s*:\s*\K[0-9]+' || echo "1")

CONTEXT="RESUME: Previous session was interrupted. State recovered from checkpoint.
- Scope: ${SCOPE}
- Sprint: ${SPRINT}
- Iteration: ${ITERATION}
- QA_HANDOFF.md status: ${STATUS}
- Last commit: ${COMMIT}

Action required based on status:
- pending-qa: Run QA Reviewer on commit ${COMMIT}.
- pending-fix: Run Builder to fix QA findings, then re-QA.
- approved: Proceed to wrap-up.

Read QA_HANDOFF.md for full details before continuing."

echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":$(echo "$CONTEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}}"
