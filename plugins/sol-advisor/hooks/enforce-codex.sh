#!/bin/sh
set -eu

deny() {
  reason=$1
  jq -cn --arg reason "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

command -v jq >/dev/null 2>&1 || { printf '%s\n' 'Advisor requires jq for strict Codex enforcement.' >&2; exit 2; }
path_exists() { [ -e "$1" ] || [ -L "$1" ]; }
plugin_root=${PLUGIN_ROOT-}
case "$plugin_root" in /*) ;; *) deny "Advisor plugin root is unavailable." ;; esac
payload=$(jq -ce 'if type == "object" then . else error("invalid") end' 2>/dev/null) || deny "Advisor received malformed PreToolUse input."
printf '%s\n' "$payload" | jq -e '.hook_event_name == "PreToolUse"' >/dev/null 2>&1 || deny "Advisor received the wrong hook event."
tool=$(printf '%s\n' "$payload" | jq -r '.tool_name // empty')
case "$tool" in
  collaborationspawn_agent|spawn_agent|Agent|mcp__open_dynamic_workflows__workflow|mcp__open-dynamic-workflows__workflow) ;;
  *) exit 0 ;;
esac
runtime_id=$(printf '%s\n' "$payload" | jq -r '.session_id // empty')
printf '%s\n' "$runtime_id" | LC_ALL=C grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' || deny "Advisor could not identify the primary Codex session."

if [ "${ODW_HOST-}" = codex ] && [ "${ODW_REQUIRE_CWD-}" = 1 ]; then
  case "$tool" in
    collaborationspawn_agent|spawn_agent|Agent|mcp__open_dynamic_workflows__workflow|mcp__open-dynamic-workflows__workflow)
      deny "Advisor ODW workers cannot spawn native subagents or nested workflows."
      ;;
  esac
  exit 0
fi

if [ -n "${ADVISOR_CONFIG_HOME-}" ]; then config_dir=$ADVISOR_CONFIG_HOME
elif [ -n "${XDG_CONFIG_HOME-}" ]; then config_dir=$XDG_CONFIG_HOME/advisor
else [ -n "${HOME-}" ] || deny "Advisor configuration home is unavailable."; config_dir=$HOME/.config/advisor
fi
case "$config_dir" in /*) ;; *) config_dir=$(pwd -P)/$config_dir ;; esac
sessions=$config_dir/sessions
if ! path_exists "$config_dir" || [ -L "$config_dir" ] || [ ! -d "$config_dir" ] ||
  ! path_exists "$sessions" || [ -L "$sessions" ] || [ ! -d "$sessions" ]; then
  deny "Advisor configuration or session policy directory is unavailable or unsafe."
fi
snapshot=$sessions/$runtime_id.json
inspector=$plugin_root/scripts/inspect-codex-runtime.sh
[ -f "$inspector" ] && [ ! -L "$inspector" ] || deny "Advisor Codex runtime inspector is unavailable."
if ! sh "$inspector" --mode native --policy "$snapshot" --role advisor "$runtime_id" >/dev/null 2>&1; then
  deny "Advisor denied the tool because the primary runtime does not match its immutable session policy."
fi

case "$tool" in collaborationspawn_agent|spawn_agent|Agent)
  if ! printf '%s\n' "$payload" | jq -e '
    (.tool_input | type) == "object" and .tool_input.agent_type == "advisor_grunt" and
    .tool_input.fork_turns == "none" and (.tool_input | has("model") | not) and
    (.tool_input | has("reasoning_effort") | not)
  ' >/dev/null 2>&1; then
    deny "Advisor permits only agent_type=advisor_grunt, fork_turns=none, and no per-spawn model or effort override."
  fi
  ;;
esac
