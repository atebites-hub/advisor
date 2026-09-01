#!/bin/sh
set -eu

fail() { printf '%s\n' "ERROR: $*" >&2; exit 1; }
path_exists() { [ -e "$1" ] || [ -L "$1" ]; }
valid_id() { printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; }
# GNU coreutils first: `stat -f` is --file-system, not BSD format.
file_mode() {
  if stat -c %a "$1" >/dev/null 2>&1; then
    stat -c %a "$1"
  else
    stat -f %Lp "$1"
  fi
}

usage() {
  printf '%s\n' \
    'Usage:' \
    '  inspect-codex-runtime.sh --mode native [--sessions-dir DIR] --policy SNAPSHOT --role advisor|grunt [--result FILE] THREAD_ID' \
    '  inspect-codex-runtime.sh --mode odw [--sessions-dir DIR] --route POLICY --result FILE THREAD_ID'
}

command -v jq >/dev/null 2>&1 || fail "jq is unavailable."

mode= role= policy= route= result= sessions_dir= thread_id=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode|--role|--policy|--route|--result|--sessions-dir)
      option=$1
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "$option requires a value."
      case "$2" in --*) fail "$option requires an explicit value." ;; esac
      case "$option" in
        --mode) [ -z "$mode" ] || fail "duplicate --mode."; mode=$2 ;;
        --role) [ -z "$role" ] || fail "duplicate --role."; role=$2 ;;
        --policy) [ -z "$policy" ] || fail "duplicate --policy."; policy=$2 ;;
        --route) [ -z "$route" ] || fail "duplicate --route."; route=$2 ;;
        --result) [ -z "$result" ] || fail "duplicate --result."; result=$2 ;;
        --sessions-dir) [ -z "$sessions_dir" ] || fail "duplicate --sessions-dir."; sessions_dir=$2 ;;
      esac
      shift 2 ;;
    --*) fail "unknown option: $1" ;;
    *) [ -z "$thread_id" ] || fail "extra positional argument: $1"; thread_id=$1; shift ;;
  esac
done

case "$mode" in native|odw) ;; '') fail "--mode is required." ;; *) fail "unknown mode: $mode" ;; esac
[ -n "$thread_id" ] && valid_id "$thread_id" || fail "THREAD_ID must be a lowercase UUID."
if [ -z "$sessions_dir" ]; then
  if [ -n "${CODEX_HOME-}" ]; then sessions_dir=$CODEX_HOME/sessions
  else [ -n "${HOME-}" ] || fail "HOME is unset; pass --sessions-dir."; sessions_dir=$HOME/.codex/sessions
  fi
fi
[ -d "$sessions_dir" ] && [ ! -L "$sessions_dir" ] || fail "sessions directory is unavailable or unsafe."

