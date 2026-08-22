#!/bin/sh
set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }
must_fail() { label=$1; shift; if "$@" >/dev/null 2>&1; then fail "$label unexpectedly succeeded"; fi; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
inspector=$script_dir/inspect-odw-run.sh
tmp_base=${TMPDIR:-/tmp}; case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_base=$(CDPATH= cd "$tmp_base" && pwd -P)
tmp=$(mktemp -d "$tmp_base/advisor-odw-verify.XXXXXX") || fail "could not create test directory"
tmp=$(CDPATH= cd "$tmp" && pwd -P)
cleanup() { case "$tmp" in "$tmp_base"/advisor-odw-verify.*) rm -rf "$tmp" ;; *) printf '%s\n' "REFUSING cleanup: $tmp" >&2 ;; esac; }
trap cleanup 0 HUP INT TERM
sessions=$tmp/codex-sessions
mkdir -p "$sessions"

write_codex_rollout() {
  id=$1 model=$2 effort=$3
  file=$sessions/rollout-fixture-$id.jsonl
  jq -cn --arg id "$id" '{type:"session_meta",payload:{id:$id,parent_thread_id:null,agent_role:null,agent_path:null}}' > "$file"
  jq -cn --arg model "$model" --arg effort "$effort" '{type:"turn_context",payload:{model:$model,effort:$effort,cwd:"/workspace"}}' >> "$file"
  jq -cn '{type:"event_msg",payload:{type:"task_started"}}' >> "$file"
  jq -cn '{type:"event_msg",payload:{type:"task_complete"}}' >> "$file"
}

write_run() {
  host=$1 run=$2 model=$3 effort=$4 id1=$5 id2=$6
  mkdir -p "$run/agents"
  printf '%s\n' 'export const meta = { name: "fixture", description: "fixture" }; return 1;' > "$run/script.js"
  policy=$(jq -cn --arg host "$host" --arg model "$model" --arg effort "$effort" '{executor:$host,model:$model,reasoningEffort:$effort}')
  fingerprint=$(printf '%s' "$policy" | shasum -a 256 | awk '{print $1}')
  run_id=$(basename "$run")
  jq -cn --arg run "$run_id" --arg fingerprint "$fingerprint" --argjson policy "$policy" '{type:"run_start",runId:$run,routingPolicy:$policy,routingPolicyFingerprint:$fingerprint}' > "$run/events.jsonl"
  for agent in 1 2; do
    jq -cn --argjson agent "$agent" '{type:"agent_start",agentId:$agent,cached:false}' >> "$run/events.jsonl"
    jq -cn --argjson agent "$agent" '{type:"agent_end",agentId:$agent,cached:false,ok:true}' >> "$run/events.jsonl"
    jq -cn --argjson agent "$agent" '{index:$agent,cached:false}' >> "$run/journal.jsonl"
  done
  jq -cn --arg run "$run_id" '{type:"run_end",runId:$run,ok:true,failedAgents:0,failedWorkflows:0}' >> "$run/events.jsonl"
  agent=1
  for runtime in "$id1" "$id2"; do
    if [ "$host" = codex ]; then
      jq -n --arg runtime "$runtime" --arg fingerprint "$fingerprint" --arg model "$model" --arg effort "$effort" '{command:"codex",exitCode:0,isError:false,resultSubtype:"success",routing:{policyFingerprint:$fingerprint,executor:"codex",model:$model,reasoningEffort:$effort,runtimeId:$runtime},events:[{type:"thread.started",thread_id:$runtime},{type:"turn.completed"}]}' > "$run/agents/agent-$agent.jsonl"
      write_codex_rollout "$runtime" "$model" "$effort"
    else
      jq -n --arg runtime "$runtime" --arg fingerprint "$fingerprint" --arg model "$model" --arg effort "$effort" '{command:"zcode",exitCode:0,isError:false,resultSubtype:"success",routing:{policyFingerprint:$fingerprint,executor:"zcode",model:$model,reasoningEffort:$effort,runtimeId:$runtime},events:[{type:"zcode_result",sessionId:$runtime,runtimeAttestation:{type:"zcode_runtime_attestation",schemaVersion:1,executor:"zcode",route:"odw",runtimeId:$runtime,runtimeVersion:"0.16.3",sessionId:$runtime,role:"main",parentSessionId:null,policySource:null,rolePolicy:null,rolePolicyFingerprint:null,model:$model,reasoningEffort:$effort}}]}' > "$run/agents/agent-$agent.jsonl"
    fi
    agent=$((agent + 1))
  done
}

