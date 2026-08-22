#!/bin/sh
set -eu

fail() { printf '%s\n' "ERROR: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq is unavailable."
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
host= run_dir= sessions_dir=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host|--sessions-dir)
      option=$1; [ "$#" -ge 2 ] && [ -n "$2" ] || fail "$option requires a value."
      case "$2" in --*) fail "$option requires an explicit value." ;; esac
      if [ "$option" = --host ]; then [ -z "$host" ] || fail "duplicate --host."; host=$2
      else [ -z "$sessions_dir" ] || fail "duplicate --sessions-dir."; sessions_dir=$2
      fi
      shift 2 ;;
    --*) fail "unknown option: $1" ;;
    *) [ -z "$run_dir" ] || fail "extra positional argument: $1"; run_dir=$1; shift ;;
  esac
done
case "$host" in codex|zcode) ;; '') fail "--host is required." ;; *) fail "unsupported Advisor ODW host: $host" ;; esac
[ -n "$run_dir" ] || fail "run directory is required."
case "$run_dir" in /*) ;; *) fail "run directory must be absolute and canonical." ;; esac
[ -d "$run_dir" ] && [ ! -L "$run_dir" ] || fail "run directory is unavailable or unsafe."
physical=$(CDPATH= cd "$run_dir" && pwd -P) || fail "run directory cannot be resolved."
[ "$physical" = "$run_dir" ] || fail "run directory must not contain symlinks, dot segments, or a trailing slash."
if find "$run_dir" -type l -print 2>/dev/null | grep -q .; then fail "run contains a symlink."; fi

run_id=$(basename "$run_dir"); runs_dir=$(dirname "$run_dir"); workflow_dir=$(dirname "$runs_dir"); odw_dir=$(dirname "$workflow_dir")
[ "$(basename "$runs_dir")" = runs ] && [ "$(basename "$odw_dir")" = .odw ] || fail "run is not below .odw/WORKFLOW/runs."
printf '%s\n' "$run_id" | LC_ALL=C grep -Eq '^run-[A-Za-z0-9][A-Za-z0-9._-]*$' || fail "invalid run id."

events=$run_dir/events.jsonl; journal=$run_dir/journal.jsonl; agents=$run_dir/agents
for file in "$events" "$journal"; do [ -f "$file" ] && [ ! -L "$file" ] || fail "required run artifact is missing or unsafe."; done
[ -d "$agents" ] && [ ! -L "$agents" ] || fail "agents directory is missing or unsafe."
script_count=0
for script in "$run_dir/script.js" "$run_dir/script.mjs"; do [ -f "$script" ] && [ ! -L "$script" ] && script_count=$((script_count + 1)); done
[ "$script_count" -eq 1 ] || fail "run must contain exactly one regular persisted script."

tmp_base=${TMPDIR:-/tmp}; case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_base=$(CDPATH= cd "$tmp_base" && pwd -P)
tmp=$(mktemp -d "$tmp_base/advisor-odw-inspect.XXXXXX") || fail "could not create verification directory."
cleanup() { case "$tmp" in "$tmp_base"/advisor-odw-inspect.*) rm -rf "$tmp" ;; esac; }
trap cleanup 0 HUP INT TERM

summary=$tmp/summary.json
jq -ce -s --arg run "$run_id" --arg host "$host" '
  [ .[] | select(.type == "run_start") ] as $starts |
  [ .[] | select(.type == "run_end") ] as $ends |
  [ .[] | select(.type == "agent_start") ] as $agent_starts |
  [ .[] | select(.type == "agent_end") ] as $agent_ends |
  if ($starts | length) != 1 or ($ends | length) != 1 then error("ambiguous lifecycle")
  elif $starts[0].runId != $run or $ends[0].runId != $run then error("run id mismatch")
  elif $ends[0].ok != true or $ends[0].failedAgents != 0 or $ends[0].failedWorkflows != 0 then error("failed run")
  elif ($starts[0].routingPolicy | type) != "object" or ($starts[0].routingPolicy | keys) != ["executor","model","reasoningEffort"] then error("invalid policy")
  elif $starts[0].routingPolicy.executor != $host or any($starts[0].routingPolicy[]; type != "string" or length == 0) then error("wrong host policy")
  elif ($starts[0].routingPolicyFingerprint | type) != "string" or ($starts[0].routingPolicyFingerprint | test("^[a-f0-9]{64}$") | not) then error("invalid fingerprint")
  elif ($agent_starts | length) == 0 or ($agent_starts | length) != ($agent_ends | length) then error("partial agent lifecycle")
  elif any($agent_starts[]; .cached != false or (.agentId | type != "number")) or any($agent_ends[]; .cached != false or .ok != true or .skipped == true) then error("cached failed or skipped agent")
  elif ($agent_starts | map(.agentId) | unique | length) != ($agent_starts | length) or ($agent_ends | map(.agentId) | unique | length) != ($agent_ends | length) then error("duplicate agent id")
  elif ([ $agent_starts[].agentId ] | sort) != ([ $agent_ends[].agentId ] | sort) then error("unjoined agent lifecycle")
  else {policy:$starts[0].routingPolicy,fingerprint:$starts[0].routingPolicyFingerprint,agent_ids:([$agent_starts[].agentId] | sort)} end
' "$events" > "$summary" 2>/dev/null || fail "events are malformed, cached, failed, partial, or missing one routing policy."

canonical=$(jq -c '{executor:.policy.executor,model:.policy.model,reasoningEffort:.policy.reasoningEffort}' "$summary")
recorded=$(jq -r '.fingerprint' "$summary")
[ "$(printf '%s' "$canonical" | shasum -a 256 | awk '{print $1}')" = "$recorded" ] || fail "run policy fingerprint does not recompute."
route=$tmp/route.json
printf '%s\n' "$canonical" > "$route"; chmod 600 "$route"

jq -e -s --slurpfile events "$events" '
  [ $events[] | select(.type == "agent_start") | .agentId ] as $ids |
  length == ($ids | length) and ([.[].index] | sort) == ($ids | sort) and all(.[]; .cached == false)
' "$journal" >/dev/null 2>&1 || fail "journal does not account for every fresh model node."

jq -r '.agent_ids[]' "$summary" > "$tmp/agent-ids"
find "$agents" -mindepth 1 -maxdepth 1 -print > "$tmp/agent-files"
[ "$(awk 'END {print NR+0}' "$tmp/agent-files")" -eq "$(jq '.agent_ids | length' "$summary")" ] || fail "trace inventory does not match model nodes."
: > "$tmp/evidence.jsonl"

while IFS= read -r agent_id; do
  trace=$agents/agent-$agent_id.jsonl
  [ -f "$trace" ] && [ ! -L "$trace" ] || fail "agent trace is missing or unsafe."
  runtime=$(jq -r --arg host "$host" --arg fingerprint "$recorded" --argjson route "$canonical" '
    if type == "object" and .command == $host and .exitCode == 0 and .isError == false and .resultSubtype == "success" and
      (.routing | type) == "object" and (.routing | keys) == ["executor","model","policyFingerprint","reasoningEffort","runtimeId"] and
      .routing.policyFingerprint == $fingerprint and .routing.executor == $route.executor and .routing.model == $route.model and .routing.reasoningEffort == $route.reasoningEffort and
      (.routing.runtimeId | type == "string" and test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"))
    then .routing.runtimeId else error("invalid trace") end
  ' "$trace" 2>/dev/null) || fail "trace has wrong executor, route, fingerprint, runtime id, or completion state."
  if [ "$host" = codex ]; then
    if [ -n "$sessions_dir" ]; then
      evidence=$(sh "$script_dir/inspect-codex-runtime.sh" --mode odw --sessions-dir "$sessions_dir" --route "$route" --result "$trace" "$runtime") || fail "Codex host evidence rejected a model node."
    else
      evidence=$(sh "$script_dir/inspect-codex-runtime.sh" --mode odw --route "$route" --result "$trace" "$runtime") || fail "Codex host evidence rejected a model node."
    fi
  else
    evidence=$(sh "$script_dir/inspect-zcode-runtime.sh" --mode odw --route "$route" --result "$trace") || fail "ZCode host evidence rejected a model node."
  fi
  printf '%s\n' "$evidence" | jq -ce --argjson agent "$agent_id" '{agent_id:$agent,runtime_id,model,effort,state}' >> "$tmp/evidence.jsonl" || fail "host evidence output is invalid."
done < "$tmp/agent-ids"

jq -ce -s --arg run "$run_id" --arg host "$host" --arg fingerprint "$recorded" '
  if (map(.runtime_id) | unique | length) != length then error("duplicate runtime id")
  else {run_id:$run,host:$host,policy_fingerprint:$fingerprint,agent_count:length,agents:(sort_by(.agent_id))} end
' "$tmp/evidence.jsonl" || fail "ODW evidence could not be summarized safely."