expected_model= expected_effort= expected_parent= output_role=
if [ "$mode" = native ]; then
  case "$role" in advisor|grunt) ;; *) fail "native mode requires --role advisor|grunt." ;; esac
  [ -n "$policy" ] || fail "native mode requires --policy."
  [ -z "$route" ] || fail "native mode does not accept --route."
  [ -f "$policy" ] && [ ! -L "$policy" ] && [ "$(file_mode "$policy")" = 600 ] || fail "policy snapshot is unavailable, unsafe, or not mode 600."
  snapshot=$(jq -ce '
    if type == "object" and keys == ["createdAt","host","policy","policyFingerprint","runtimeId","schemaVersion"] and
    .schemaVersion == 1 and .host == "codex" and
    (.runtimeId | type == "string" and test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")) and
    (.createdAt | type == "string" and length > 0) and
    (.policyFingerprint | type == "string" and test("^[a-f0-9]{64}$")) and
    (.policy | type == "object" and keys == ["advisorEffort","advisorModel","gruntEffort","gruntModel"] and
      all(.[]; type == "string" and length > 0))
    then {runtimeId,policy,policyFingerprint} else error("invalid snapshot") end
  ' "$policy" 2>/dev/null) || fail "policy snapshot schema is invalid."
  canonical=$(printf '%s\n' "$snapshot" | jq -c '{advisorModel:.policy.advisorModel,advisorEffort:.policy.advisorEffort,gruntModel:.policy.gruntModel,gruntEffort:.policy.gruntEffort}')
  recorded=$(printf '%s\n' "$snapshot" | jq -r '.policyFingerprint')
  [ "$(printf '%s' "$canonical" | shasum -a 256 | awk '{print $1}')" = "$recorded" ] || fail "policy snapshot fingerprint is invalid."
  expected_parent=$(printf '%s\n' "$snapshot" | jq -r '.runtimeId')
  if [ "$role" = advisor ]; then
    [ -z "$result" ] || fail "advisor inspection does not accept --result."
    [ "$thread_id" = "$expected_parent" ] || fail "advisor runtime does not match the snapshot."
    expected_model=$(printf '%s\n' "$snapshot" | jq -r '.policy.advisorModel')
    expected_effort=$(printf '%s\n' "$snapshot" | jq -r '.policy.advisorEffort')
    expected_parent=null
    output_role=advisor
  else
    [ -n "$result" ] || fail "grunt inspection requires --result."
    expected_model=$(printf '%s\n' "$snapshot" | jq -r '.policy.gruntModel')
    expected_effort=$(printf '%s\n' "$snapshot" | jq -r '.policy.gruntEffort')
    output_role=advisor_grunt
    [ -f "$result" ] && [ ! -L "$result" ] || fail "grunt result is unavailable or unsafe."
    jq -e --arg runtime "$thread_id" --arg parent "$expected_parent" '
      type == "object" and keys == ["parent_runtime_id","runtime_id","state"] and
      .runtime_id == $runtime and .parent_runtime_id == $parent and .state == "completed"
    ' "$result" >/dev/null 2>&1 || fail "grunt result is incomplete, failed, or does not match the child runtime."
  fi
else
  [ -z "$role$policy" ] || fail "ODW mode does not accept --role or --policy."
  [ -n "$route" ] && [ -n "$result" ] || fail "ODW mode requires --route and --result."
  [ -f "$route" ] && [ ! -L "$route" ] && [ "$(file_mode "$route")" = 600 ] || fail "ODW route is unavailable, unsafe, or not mode 600."
  route_json=$(jq -ce '
    if type == "object" and keys == ["executor","model","reasoningEffort"] and
    .executor == "codex" and all(.[]; type == "string" and length > 0)
    then . else error("invalid route") end
  ' "$route" 2>/dev/null) || fail "ODW route schema is invalid."
  expected_model=$(printf '%s\n' "$route_json" | jq -r '.model')
  expected_effort=$(printf '%s\n' "$route_json" | jq -r '.reasoningEffort')
  expected_parent=null
  output_role=odw
  [ -f "$result" ] && [ ! -L "$result" ] || fail "ODW result is unavailable or unsafe."
  jq -e --arg runtime "$thread_id" --arg model "$expected_model" --arg effort "$expected_effort" '
    type == "object" and .command == "codex" and .exitCode == 0 and .isError == false and .resultSubtype == "success" and
    .routing.runtimeId == $runtime and .routing.executor == "codex" and
    .routing.model == $model and .routing.reasoningEffort == $effort and
    ([.events[]? | select(.type == "thread.started") | .thread_id] == [$runtime]) and
    ([.events[]? | select(.type == "turn.completed")] | length) == 1 and
    ([.events[]? | select(.type == "turn.failed" or .type == "error")] | length) == 0
  ' "$result" >/dev/null 2>&1 || fail "ODW Codex result is failed, partial, or runtime-mismatched."
fi

tmp_base=${TMPDIR:-/tmp}; case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_base=$(CDPATH= cd "$tmp_base" && pwd -P)
matches=$(mktemp "$tmp_base/advisor-codex-rollout.XXXXXX") || fail "could not create match list."
cleanup() { case "${matches-}" in "$tmp_base"/advisor-codex-rollout.*) rm -f "$matches" ;; esac; }
trap cleanup 0 HUP INT TERM
find "$sessions_dir" -name "rollout-*-$thread_id.jsonl" -print > "$matches" || fail "could not enumerate rollout filenames."
[ "$(awk 'END {print NR+0}' "$matches")" -eq 1 ] || fail "rollout filename match is missing or ambiguous."
IFS= read -r rollout < "$matches" || fail "could not read rollout match."
[ -f "$rollout" ] && [ ! -L "$rollout" ] || fail "rollout is unavailable or unsafe."

jq -ce -s --arg runtime "$thread_id" --arg parent "$expected_parent" --arg role "$output_role" \
  --arg model "$expected_model" --arg effort "$expected_effort" '
  [ .[] | select(.type == "session_meta") | .payload ] as $sessions |
  [ .[] | select(.type == "turn_context") | .payload ] as $turns |
  [ $sessions[] | .id ] as $ids |
  [ $sessions[] | (.parent_thread_id // null) ] as $parents |
  [ $sessions[] | (if .agent_role? != null then .agent_role elif (.source | type) == "object" then (.source.subagent.thread_spawn.agent_role? // null) else null end) ] as $roles |
  [ $turns[] | .model ] as $models |
  [ $turns[] | .effort ] as $efforts |
  [ $turns[] | .cwd ] as $cwds |
  ([ .[] | select(.type == "event_msg") | .payload.type ] // []) as $events |
  ($events | map(select(. == "task_started")) | length) as $starts |
  ($events | map(select(. == "task_complete")) | length) as $completed |
  ($events | map(select(. == "task_failed" or . == "task_cancelled" or . == "task_timed_out" or . == "turn_aborted")) | length) as $failed |
  if ($sessions | length) == 0 or ($turns | length) == 0 then error("missing runtime metadata")
  elif ($ids | unique) != [$runtime] then error("runtime id mismatch")
  elif any($models[]; type != "string" or length == 0) or ($models | unique) != [$model] then error("model mismatch")
  elif any($efforts[]; type != "string" or length == 0) or ($efforts | unique) != [$effort] then error("effort mismatch")
  elif any($cwds[]; type != "string" or length == 0) or ($cwds | unique | length) != 1 then error("cwd mismatch")
  elif $failed != 0 or $starts == 0 then error("failed or incomplete lifecycle")
  elif $role == "advisor" and (($parents | unique) != [null] or ($roles | unique) != [null] or $completed >= $starts) then error("advisor is not a running root")
  elif $role == "advisor_grunt" and (($parents | unique) != [$parent] or ($roles | unique) != ["advisor_grunt"] or $completed != $starts) then error("grunt role parent or state mismatch")
  elif $role == "odw" and (($parents | unique) != [null] or ($roles | unique) != [null] or $completed != $starts) then error("ODW runtime is not a completed standalone root")
  else {runtime_id:$runtime,parent_runtime_id:(if $parent == "null" then null else $parent end),role:$role,model:$model,effort:$effort,cwd:$cwds[0],state:(if $completed == $starts then "completed" else "running" end)} end
' "$rollout" 2>/dev/null || fail "rollout routing, role, parent, or lifecycle evidence is invalid."