codex_run=$tmp/project/.odw/codex-fixture/runs/run-codex
codex_1=11111111-1111-4111-8111-111111111111
codex_2=22222222-2222-4222-8222-222222222222
write_run codex "$codex_run" gpt-5.6-luna high "$codex_1" "$codex_2"
codex_output=$(sh "$inspector" --host codex --sessions-dir "$sessions" "$codex_run")
printf '%s\n' "$codex_output" | jq -e '.host == "codex" and .agent_count == 2 and ([.agents[].runtime_id] | unique | length) == 2 and all(.agents[]; .model == "gpt-5.6-luna" and .effort == "high" and .state == "completed")' >/dev/null || fail "Codex ODW summary is invalid"
pass "two-node Codex ODW policy, trace, rollout, and distinct runtime evidence"

zcode_run=$tmp/project/.odw/zcode-fixture/runs/run-zcode
zcode_1=33333333-3333-4333-8333-333333333333
zcode_2=44444444-4444-4444-8444-444444444444
write_run zcode "$zcode_run" zai/grunt low "$zcode_1" "$zcode_2"
zcode_output=$(sh "$inspector" --host zcode "$zcode_run")
printf '%s\n' "$zcode_output" | jq -e '.host == "zcode" and .agent_count == 2 and ([.agents[].runtime_id] | unique | length) == 2 and all(.agents[]; .model == "zai/grunt" and .effort == "low" and .state == "completed")' >/dev/null || fail "ZCode ODW summary is invalid"
pass "two-node ZCode ODW policy, trace, attestation, and distinct runtime evidence"

mutated=$tmp/project/.odw/mutated/runs/run-mutated
write_run zcode "$mutated" zai/grunt low "$zcode_1" "$zcode_2"
jq 'if .type == "run_start" then .routingPolicyFingerprint=("a"*64) else . end' "$mutated/events.jsonl" > "$tmp/events-mutated"
mv "$tmp/events-mutated" "$mutated/events.jsonl"
must_fail "wrong run fingerprint" sh "$inspector" --host zcode "$mutated"

write_run zcode "$mutated" zai/grunt low "$zcode_1" "$zcode_2"
jq '.routing.model="zai/other"' "$mutated/agents/agent-1.jsonl" > "$tmp/trace-mutated"
mv "$tmp/trace-mutated" "$mutated/agents/agent-1.jsonl"
must_fail "wrong trace model" sh "$inspector" --host zcode "$mutated"

write_run zcode "$mutated" zai/grunt low "$zcode_1" "$zcode_2"
jq 'if .type == "agent_start" and .agentId == 1 then .cached=true else . end' "$mutated/events.jsonl" > "$tmp/events-mutated"
mv "$tmp/events-mutated" "$mutated/events.jsonl"
must_fail "cached model node" sh "$inspector" --host zcode "$mutated"

write_run zcode "$mutated" zai/grunt low "$zcode_1" "$zcode_1"
must_fail "duplicate runtime id" sh "$inspector" --host zcode "$mutated"

write_run zcode "$mutated" zai/grunt low "$zcode_1" "$zcode_2"
jq '.exitCode=1 | .isError=true | .resultSubtype="error_during_execution"' "$mutated/agents/agent-2.jsonl" > "$tmp/trace-mutated"
mv "$tmp/trace-mutated" "$mutated/agents/agent-2.jsonl"
must_fail "failed model node" sh "$inspector" --host zcode "$mutated"
must_fail "unsupported Cursor ODW host" sh "$inspector" --host cursor "$zcode_run"
must_fail "unsupported Claude ODW host" sh "$inspector" --host claude "$zcode_run"
must_fail "unsupported Grok ODW host" sh "$inspector" --host grok "$zcode_run"
pass "fingerprint route cache runtime failure and unsupported-host denials"

printf '%s\n' "VERIFY ODW INSPECTOR PASSED"
