#!/bin/sh
set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }
must_fail() { label=$1; shift; if "$@" >/dev/null 2>&1; then fail "$label unexpectedly succeeded"; fi; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1
inspector=$script_dir/inspect-zcode-runtime.sh
enforcer=$plugin_dir/hosts/zcode/hooks/enforce.sh
advisor=$plugin_dir/bin/advisor

tmp_base=${TMPDIR:-/tmp}; case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_base=$(CDPATH= cd "$tmp_base" && pwd -P)
tmp=$(mktemp -d "$tmp_base/advisor-host-verify.XXXXXX") || fail "could not create test directory"
cleanup() { case "$tmp" in "$tmp_base"/advisor-host-verify.*) rm -rf "$tmp" ;; esac; }
trap cleanup 0 HUP INT TERM

jq -e '
  .name == "sol-advisor" and .version == "0.9.0" and .hooks == "./hosts/zcode/hooks/hooks.json" and
  (.userConfig | keys == ["advisor_effort","advisor_model","grunt_effort","grunt_model"]) and
  all(.userConfig[]; .type == "string" and .required == true and .sensitive == false)
' "$plugin_dir/.zcode-plugin/plugin.json" >/dev/null || fail "ZCode manifest settings or hook path are invalid"
jq -e '
  .version == "0.9.0" and (has("agents") | not) and (has("hooks") | not) and (has("mcpServers") | not) and
  (.description | test("experimental detection; strict delegation disabled"; "i"))
' "$plugin_dir/.grok-plugin/plugin.json" "$plugin_dir/.cursor-plugin/plugin.json" "$plugin_dir/.claude-plugin/plugin.json" >/dev/null || fail "experimental host manifests imply strict delegation"
jq empty "$repo_dir/marketplace.json" "$repo_dir/.grok-plugin/marketplace.json" "$repo_dir/.cursor-plugin/marketplace.json" "$repo_dir/.claude-plugin/marketplace.json" >/dev/null
pass "ZCode strict manifest and content-only experimental host manifests"

config=$tmp/zcode-config.json
write_config() {
  advisor_model=$1 advisor_effort=$2 grunt_model=$3 grunt_effort=$4
  jq -n --arg am "$advisor_model" --arg ae "$advisor_effort" --arg gm "$grunt_model" --arg ge "$grunt_effort" '{
    model:{main:"host/original",lite:"host/original-lite"},provider:{keep:{apiKey:"not-read-by-advisor"}},hooks:{enabled:false},
    plugins:{enabled:true,enabledPlugins:{"sol-advisor@sol-advisor":true},options:{"sol-advisor@sol-advisor":{advisor_model:$am,advisor_effort:$ae,grunt_model:$gm,grunt_effort:$ge}},unrelated:{keep:true}}
  }' > "$config"
}
write_config zai/advisor high zai/grunt low
config_hash=$(shasum -a 256 "$config")
doctor=$(HOME=$tmp ZCODE_CONFIG=$config sh "$advisor" doctor --host zcode --json || true)
printf '%s\n' "$doctor" | jq -e '.host == "zcode" and .strict == false and .code == "runtime_attestation_required" and .profileValid == true and .advisor.model == "zai/advisor" and .grunt.model == "zai/grunt"' >/dev/null || fail "ZCode doctor did not report configured attestation-required status"
[ "$config_hash" = "$(shasum -a 256 "$config")" ] || fail "ZCode doctor mutated host config"
incomplete=$tmp/incomplete.json
jq '.plugins.options["sol-advisor@sol-advisor"] |= del(.grunt_effort)' "$config" > "$incomplete"
incomplete_doctor=$(HOME=$tmp ZCODE_CONFIG=$incomplete sh "$advisor" doctor --host zcode --json || true)
printf '%s\n' "$incomplete_doctor" | jq -e '.code == "plugin_settings_required" and .strict == false' >/dev/null || fail "incomplete ZCode settings were accepted"
pass "ZCode settings discovery is read-only and incomplete settings disable strict mode"

policy_a=$(jq -cn '{advisorModel:"zai/advisor",advisorEffort:"high",gruntModel:"zai/grunt",gruntEffort:"low"}')
policy_b=$(jq -cn '{advisorModel:"zai/new-advisor",advisorEffort:"max",gruntModel:"zai/new-grunt",gruntEffort:"medium"}')
root=11111111-1111-4111-8111-111111111111
child=22222222-2222-4222-8222-222222222222

