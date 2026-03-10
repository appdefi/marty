#!/bin/bash
# Marty Stop Hook
# Blocks the coordinator from stopping if the QA loop is still in progress.
# Cleans up the checkpoint file when the loop completes.

set -euo pipefail

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | grep -o '"stop_hook_active":\s*true' || true)

# If we already blocked once and the agent is still running, let it decide
if [ -n "$STOP_HOOK_ACTIVE" ]; then
  echo '{}'
  exit 0
fi

HANDOFF_FILE="QA_HANDOFF.md"
CHECKPOINT_FILE=".marty-checkpoint.json"

if [ ! -f "$HANDOFF_FILE" ]; then
  rm -f "$CHECKPOINT_FILE"
  echo '{}'
  exit 0
fi

STATUS=$(grep -oP '(?<=status: )\S+' "$HANDOFF_FILE" 2>/dev/null || echo "idle")

case "$STATUS" in
  pending-qa)
    echo '{"hookSpecificOutput":{"hookEventName":"Stop","decision":"block","reason":"QA_HANDOFF.md has status: pending-qa. Run the QA Reviewer subagent to review the commit before stopping."}}'
    ;;
  pending-fix)
    echo '{"hookSpecificOutput":{"hookEventName":"Stop","decision":"block","reason":"QA_HANDOFF.md has status: pending-fix. Run the Builder subagent to fix the QA findings before stopping."}}'
    ;;
  approved|idle|*)
    rm -f "$CHECKPOINT_FILE"
    echo '{}'
    ;;
esac
