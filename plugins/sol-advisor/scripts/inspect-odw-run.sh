#!/bin/sh
# Emit only allowlisted routing evidence for one complete fresh ODW v0.2.0 run.

set -eu

usage() {
  cat <<'EOF'
Usage: inspect-odw-run.sh [--sessions-dir DIR] /absolute/project/.odw/WORKFLOW/runs/RUN_ID

Validate one complete fresh ODW v0.2.0 run and emit only agent ids, Codex thread ids,
models, and efforts. Without --sessions-dir, use "$CODEX_HOME/sessions" when
CODEX_HOME is set, otherwise "$HOME/.codex/sessions".
EOF
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "the jq dependency is unavailable."

sessions_dir=''
case "$#" in
  1)
    run_dir=$1
    ;;
  3)
    [ "$1" = "--sessions-dir" ] || {
      usage >&2
      exit 2
    }
    [ -n "$2" ] || fail "--sessions-dir requires a non-empty directory."
    sessions_dir=$2
    run_dir=$3
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

case "$run_dir" in
  /*) ;;
  *) fail "run directory must be an absolute canonical path." ;;
esac
[ -d "$run_dir" ] && [ ! -L "$run_dir" ] || fail "run directory is unavailable or unsafe."
physical_run_dir=$(CDPATH= cd "$run_dir" && pwd -P) || fail "run directory cannot be resolved."
[ "$physical_run_dir" = "$run_dir" ] || fail "run directory must not contain symlinks, dot segments, or a trailing slash."

run_id=$(basename "$run_dir")
runs_dir=$(dirname "$run_dir")
workflow_dir=$(dirname "$runs_dir")
odw_dir=$(dirname "$workflow_dir")
workflow_name=$(basename "$workflow_dir")
[ "$(basename "$runs_dir")" = runs ] || fail "run directory is not below an ODW runs directory."
[ "$(basename "$odw_dir")" = .odw ] || fail "run directory is not below .odw/WORKFLOW/runs."
printf '%s\n' "$run_id" | LC_ALL=C grep -Eq '^run-[A-Za-z0-9][A-Za-z0-9._-]*$' || fail "invalid ODW run id."
printf '%s\n' "$workflow_name" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' || fail "invalid ODW workflow name."

if find "$run_dir" -type l -print 2>/dev/null | grep -q .; then
  fail "ODW run contains a symlink."
fi

script_file=$run_dir/script.js
events_file=$run_dir/events.jsonl
journal_file=$run_dir/journal.jsonl
agents_dir=$run_dir/agents
for required_file in "$script_file" "$events_file" "$journal_file"; do
  [ -f "$required_file" ] && [ ! -L "$required_file" ] || fail "ODW run is missing a required regular artifact."
done
[ -d "$agents_dir" ] && [ ! -L "$agents_dir" ] || fail "ODW run is missing its agents directory."

if [ -z "$sessions_dir" ]; then
  if [ -n "${CODEX_HOME-}" ]; then
    sessions_dir=$CODEX_HOME/sessions
  else
    [ -n "${HOME-}" ] || fail "HOME is unset and CODEX_HOME was not supplied; pass --sessions-dir explicitly."
    sessions_dir=$HOME/.codex/sessions
  fi
fi
[ -d "$sessions_dir" ] || fail "sessions directory is unavailable."

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in
  /*) ;;
  *) tmp_base=/tmp ;;
esac
tmp_dir=''
cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    case "$tmp_dir" in
      "$tmp_base"/sol-advisor-odw.*) rm -rf "$tmp_dir" ;;
      *) printf '%s\n' "ERROR: refusing cleanup of unexpected temporary directory." >&2 ;;
    esac
  fi
}
trap cleanup 0 HUP INT TERM
tmp_dir=$(mktemp -d "$tmp_base/sol-advisor-odw.XXXXXX") || fail "could not create a temporary verification directory."

event_summary=$tmp_dir/event-summary.json
if ! jq -ce -s --arg expected_run_id "$run_id" '
  def positive_integer: type == "number" and . > 0 and . == floor;
  [ .[] | select(.type == "run_start") ] as $run_starts |
  [ .[] | select(.type == "run_end") ] as $run_ends |
  [ .[] | select(.type == "workflow_start") ] as $workflow_starts |
  [ .[] | select(.type == "workflow_end") ] as $workflow_ends |
  [ .[] | select(.type == "agent_start") ] as $starts |
  [ .[] | select(.type == "agent_end") ] as $ends |
  if ($run_starts | length) != 1 or ($run_ends | length) != 1 then
    error("missing or ambiguous run lifecycle")
  elif $run_starts[0].runId != $expected_run_id or $run_ends[0].runId != $expected_run_id then
    error("run id mismatch")
  elif $run_ends[0].ok != true or $run_ends[0].failedAgents != 0 or $run_ends[0].failedWorkflows != 0 then
    error("run did not complete cleanly")
  elif ($workflow_starts | length) != ($workflow_ends | length) or any($workflow_ends[]; .ok != true) then
    error("nested workflow lifecycle is incomplete")
  elif ($starts | length) == 0 or ($ends | length) != ($starts | length) then
    error("agent lifecycle is incomplete")
  elif any($starts[]; (.agentId | positive_integer) | not) or any($ends[]; (.agentId | positive_integer) | not) then
    error("invalid agent id")
  elif ($starts | map(.agentId) | unique | length) != ($starts | length) then
    error("duplicate agent start")
  elif ($ends | map(.agentId) | unique | length) != ($ends | length) then
    error("duplicate agent end")
  elif any($starts[]; .cached != false) or any($ends[]; .cached != false) then
    error("cached agent is not accepted")
  elif any($ends[]; .ok != true or .skipped == true) then
    error("failed or skipped agent")
  elif any($starts[]; .agentId as $id | ([ $ends[] | select(.agentId == $id) ] | length) != 1) then
    error("started agent is unaccounted for")
  elif any($ends[]; .agentId as $id | ([ $starts[] | select(.agentId == $id) ] | length) != 1) then
    error("ended agent has no start")
  else
    {run_id: $expected_run_id, agent_ids: ($starts | map(.agentId) | sort)}
  end
' "$events_file" > "$event_summary" 2>/dev/null; then
  fail "ODW events are missing, malformed, cached, failed, partial, or inconsistent."
fi

if ! jq -e -s --slurpfile events "$events_file" '
  [ $events[] | select(.type == "agent_start") | .agentId ] as $ids |
  (length == ($ids | length)) and
  ([ .[] | .index ] | sort) == ($ids | sort) and
  all(.[]; .cached == false)
' "$journal_file" >/dev/null 2>&1; then
  fail "ODW journal does not account for every fresh agent."
fi

agent_count=$(jq -r '.agent_ids | length' "$event_summary")
find "$agents_dir" -mindepth 1 -maxdepth 1 -print > "$tmp_dir/agent-entries"
entry_count=$(awk 'END { print NR + 0 }' "$tmp_dir/agent-entries")
[ "$entry_count" -eq "$agent_count" ] || fail "ODW trace inventory does not match started agents."
jq -r '.agent_ids[]' "$event_summary" > "$tmp_dir/agent-ids"
: > "$tmp_dir/evidence.jsonl"

while IFS= read -r agent_id; do
  trace_file=$agents_dir/agent-$agent_id.jsonl
  [ -f "$trace_file" ] && [ ! -L "$trace_file" ] || fail "ODW agent trace is missing or unsafe."

  if ! trace_evidence=$(jq -ce '
    (.args // null) as $args |
    [ .events[]? | select(.type == "thread.started") | .thread_id ] as $threads |
    [ .events[]? | select(.type == "turn.completed") ] as $completed |
    [ .events[]? | select(.type == "turn.failed" or .type == "error") ] as $failures |
    [ range(0; ($args | length)) as $i | select($args[$i] == "-m") | $args[$i + 1] ] as $models |
    [ $args[] | select(startswith("model_reasoning_effort=")) ] as $efforts |
    ($args | index("model_reasoning_effort=\"high\"")) as $effort_index |
    if .command != "codex" or ($args | type) != "array" or any($args[]; type != "string") then
      error("unexpected executor or arguments")
    elif $args[0] != "exec" or ([ $args[] | select(. == "--json") ] | length) != 1 then
      error("unexpected Codex invocation")
    elif $models != ["gpt-5.6-luna"] or any($args[]; startswith("--model") or startswith("model=")) then
      error("unexpected model selection")
    elif $efforts != ["model_reasoning_effort=\"high\""] or $effort_index == 0 or $args[$effort_index - 1] != "-c" then
      error("unexpected reasoning effort")
    elif .exitCode != 0 or .isError != false or .resultSubtype != "success" then
      error("agent process did not complete successfully")
    elif ($threads | length) != 1 or ($threads[0] | test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$") | not) then
      error("missing or ambiguous thread id")
    elif ($completed | length) != 1 or ($failures | length) != 0 then
      error("Codex turn did not complete cleanly")
    else
      {thread_id: $threads[0]}
    end
  ' "$trace_file" 2>/dev/null); then
    fail "ODW agent trace has invalid executor, routing, thread, or completion evidence."
  fi

  thread_id=$(printf '%s\n' "$trace_evidence" | jq -r '.thread_id')
  matches_file=$tmp_dir/matches-$agent_id
  if ! find "$sessions_dir" -type f -name "rollout-*-$thread_id.jsonl" -print > "$matches_file"; then
    fail "could not enumerate Codex rollout filenames."
  fi
  match_count=$(awk 'END { print NR + 0 }' "$matches_file")
  [ "$match_count" -eq 1 ] || fail "Codex rollout match is missing or ambiguous."
  IFS= read -r rollout_file < "$matches_file" || fail "could not read the matched rollout filename."
  [ -f "$rollout_file" ] || fail "matched Codex rollout is unavailable."

  if ! runtime_evidence=$(jq -ce -s --arg expected_thread_id "$thread_id" '
    [ .[] | select(.type == "session_meta") | .payload ] as $sessions |
    [ .[] | select(.type == "turn_context") | .payload ] as $turns |
    [ $turns[] | .model ] as $models |
    [ $turns[] | .effort ] as $efforts |
    if ($sessions | length) != 1 or ($turns | length) == 0 then
      error("missing or ambiguous runtime metadata")
    elif $sessions[0].id != $expected_thread_id then
      error("runtime thread id mismatch")
    elif $sessions[0].parent_thread_id != null or $sessions[0].agent_role != null or $sessions[0].agent_path != null then
      error("runtime is not a standalone ODW Codex session")
    elif any($models[]; type != "string" or length == 0) or any($efforts[]; type != "string" or length == 0) then
      error("missing model or effort")
    elif ($models | unique) != ["gpt-5.6-luna"] then
      error("unexpected or conflicting runtime model")
    elif ($efforts | unique) != ["high"] then
      error("unexpected or conflicting runtime effort")
    else
      {thread_id: $expected_thread_id, model: $models[0], effort: $efforts[0]}
    end
  ' "$rollout_file" 2>/dev/null); then
    fail "Codex rollout is missing, ambiguous, invalid, or inconsistent routing metadata."
  fi

  printf '%s\n' "$runtime_evidence" | jq -c --argjson agent_id "$agent_id" '
    {agent_id: $agent_id, thread_id, model, effort}
  ' >> "$tmp_dir/evidence.jsonl"
done < "$tmp_dir/agent-ids"

if ! jq -ce -s --arg run_id "$run_id" '
  . as $agents |
  if ($agents | map(.thread_id) | unique | length) != ($agents | length) then
    error("duplicate thread id")
  else
    {run_id: $run_id, agent_count: ($agents | length), agents: ($agents | sort_by(.agent_id))}
  end
' "$tmp_dir/evidence.jsonl"; then
  fail "ODW routing evidence could not be summarized safely."
fi
