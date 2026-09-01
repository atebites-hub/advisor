#!/bin/sh
set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }
must_fail() { label=$1; shift; if "$@" >/dev/null 2>&1; then fail "$label unexpectedly succeeded"; fi; }
# GNU coreutils first: `stat -f` is --file-system, not BSD format.
file_mode() {
  if stat -c %a "$1" >/dev/null 2>&1; then
    stat -c %a "$1"
  else
    stat -f %Lp "$1"
  fi
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
installer=$script_dir/install-agents.sh
inspector=$script_dir/inspect-codex-runtime.sh
context=$plugin_dir/hooks/session-context.sh
enforcer=$plugin_dir/hooks/enforce-codex.sh
advisor=$plugin_dir/bin/advisor

tmp_base=${TMPDIR:-/tmp}; case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_base=$(CDPATH= cd "$tmp_base" && pwd -P)
tmp=$(mktemp -d "$tmp_base/advisor-codex-verify.XXXXXX") || fail "could not create test directory"
cleanup() { case "$tmp" in "$tmp_base"/advisor-codex-verify.*) rm -rf "$tmp" ;; esac; }
trap cleanup 0 HUP INT TERM

default_target=$tmp/default-agents
ADVISOR_CONFIG_HOME=$tmp/default-config ADVISOR_AGENT_DIR=$default_target sh "$installer" >/dev/null
role=$default_target/advisor-grunt.toml
[ -f "$role" ] && [ "$(file_mode "$role")" = 600 ] || fail "default role is missing or not mode 600"
grep -Fq 'name = "advisor_grunt"' "$role" && grep -Fq 'model = "gpt-5.6-luna"' "$role" && grep -Fq 'model_reasoning_effort = "high"' "$role" || fail "default role tuple is wrong"
ADVISOR_CONFIG_HOME=$tmp/default-config ADVISOR_AGENT_DIR=$default_target sh "$installer" --check >/dev/null || fail "default role check failed"

catalog=$tmp/models.json
jq -n '{models:[{slug:"custom/advisor",supported_reasoning_levels:[{effort:"max"}]},{slug:"custom/grunt",supported_reasoning_levels:[{effort:"medium"}]}]}' > "$catalog"
custom_config=$tmp/custom-config
ADVISOR_CONFIG_HOME=$custom_config ADVISOR_MODEL_CATALOG=$catalog sh "$advisor" configure --host codex \
  --advisor-model custom/advisor --advisor-effort max --grunt-model custom/grunt --grunt-effort medium >/dev/null
custom_target=$tmp/custom-agents
ADVISOR_CONFIG_HOME=$custom_config ADVISOR_AGENT_DIR=$custom_target sh "$installer" >/dev/null
grep -Fq 'model = "custom/grunt"' "$custom_target/advisor-grunt.toml" && grep -Fq 'model_reasoning_effort = "medium"' "$custom_target/advisor-grunt.toml" || fail "custom role tuple was not rendered exactly"
printf '%s\n' '# user modification' >> "$custom_target/advisor-grunt.toml"
before=$(shasum -a 256 "$custom_target/advisor-grunt.toml")
must_fail "modified role replacement" env ADVISOR_CONFIG_HOME=$custom_config ADVISOR_AGENT_DIR=$custom_target sh "$installer"
[ "$before" = "$(shasum -a 256 "$custom_target/advisor-grunt.toml")" ] || fail "failed install changed a modified role"

migrate=$tmp/migrate
mkdir -p "$migrate"
cat > "$migrate/sol-advisor-luna-subagent.toml" <<'OLD_ROLE'
name = "sol_advisor_luna_subagent"
description = "Sol Advisor's only child lane for bounded implementation, research, evidence gathering, and testing."
model = "gpt-5.6-luna"
model_reasoning_effort = "high"