write_native_payload() {
  file=$1 runtime=$2 role=$3 parent=$4 source=$5 model=$6 effort=$7 policy=$8 state=${9-running}
  fingerprint=$(printf '%s' "$policy" | shasum -a 256 | awk '{print $1}')
  jq -n --arg runtime "$runtime" --arg role "$role" --arg parent "$parent" --arg source "$source" \
    --arg model "$model" --arg effort "$effort" --arg fingerprint "$fingerprint" --arg state "$state" --argjson policy "$policy" '{
      hookEventName:"SessionStart",state:$state,
      runtimeAttestation:{type:"zcode_runtime_attestation",schemaVersion:1,executor:"zcode",route:"native",runtimeId:$runtime,runtimeVersion:"0.16.3",sessionId:$runtime,role:$role,parentSessionId:(if $parent == "null" then null else $parent end),policySource:$source,rolePolicy:$policy,rolePolicyFingerprint:$fingerprint,model:$model,reasoningEffort:$effort}
    }' > "$file"
}
inspect_native() { file=$1 role=$2; sh "$inspector" --mode native --role "$role" --config "$config" < "$file"; }

root_payload=$tmp/root.json
write_native_payload "$root_payload" "$root" main null new zai/advisor high "$policy_a"
inspect_native "$root_payload" advisor >/dev/null || fail "valid new ZCode root attestation was rejected"
write_config zai/new-advisor max zai/new-grunt medium
write_native_payload "$root_payload" "$root" main null persisted zai/advisor high "$policy_a"
inspect_native "$root_payload" advisor >/dev/null || fail "restored root reread changed plugin settings"
new_root=33333333-3333-4333-8333-333333333333
write_native_payload "$root_payload" "$new_root" main null new zai/new-advisor max "$policy_b"
inspect_native "$root_payload" advisor >/dev/null || fail "new root did not accept new settings"
write_native_payload "$root_payload" "$new_root" main null new zai/advisor high "$policy_a"
must_fail "new root with stale settings" inspect_native "$root_payload" advisor

child_payload=$tmp/child.json
write_native_payload "$child_payload" "$child" lite "$root" parent zai/grunt low "$policy_a" completed
inspect_native "$child_payload" grunt >/dev/null || fail "valid inherited ZCode grunt attestation was rejected"
for mutation in wrong_version wrong_model wrong_effort wrong_role wrong_parent wrong_fingerprint failed_state; do
  write_native_payload "$child_payload" "$child" lite "$root" parent zai/grunt low "$policy_a" completed
  case "$mutation" in
    wrong_version) jq '.runtimeAttestation.runtimeVersion="0.0.0"' "$child_payload" > "$tmp/mutated.json" ;;
    wrong_model) jq '.runtimeAttestation.model="zai/other"' "$child_payload" > "$tmp/mutated.json" ;;
    wrong_effort) jq '.runtimeAttestation.reasoningEffort="high"' "$child_payload" > "$tmp/mutated.json" ;;
    wrong_role) jq '.runtimeAttestation.role="main"' "$child_payload" > "$tmp/mutated.json" ;;
    wrong_parent) jq '.runtimeAttestation.parentSessionId=null' "$child_payload" > "$tmp/mutated.json" ;;
    wrong_fingerprint) jq '.runtimeAttestation.rolePolicyFingerprint=("a"*64)' "$child_payload" > "$tmp/mutated.json" ;;
    failed_state) jq '.state="failed"' "$child_payload" > "$tmp/mutated.json" ;;
  esac
  must_fail "$mutation ZCode child" inspect_native "$tmp/mutated.json" grunt
done
printf '%s\n' '{}' > "$tmp/missing.json"
must_fail "missing ZCode attestation" inspect_native "$tmp/missing.json" advisor
pass "ZCode A-to-B session persistence and strict role policy attestation"

write_config zai/advisor high zai/grunt low
# root_payload currently contains a stale policy; rebuild the exact current root.
write_native_payload "$root_payload" "$root" main null new zai/advisor high "$policy_a"
valid_hook=$(CLAUDE_PLUGIN_ROOT=$plugin_dir ZCODE_CONFIG=$config sh "$enforcer" < "$root_payload")
printf '%s\n' "$valid_hook" | jq -e '.continue == true' >/dev/null || fail "valid ZCode hook did not continue"
if CLAUDE_PLUGIN_ROOT=$plugin_dir ZCODE_CONFIG=$config sh "$enforcer" < "$tmp/missing.json" > "$tmp/hook-out" 2> "$tmp/hook-error"; then fail "malformed ZCode hook input was allowed"; fi
grep -Fq ZCODE_STRICT_ADVISOR_HOOK_FAILURE "$tmp/hook-error" || fail "ZCode hook failure lacked the strict marker"
pass "ZCode plugin hook explicitly accepts valid evidence and fails invalid evidence"

