#!/bin/sh
# Allow only Sol Advisor's role-pinned, fresh Luna / High child contract.

set -eu

reason='Sol Advisor requires agent_type=sol_advisor_luna_subagent, fork_turns=none, and no per-spawn model or reasoning_effort override.'

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$reason The jq dependency is unavailable." >&2
  exit 2
fi

payload=$(cat)
if printf '%s\n' "$payload" | jq -e '
  .hook_event_name == "PreToolUse" and
  .tool_name == "spawn_agent" and
  (.tool_input | type) == "object" and
  .tool_input.agent_type == "sol_advisor_luna_subagent" and
  .tool_input.fork_turns == "none" and
  (.tool_input | has("model") | not) and
  (.tool_input | has("reasoning_effort") | not)
' >/dev/null 2>&1; then
  exit 0
fi

jq -cn --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