developer_instructions = """
You are Sol Advisor's bounded execution child. Complete the supplied objective within
the settled architecture and exact owned file set. You may implement, research, gather
evidence, or run tests as the packet requests. Preserve stated interfaces and
constraints, adapt to concurrent edits, and do not revert unrelated work.

Surface material ambiguity, ownership conflicts, architectural decisions, or failed
verification to the Sol / Ultra parent instead of widening scope. Run the requested
checks and return exact commands and concrete evidence. Do not perform final review or
accept the deliverable. Do not spawn subagents. Do not substitute another role, model, or
reasoning level; this profile is pinned to GPT-5.6 Luna / High.
"""
OLD_ROLE
[ "$(shasum -a 256 "$migrate/sol-advisor-luna-subagent.toml" | awk '{print $1}')" = 7efae829b44a3e68f75d6f0f4988c8192502f7bdf0fb06c4802482b4ac7f497f ] || fail "historical role fixture drifted"
ADVISOR_CONFIG_HOME=$tmp/migrate-config ADVISOR_AGENT_DIR=$migrate sh "$installer" >/dev/null
[ -f "$migrate/advisor-grunt.toml" ] && [ ! -e "$migrate/sol-advisor-luna-subagent.toml" ] || fail "exact historical role was not retired"
conflict=$tmp/migration-conflict
mkdir -p "$conflict"
cp "$role" "$conflict/sol-advisor-luna-subagent.toml"
must_fail "modified historical role" env ADVISOR_CONFIG_HOME=$tmp/conflict-config ADVISOR_AGENT_DIR=$conflict sh "$installer"
[ ! -e "$conflict/advisor-grunt.toml" ] || fail "migration conflict partially installed the new role"
pass "generic role rendering, mode, check, conflict, and exact migration"

config=$tmp/runtime-config
mkdir -p "$config"
runtime_catalog=$tmp/runtime-models.json
jq -n '{models:[
  {slug:"gpt-5.6-sol",supported_reasoning_levels:[{effort:"ultra"}]},
  {slug:"gpt-5.6-luna",supported_reasoning_levels:[{effort:"high"}]},
  {slug:"custom/advisor",supported_reasoning_levels:[{effort:"max"}]},
  {slug:"custom/grunt",supported_reasoning_levels:[{effort:"medium"}]}
]}' > "$runtime_catalog"
root_a=11111111-1111-4111-8111-111111111111
root_b=22222222-2222-4222-8222-222222222222
child=33333333-3333-4333-8333-333333333333
sessions=$tmp/codex/sessions
mkdir -p "$sessions"

startup() {
  id=$1 source=$2
  printf '%s\n' "{\"hook_event_name\":\"SessionStart\",\"source\":\"$source\",\"session_id\":\"$id\",\"model\":\"gpt-5.6-sol\"}" |
    PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config sh "$context" >/dev/null
}
startup "$root_a" startup
snapshot_a=$config/sessions/$root_a.json
[ -f "$snapshot_a" ] && [ "$(file_mode "$snapshot_a")" = 600 ] || fail "SessionStart did not write a private snapshot"
jq -e '.policy == {advisorModel:"gpt-5.6-sol",advisorEffort:"ultra",gruntModel:"gpt-5.6-luna",gruntEffort:"high"}' "$snapshot_a" >/dev/null || fail "default session policy is wrong"
snapshot_hash=$(shasum -a 256 "$snapshot_a")
ADVISOR_CONFIG_HOME=$config ADVISOR_MODEL_CATALOG=$runtime_catalog sh "$advisor" configure --host codex \
  --advisor-model custom/advisor --advisor-effort max --grunt-model custom/grunt --grunt-effort medium >/dev/null
startup "$root_a" resume
[ "$snapshot_hash" = "$(shasum -a 256 "$snapshot_a")" ] || fail "resume reread the changed profile"
startup "$root_b" startup
jq -e '.policy == {advisorModel:"custom/advisor",advisorEffort:"max",gruntModel:"custom/grunt",gruntEffort:"medium"}' "$config/sessions/$root_b.json" >/dev/null || fail "new session did not snapshot the changed profile"
must_fail "duplicate startup snapshot" startup "$root_a" startup
must_fail "missing resume snapshot" startup 44444444-4444-4444-8444-444444444444 resume
ln -s "$config" "$tmp/config-link"
must_fail "symlinked Advisor config home" sh -c 'printf "%s\n" "$1" | PLUGIN_ROOT="$2" ADVISOR_CONFIG_HOME="$3" sh "$2/hooks/session-context.sh" >/dev/null' sh \
  "{\"hook_event_name\":\"SessionStart\",\"source\":\"resume\",\"session_id\":\"$root_a\"}" "$plugin_dir" "$tmp/config-link"