tool_call=tool-call-1
jq --arg tool_call "$tool_call" '
  .hookEventName="PreToolUse" | .toolName="Agent" | .toolCallId=$tool_call |
  .toolInput={description:"bounded work",prompt:"do it",run_in_background:false}
' "$root_payload" > "$tmp/zcode-agent-pre.json"
pre_hook=$(CLAUDE_PLUGIN_ROOT=$plugin_dir ZCODE_CONFIG=$config sh "$enforcer" < "$tmp/zcode-agent-pre.json")
printf '%s\n' "$pre_hook" | jq -e '.continue == true' >/dev/null || fail "valid foreground ZCode Agent launch was rejected"
jq '.toolInput.run_in_background=true' "$tmp/zcode-agent-pre.json" > "$tmp/zcode-agent-background.json"
must_fail "background ZCode Agent launch" env CLAUDE_PLUGIN_ROOT=$plugin_dir ZCODE_CONFIG=$config sh "$enforcer" < "$tmp/zcode-agent-background.json"
jq '.toolInput.model="zai/other"' "$tmp/zcode-agent-pre.json" > "$tmp/zcode-agent-override.json"
must_fail "alternate-model ZCode Agent launch" env CLAUDE_PLUGIN_ROOT=$plugin_dir ZCODE_CONFIG=$config sh "$enforcer" < "$tmp/zcode-agent-override.json"
jq '.hookEventName="PreToolUse" | .toolName="Agent" | .toolCallId="nested" | .toolInput={prompt:"nested"}' "$child_payload" > "$tmp/zcode-agent-nested.json"
must_fail "nested native ZCode Agent launch" env CLAUDE_PLUGIN_ROOT=$plugin_dir ZCODE_CONFIG=$config sh "$enforcer" < "$tmp/zcode-agent-nested.json"

jq -n --slurpfile root_payload "$root_payload" --slurpfile child_payload "$child_payload" --arg tool_call "$tool_call" --arg root_id "$root" --arg child_id "$child" '
  $root_payload[0] | .hookEventName="PostToolUse" | .toolName="Agent" | .toolCallId=$tool_call |
  .childRuntimeEvidence={childSessionId:$child_id,parentSessionId:$root_id,parentToolCallId:$tool_call,state:"completed",runtimeAttestation:$child_payload[0].runtimeAttestation}
' > "$tmp/zcode-agent-post.json"
post_hook=$(CLAUDE_PLUGIN_ROOT=$plugin_dir ZCODE_CONFIG=$config sh "$enforcer" < "$tmp/zcode-agent-post.json")
printf '%s\n' "$post_hook" | jq -e '.continue == true' >/dev/null || fail "completed foreground ZCode Agent evidence was rejected"
for mutation in missing_child failed_child wrong_child wrong_parent wrong_tool wrong_policy wrong_child_model; do
  case "$mutation" in
    missing_child) jq 'del(.childRuntimeEvidence)' "$tmp/zcode-agent-post.json" > "$tmp/mutated-hook.json" ;;
    failed_child) jq '.childRuntimeEvidence.state="failed"' "$tmp/zcode-agent-post.json" > "$tmp/mutated-hook.json" ;;
    wrong_child) jq '.childRuntimeEvidence.childSessionId="33333333-3333-4333-8333-333333333333"' "$tmp/zcode-agent-post.json" > "$tmp/mutated-hook.json" ;;
    wrong_parent) jq '.childRuntimeEvidence.parentSessionId="33333333-3333-4333-8333-333333333333"' "$tmp/zcode-agent-post.json" > "$tmp/mutated-hook.json" ;;
    wrong_tool) jq '.childRuntimeEvidence.parentToolCallId="other-tool"' "$tmp/zcode-agent-post.json" > "$tmp/mutated-hook.json" ;;
    wrong_policy) jq '.childRuntimeEvidence.runtimeAttestation.rolePolicyFingerprint=("a"*64)' "$tmp/zcode-agent-post.json" > "$tmp/mutated-hook.json" ;;
    wrong_child_model) jq '.childRuntimeEvidence.runtimeAttestation.model="zai/other"' "$tmp/zcode-agent-post.json" > "$tmp/mutated-hook.json" ;;
  esac
  must_fail "$mutation ZCode Agent result" env CLAUDE_PLUGIN_ROOT=$plugin_dir ZCODE_CONFIG=$config sh "$enforcer" < "$tmp/mutated-hook.json"