worker_context=$(printf '%s\n' '{"hook_event_name":"SubagentStart","agent_id":"agent-1","agent_type":"advisor_grunt","session_id":"11111111-1111-4111-8111-111111111111"}' | PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config sh "$context")
printf '%s\n' "$worker_context" | grep -Fq 'Advisor bounded grunt' || fail "SubagentStart did not inject grunt context"
other_context=$(printf '%s\n' '{"hook_event_name":"SubagentStart","agent_id":"agent-2","agent_type":"worker"}' | PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config sh "$context")
[ -z "$other_context" ] || fail "SubagentStart claimed an unrelated role"
pass "immutable session policy and authoritative SubagentStart context"

odw_root=88888888-8888-4888-8888-888888888888
odw_context=$(printf '%s\n' "{\"hook_event_name\":\"SessionStart\",\"source\":\"startup\",\"session_id\":\"$odw_root\",\"model\":\"custom/grunt\"}" |
  ODW_HOST=codex ODW_REQUIRE_CWD=1 PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config sh "$context")
printf '%s\n' "$odw_context" | grep -Fq 'Advisor ODW grunt' || fail "marked Codex ODW worker did not receive bounded context"
[ ! -e "$config/sessions/$odw_root.json" ] || fail "Codex ODW worker created a native root snapshot"
pass "marked Codex ODW workers bypass native-root activation without claiming a route"

write_rollout() {
  id=$1 parent=$2 role_name=$3 model=$4 effort=$5 state=$6
  file=$sessions/rollout-fixture-$id.jsonl
  jq -cn --arg id "$id" --arg parent "$parent" --arg role "$role_name" \
    '{type:"session_meta",payload:{id:$id,parent_thread_id:(if $parent == "null" then null else $parent end),agent_role:(if $role == "null" then null else $role end),agent_path:(if $role == "null" then null else "/root/grunt" end)}}' > "$file"
  jq -cn --arg model "$model" --arg effort "$effort" '{type:"turn_context",payload:{model:$model,effort:$effort,cwd:"/workspace"}}' >> "$file"
  jq -cn '{type:"event_msg",payload:{type:"task_started"}}' >> "$file"
  case "$state" in
    running) ;;
    completed) jq -cn '{type:"event_msg",payload:{type:"task_complete"}}' >> "$file" ;;
    failed) jq -cn '{type:"event_msg",payload:{type:"task_failed"}}' >> "$file" ;;
    cancelled) jq -cn '{type:"event_msg",payload:{type:"task_cancelled"}}' >> "$file" ;;
    timed_out) jq -cn '{type:"event_msg",payload:{type:"task_timed_out"}}' >> "$file" ;;
    aborted) jq -cn '{type:"event_msg",payload:{type:"turn_aborted"}}' >> "$file" ;;
  esac
}

write_rollout "$root_a" null null gpt-5.6-sol ultra running
advisor_evidence=$(sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$snapshot_a" --role advisor "$root_a")
printf '%s\n' "$advisor_evidence" | jq -e '.role == "advisor" and .state == "running" and .model == "gpt-5.6-sol" and .effort == "ultra"' >/dev/null || fail "primary runtime evidence is wrong"

write_rollout "$child" "$root_a" advisor_grunt gpt-5.6-luna high completed
result=$tmp/child-result.json
jq -n --arg runtime "$child" --arg parent "$root_a" '{runtime_id:$runtime,parent_runtime_id:$parent,state:"completed"}' > "$result"
grunt_evidence=$(sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$snapshot_a" --role grunt --result "$result" "$child")
printf '%s\n' "$grunt_evidence" | jq -e '.role == "advisor_grunt" and .parent_runtime_id == "11111111-1111-4111-8111-111111111111" and .state == "completed"' >/dev/null || fail "grunt runtime evidence is wrong"
write_rollout "$child" "$root_a" advisor_grunt gpt-5.6-luna low completed
must_fail "wrong grunt effort" sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$snapshot_a" --role grunt --result "$result" "$child"
write_rollout "$child" "$root_a" worker gpt-5.6-luna high completed
must_fail "wrong grunt role" sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$snapshot_a" --role grunt --result "$result" "$child"
write_rollout "$child" "$root_a" advisor_grunt gpt-5.6-luna high failed
must_fail "failed grunt" sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$snapshot_a" --role grunt --result "$result" "$child"
for terminal in cancelled timed_out aborted running; do
  write_rollout "$child" "$root_a" advisor_grunt gpt-5.6-luna high "$terminal"
  must_fail "$terminal grunt" sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$snapshot_a" --role grunt --result "$result" "$child"
done
write_rollout "$child" "$root_a" advisor_grunt gpt-5.6-luna high completed

cp "$sessions/rollout-fixture-$child.jsonl" "$sessions/rollout-duplicate-$child.jsonl"
must_fail "duplicate rollout" sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$snapshot_a" --role grunt --result "$result" "$child"
rm "$sessions/rollout-duplicate-$child.jsonl"
ln -s "$snapshot_a" "$tmp/symlinked-snapshot.json"
must_fail "symlinked snapshot" sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$tmp/symlinked-snapshot.json" --role advisor "$root_a"

same_root=66666666-6666-4666-8666-666666666666
same_child=77777777-7777-4777-8777-777777777777
same_policy=$tmp/same-policy.json
same_canonical=$(jq -cn '{advisorModel:"gpt-5.6-luna",advisorEffort:"high",gruntModel:"gpt-5.6-luna",gruntEffort:"high"}')
same_fingerprint=$(printf '%s' "$same_canonical" | shasum -a 256 | awk '{print $1}')
jq -n --arg runtime "$same_root" --arg fingerprint "$same_fingerprint" --argjson policy "$same_canonical" \
  '{schemaVersion:1,host:"codex",runtimeId:$runtime,policy:$policy,policyFingerprint:$fingerprint,createdAt:"2026-08-21T00:00:00Z"}' > "$same_policy"
chmod 600 "$same_policy"
write_rollout "$same_root" null null gpt-5.6-luna high running
write_rollout "$same_child" "$same_root" advisor_grunt gpt-5.6-luna high completed
same_result=$tmp/same-result.json
jq -n --arg runtime "$same_child" --arg parent "$same_root" '{runtime_id:$runtime,parent_runtime_id:$parent,state:"completed"}' > "$same_result"
sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$same_policy" --role advisor "$same_root" >/dev/null || fail "identical advisor tuple was rejected"
sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$same_policy" --role grunt --result "$same_result" "$same_child" >/dev/null || fail "identical grunt tuple was rejected"
write_rollout "$same_child" "$same_root" worker gpt-5.6-luna high completed
must_fail "identical tuple wrong role" sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$same_policy" --role grunt --result "$same_result" "$same_child"
pass "terminal-state, duplicate, symlink, and identical-tuple denials"

route=$tmp/codex-route.json
jq -n '{executor:"codex",model:"gpt-5.6-luna",reasoningEffort:"high"}' > "$route"; chmod 600 "$route"
odw_id=55555555-5555-4555-8555-555555555555
write_rollout "$odw_id" null null gpt-5.6-luna high completed
trace=$tmp/codex-trace.json
jq -n --arg runtime "$odw_id" '{command:"codex",exitCode:0,isError:false,resultSubtype:"success",routing:{runtimeId:$runtime,executor:"codex",model:"gpt-5.6-luna",reasoningEffort:"high"},events:[{type:"thread.started",thread_id:$runtime},{type:"turn.completed"}]}' > "$trace"
sh "$inspector" --mode odw --sessions-dir "$sessions" --route "$route" --result "$trace" "$odw_id" >/dev/null || fail "valid standalone Codex ODW evidence was rejected"
must_fail "cross-mode ODW evidence" sh "$inspector" --mode native --sessions-dir "$sessions" --policy "$snapshot_a" --role grunt --result "$trace" "$odw_id"
must_fail "missing inspector mode" sh "$inspector" --sessions-dir "$sessions" --policy "$snapshot_a" --role advisor "$root_a"
pass "native advisor/grunt and standalone ODW runtime inspection"

allowed='{"hook_event_name":"PreToolUse","session_id":"11111111-1111-4111-8111-111111111111","tool_name":"exec_command","tool_input":{}}'
spawn='{"hook_event_name":"PreToolUse","session_id":"11111111-1111-4111-8111-111111111111","tool_name":"spawn_agent","tool_input":{"agent_type":"advisor_grunt","fork_turns":"none"}}'
allowed_output=$(printf '%s\n' "$allowed" | PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config CODEX_HOME=$tmp/codex sh "$enforcer")
[ -z "$allowed_output" ] || fail "valid primary tool was not silently allowed"
unverified_output=$(printf '%s\n' '{"hook_event_name":"PreToolUse","tool_name":"exec_command","tool_input":{}}' |
  PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$tmp/missing-config CODEX_HOME=$tmp/missing-codex sh "$enforcer")
[ -z "$unverified_output" ] || fail "ordinary solo tool required unavailable Advisor runtime state"
linked_output=$(printf '%s\n' "$spawn" | PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$tmp/config-link CODEX_HOME=$tmp/codex sh "$enforcer")
printf '%s\n' "$linked_output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null || fail "symlinked Advisor config home bypassed delegation enforcement"
spawn_output=$(printf '%s\n' "$spawn" | PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config CODEX_HOME=$tmp/codex sh "$enforcer")
[ -z "$spawn_output" ] || fail "valid grunt spawn was denied"
odw_allowed=$(printf '%s\n' "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$odw_root\",\"tool_name\":\"exec_command\",\"tool_input\":{}}" |
  ODW_HOST=codex ODW_REQUIRE_CWD=1 PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config CODEX_HOME=$tmp/codex sh "$enforcer")
[ -z "$odw_allowed" ] || fail "ordinary tool was denied inside a marked Codex ODW worker"
odw_denied=$(printf '%s\n' "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$odw_root\",\"tool_name\":\"spawn_agent\",\"tool_input\":{}}" |
  ODW_HOST=codex ODW_REQUIRE_CWD=1 PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config CODEX_HOME=$tmp/codex sh "$enforcer")
printf '%s\n' "$odw_denied" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null || fail "marked Codex ODW worker could spawn a nested native child"
incomplete_odw=$(printf '%s\n' "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$odw_root\",\"tool_name\":\"spawn_agent\",\"tool_input\":{}}" |
  ODW_HOST=codex PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config CODEX_HOME=$tmp/codex sh "$enforcer")
printf '%s\n' "$incomplete_odw" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null || fail "incomplete ODW marker bypassed native enforcement"
for denied in \
  '{"hook_event_name":"PreToolUse","session_id":"11111111-1111-4111-8111-111111111111","tool_name":"spawn_agent","tool_input":{"agent_type":"worker","fork_turns":"none"}}' \
  '{"hook_event_name":"PreToolUse","session_id":"11111111-1111-4111-8111-111111111111","tool_name":"spawn_agent","tool_input":{"agent_type":"advisor_grunt","fork_turns":"all"}}' \
  '{"hook_event_name":"PreToolUse","session_id":"11111111-1111-4111-8111-111111111111","tool_name":"spawn_agent","tool_input":{"agent_type":"advisor_grunt","fork_turns":"none","model":"gpt-5.6-luna"}}'
do
  decision=$(printf '%s\n' "$denied" | PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config CODEX_HOME=$tmp/codex sh "$enforcer")
  printf '%s\n' "$decision" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null || fail "prohibited spawn was not denied"
done
write_rollout "$root_a" null null gpt-5.6-luna high running
decision=$(printf '%s\n' "$allowed" | PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config CODEX_HOME=$tmp/codex sh "$enforcer")
[ -z "$decision" ] || fail "wrong primary tuple blocked an ordinary solo tool"
decision=$(printf '%s\n' "$spawn" | PLUGIN_ROOT=$plugin_dir ADVISOR_CONFIG_HOME=$config CODEX_HOME=$tmp/codex sh "$enforcer")
printf '%s\n' "$decision" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null || fail "wrong primary tuple did not block delegation"
pass "ordinary solo continuity and strict grunt spawn guard"

printf '%s\n' "VERIFY CODEX ADAPTER PASSED"