done
jq '.hookEventName="PostToolUseFailure" | del(.childRuntimeEvidence)' "$tmp/zcode-agent-post.json" > "$tmp/zcode-agent-failed.json"
must_fail "failed ZCode Agent result" env CLAUDE_PLUGIN_ROOT=$plugin_dir ZCODE_CONFIG=$config sh "$enforcer" < "$tmp/zcode-agent-failed.json"
pass "ZCode native delegation is foreground-only and accepts only joined completed child evidence"

zcode_odw_hook=$tmp/zcode-odw-hook.json
jq -n --arg runtime 55555555-5555-4555-8555-555555555555 '{
  hookEventName:"SessionStart",
  runtimeAttestation:{type:"zcode_runtime_attestation",schemaVersion:1,executor:"zcode",route:"odw",runtimeId:$runtime,runtimeVersion:"0.16.3",sessionId:$runtime,role:"main",parentSessionId:null,policySource:null,rolePolicy:null,rolePolicyFingerprint:null,model:"zai/grunt",reasoningEffort:"low"}
}' > "$zcode_odw_hook"
odw_hook_output=$(ZCODE_ODW_PROTOCOL=1 CLAUDE_PLUGIN_ROOT=$plugin_dir sh "$enforcer" < "$zcode_odw_hook")
printf '%s\n' "$odw_hook_output" | jq -e '.continue == true' >/dev/null || fail "marked ZCode ODW worker did not bypass native policy inspection"
jq '.hookEventName="PreToolUse" | .toolName="Agent" | .toolInput={prompt:"nested"}' "$zcode_odw_hook" > "$tmp/zcode-odw-nested.json"
must_fail "nested Agent from ZCode ODW worker" env ZCODE_ODW_PROTOCOL=1 CLAUDE_PLUGIN_ROOT=$plugin_dir sh "$enforcer" < "$tmp/zcode-odw-nested.json"
must_fail "native evidence under ZCode ODW marker" env ZCODE_ODW_PROTOCOL=1 CLAUDE_PLUGIN_ROOT=$plugin_dir sh "$enforcer" < "$root_payload"
pass "marked ZCode ODW workers avoid native-root inspection and cannot nest Agent"

route=$tmp/zcode-route.json
jq -n '{executor:"zcode",model:"zai/grunt",reasoningEffort:"low"}' > "$route"; chmod 600 "$route"
odw=44444444-4444-4444-8444-444444444444
canonical=$(jq -c '{executor,model,reasoningEffort}' "$route")
fingerprint=$(printf '%s' "$canonical" | shasum -a 256 | awk '{print $1}')
trace=$tmp/zcode-trace.json
jq -n --arg runtime "$odw" --arg fingerprint "$fingerprint" '{
  command:"zcode",exitCode:0,isError:false,resultSubtype:"success",
  routing:{policyFingerprint:$fingerprint,executor:"zcode",model:"zai/grunt",reasoningEffort:"low",runtimeId:$runtime},
  events:[{type:"zcode_result",sessionId:$runtime,runtimeAttestation:{type:"zcode_runtime_attestation",schemaVersion:1,executor:"zcode",route:"odw",runtimeId:$runtime,runtimeVersion:"0.16.3",sessionId:$runtime,role:"main",parentSessionId:null,policySource:null,rolePolicy:null,rolePolicyFingerprint:null,model:"zai/grunt",reasoningEffort:"low"}}]
}' > "$trace"
sh "$inspector" --mode odw --route "$route" --result "$trace" >/dev/null || fail "valid ZCode ODW evidence was rejected"
jq '.events[0].runtimeAttestation.role="lite"' "$trace" > "$tmp/bad-trace.json"
must_fail "wrong-role ZCode ODW" sh "$inspector" --mode odw --route "$route" --result "$tmp/bad-trace.json"
must_fail "cross-mode native evidence" inspect_native "$trace" advisor
pass "standalone ZCode ODW attestation and cross-mode rejection"

for host_code in 'cursor runtime_effort_attestation_unavailable' 'claude runtime_effort_attestation_unavailable' 'grok hook_failure_is_fail_open'; do
  set -- $host_code
  output=$(ADVISOR_CONFIG_HOME=$tmp/doctor sh "$advisor" doctor --host "$1" --json || true)
  printf '%s\n' "$output" | jq -e --arg host "$1" --arg code "$2" '.host == $host and .strict == false and .code == $code and .nativeLane == "disabled" and .odwLane == "disabled"' >/dev/null || fail "$1 doctor overclaimed support"
done
must_fail "Grok Bot exclusion" env ADVISOR_CONFIG_HOME=$tmp/doctor sh "$advisor" doctor --host grok-bot --json
pass "truthful experimental and excluded host status"

printf '%s\n' "VERIFY HOST ADAPTERS PASSED"
