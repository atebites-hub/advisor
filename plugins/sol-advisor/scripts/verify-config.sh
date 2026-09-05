#!/bin/sh
set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }
# GNU coreutils first: `stat -f` is --file-system, not BSD format.
file_mode() {
  if stat -c %a "$1" >/dev/null 2>&1; then
    stat -c %a "$1"
  else
    stat -f %Lp "$1"
  fi
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
advisor=$script_dir/../bin/advisor
tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_base=$(CDPATH= cd "$tmp_base" && pwd -P)
tmp_dir=$(mktemp -d "$tmp_base/advisor-config-verify.XXXXXX") || fail "could not create test directory"
cleanup() {
  case "$tmp_dir" in "$tmp_base"/advisor-config-verify.*) rm -rf "$tmp_dir" ;; esac
}
trap cleanup 0 HUP INT TERM

[ -f "$advisor" ] || fail "Advisor helper is missing: $advisor"

config_home=$tmp_dir/config
catalog=$tmp_dir/models.json
mkdir -p "$config_home"
printf '%s\n' keep > "$config_home/unrelated.txt"
jq -n '{models:[
  {slug:"gpt-5.6-sol",supported_reasoning_levels:[{effort:"ultra"}]},
  {slug:"gpt-5.6-luna",supported_reasoning_levels:[{effort:"high"}]},
  {slug:"custom/advisor",supported_reasoning_levels:[{effort:"max"}]},
  {slug:"custom/grunt",supported_reasoning_levels:[{effort:"medium"}]}
]}' > "$catalog"

codex_home=$tmp_dir/codex-home
mkdir -p "$codex_home"
run_advisor() {
  ADVISOR_CONFIG_HOME=$config_home ADVISOR_MODEL_CATALOG=$catalog ADVISOR_AGENT_DIR=$tmp_dir/agents \
    CODEX_HOME=$codex_home sh "$advisor" "$@"
}

profile=$config_home/codex.json
configure_output=$(run_advisor configure --host codex \
  --advisor-model gpt-5.6-sol --advisor-effort ultra \
  --grunt-model gpt-5.6-luna --grunt-effort high)
printf '%s\n' "$configure_output" | grep -Fq "WROTE: $profile" || fail "configure did not report the written profile"
printf '%s\n' "$configure_output" | grep -Fq '$advisor apply --host codex' || fail "configure omitted the installed-skill apply command"
[ -f "$profile" ] && [ ! -L "$profile" ] || fail "configure did not write a regular profile"
[ "$(file_mode "$profile")" = 600 ] || fail "profile mode is not 600"
jq -e '
  keys == ["advisor","grunt","host","schemaVersion"] and
  .schemaVersion == 1 and .host == "codex" and
  .advisor == {model:"gpt-5.6-sol",effort:"ultra"} and
  .grunt == {model:"gpt-5.6-luna",effort:"high"}
' "$profile" >/dev/null || fail "configured profile has the wrong schema"
[ "$(cat "$config_home/unrelated.txt")" = keep ] || fail "configure changed an unrelated file"
pass "atomic mode-600 Codex profile and unrelated-file preservation"

original_hash=$(shasum -a 256 "$profile" | awk '{print $1}')
for invalid in \
  'configure --host codex --advisor-model gpt-5.6-sol --advisor-effort ultra --grunt-model gpt-5.6-luna' \
  'configure --host codex --advisor-model gpt-5.6-sol --advisor-model gpt-5.6-sol --advisor-effort ultra --grunt-model gpt-5.6-luna --grunt-effort high' \
  'configure --host codex --advisor-model gpt-5.6-sol --advisor-effort ultra --grunt-model gpt-5.6-luna --grunt-effort high --unknown value' \
  'configure --host codex --advisor-model gpt-5.6-sol --advisor-effort ultra --grunt-model gpt-5.6-luna --grunt-effort high extra' \
  'configure --host codex --advisor-model unsafe\ value --advisor-effort ultra --grunt-model gpt-5.6-luna --grunt-effort high' \
  'configure --host codex --advisor-model gpt-5.6-sol --advisor-effort "" --grunt-model gpt-5.6-luna --grunt-effort high' \
  'configure --host grok --advisor-model gpt-5.6-sol --advisor-effort ultra --grunt-model gpt-5.6-luna --grunt-effort high'
do
  if ADVISOR_CONFIG_HOME=$config_home ADVISOR_MODEL_CATALOG=$catalog sh -c 'sh "$1" $2' sh "$advisor" "$invalid" >/dev/null 2>&1; then
    fail "invalid configure input succeeded: $invalid"
  fi
  [ "$(shasum -a 256 "$profile" | awk '{print $1}')" = "$original_hash" ] || fail "invalid configure changed the profile"
done
pass "incomplete duplicate unknown unsafe empty positional and wrong-host inputs fail safely"

doctor_before=$(shasum -a 256 "$profile" "$config_home/unrelated.txt")
doctor_json=$(run_advisor doctor --host codex --json || true)
doctor_after=$(shasum -a 256 "$profile" "$config_home/unrelated.txt")
[ "$doctor_before" = "$doctor_after" ] || fail "doctor mutated configuration"
printf '%s\n' "$doctor_json" | jq -e '
  keys == ["advisor","checks","code","grunt","host","nativeLane","odwLane","profilePath","profileSource","profileValid","schemaVersion","strict"] and
  .schemaVersion == 1 and .host == "codex" and .profileValid == true and
  .strict == false and .code == "activation_required" and
  .advisor == {model:"gpt-5.6-sol",effort:"ultra",observable:true,available:true} and
  .grunt == {model:"gpt-5.6-luna",effort:"high",observable:true,available:true} and
  (.checks.hostCli.present | type == "boolean") and (.checks.hostCli.version | type == "string") and
  .checks.generatedFiles.current == false and
  .checks.hooks == {configured:true,trustObservable:false,trusted:false} and
  .checks.odwPlugin.requiredVersion == "0.3.0" and (.checks.odwPlugin.compatible | type == "boolean") and
  .checks.odwPlugin.pluginId == "open-dynamic-workflows@open-dynamic-workflows" and
  .checks.odwPlugin.installHint == "install/enable open-dynamic-workflows@0.3.0" and
  .checks.runtimeAttestation == {required:true,observed:false}
' >/dev/null || fail "doctor JSON is not the allowlisted schema"
pass "doctor is read-only and reports independently validated tuples"

# Codex hook trust is persisted under [hooks.state] as sha256 of the
# NormalizedHookIdentity (event + matcher + command handler), not script bytes.
# Vectors below are version_for_toml of the current packaged hooks.json commands.
write_codex_config() {
  cat > "$codex_home/config.toml"
}
doctor_hooks() {
  run_advisor doctor --host codex --json || true
}
assert_doctor_hooks() {
  label=$1 expected_observable=$2 expected_trusted=$3
  json=$(doctor_hooks)
  printf '%s\n' "$json" | jq -e --argjson observable "$expected_observable" --argjson trusted "$expected_trusted" '
    .code == "activation_required" and .strict == false and
    .checks.runtimeAttestation == {required:true,observed:false} and
    .checks.hooks.configured == true and
    .checks.hooks.trustObservable == $observable and
    .checks.hooks.trusted == $trusted
  ' >/dev/null || fail "Codex hook trust $label: expected observable=$expected_observable trusted=$expected_trusted"
}

write_codex_config <<'TOML'
[model]
# readable Codex config without hooks.state
TOML
assert_doctor_hooks "empty-hooks-state" true false

write_codex_config <<'TOML'
[hooks.state."sol-advisor@sol-advisor:hooks/hooks.json:session_start:0:0"]
trusted_hash = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
[hooks.state."sol-advisor@sol-advisor:hooks/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
[hooks.state."sol-advisor@sol-advisor:hooks/hooks.json:subagent_start:0:0"]
trusted_hash = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
TOML
assert_doctor_hooks "wrong-trusted-hash" true false

write_codex_config <<'TOML'
[hooks.state."sol-advisor@sol-advisor:hooks/hooks.json:session_start:0:0"]
trusted_hash = "sha256:26ade51c64fb6db17b17ad11a0ebc5508f3f094a3319482a89da5ffb1a30dbab"
[hooks.state."sol-advisor@sol-advisor:hooks/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:5e7060c07cd2bd428a89a91d5debe67890e1041e00d765099890943785ef493c"
TOML
assert_doctor_hooks "incomplete-trusted-hash" true false

write_codex_config <<'TOML'
[hooks.state."sol-advisor@sol-advisor:hooks/hooks.json:session_start:0:0"]
trusted_hash = "sha256:26ade51c64fb6db17b17ad11a0ebc5508f3f094a3319482a89da5ffb1a30dbab"
[hooks.state."sol-advisor@sol-advisor:hooks/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:5e7060c07cd2bd428a89a91d5debe67890e1041e00d765099890943785ef493c"
[hooks.state."sol-advisor@sol-advisor:hooks/hooks.json:subagent_start:0:0"]
trusted_hash = "sha256:2edaa564324068e366ee73f139e5629e3e032d9816abef4f97906494c93a9bb1"
TOML
assert_doctor_hooks "matching-trusted-hash" true true
rm -f "$codex_home/config.toml"
pass "doctor observes Codex hooks.state without soft-passing attestation"

# Exercise odw_list_is_compatible from advisor without running the CLI.
odw_plugin_id=open-dynamic-workflows@open-dynamic-workflows
odw_required_version=0.3.0
eval "$(sed -n '/^odw_list_is_compatible()/,/^}$/p' "$advisor")"
assert_odw_list() {
  label=$1 expected=$2 json=$3
  if printf '%s\n' "$json" | odw_list_is_compatible; then
    actual=true
  else
    actual=false
  fi
  [ "$actual" = "$expected" ] || fail "odw list $label: expected compatible=$expected got $actual"
}
assert_odw_list zcode-plugins-enabled true \
  '{"plugins":[{"id":"open-dynamic-workflows@open-dynamic-workflows","version":"0.3.0","enabled":true}]}'
assert_odw_list codex-installed true \
  '{"installed":[{"pluginId":"open-dynamic-workflows@open-dynamic-workflows","version":"0.3.0","enabled":true}]}'
assert_odw_list codex-installedPlugins true \
  '{"installedPlugins":[{"pluginId":"open-dynamic-workflows@open-dynamic-workflows","version":"0.3.0","enabled":true}]}'
assert_odw_list marketplace-twin false \
  '{"plugins":[{"id":"open-dynamic-workflows@atebites-plugins","version":"0.3.0","enabled":true}]}'
assert_odw_list zcode-disabled false \
  '{"plugins":[{"id":"open-dynamic-workflows@open-dynamic-workflows","version":"0.3.0","enabled":false}]}'
assert_odw_list zcode-wrong-version false \
  '{"plugins":[{"id":"open-dynamic-workflows@open-dynamic-workflows","version":"0.2.0","enabled":true}]}'
pass "odw list matcher accepts ZCode .plugins[] and Codex installed shapes"

unsupported_home=$tmp_dir/unsupported
if ADVISOR_CONFIG_HOME=$unsupported_home ADVISOR_MODEL_CATALOG=$catalog sh "$advisor" configure --host codex \
  --advisor-model missing/model --advisor-effort ultra \
  --grunt-model gpt-5.6-luna --grunt-effort high >/dev/null 2>&1; then
  fail "configure accepted a tuple rejected by the available model catalog"
fi
[ ! -e "$unsupported_home/codex.json" ] || fail "unsupported configure left a profile"

unverified_home=$tmp_dir/unverified
ADVISOR_CONFIG_HOME=$unverified_home ADVISOR_MODEL_CATALOG=$tmp_dir/missing-catalog sh "$advisor" configure --host codex \
  --advisor-model custom/advisor --advisor-effort max \
  --grunt-model custom/grunt --grunt-effort medium >/dev/null
if ADVISOR_CONFIG_HOME=$unverified_home ADVISOR_MODEL_CATALOG=$tmp_dir/missing-catalog sh "$advisor" doctor --host codex --json > "$tmp_dir/unverified-doctor.json"; then
  fail "doctor accepted tuples without an authoritative catalog"
fi
jq -e '.code == "model_capability_unverified" and .strict == false' "$tmp_dir/unverified-doctor.json" >/dev/null ||
  fail "unverified doctor result used the wrong machine code"
pass "catalog-backed rejection and unverified capability gate"

for host_code in 'cursor runtime_effort_attestation_unavailable' 'claude native_advisor_unverified' 'grok hook_failure_is_fail_open'; do
  set -- $host_code
  if run_advisor doctor --host "$1" --json > "$tmp_dir/$1.json"; then
    fail "$1 doctor unexpectedly reported strict support"
  fi
  jq -e --arg host "$1" --arg code "$2" '.host == $host and .code == $code and .strict == false' "$tmp_dir/$1.json" >/dev/null ||
    fail "$1 doctor used the wrong capability code"
done
jq -e '
  .diagnostics.enforcementHook == false and (.diagnostics.nativeGaps | type == "array") and
  (.diagnostics.odwGaps | type == "array") and
  .checks.hooks.trustObservable == false and .checks.hooks.trusted == false
' "$tmp_dir/cursor.json" >/dev/null || fail "Cursor doctor omitted first-class diagnostics"
jq -e '
  .diagnostics.seating == "defer_to_native_when_present" and
  .diagnostics.nativeAdvisor == "unverified" and
  .diagnostics.nativeOrchestrator == "ultracode" and
  .diagnostics.pluginStrict == false and
  .diagnostics.odwDefault == false and
  .odwLane == "disabled" and .nativeLane == "disabled" and
  .checks.hooks.trustObservable == false and .checks.hooks.trusted == false
' "$tmp_dir/claude.json" >/dev/null || fail "Claude doctor omitted native-first diagnostics"
jq -e '.checks.hooks.trustObservable == false and .checks.hooks.trusted == false' \
  "$tmp_dir/grok.json" >/dev/null || fail "Grok doctor invented hook trust"
if run_advisor doctor --host grok-bot --json >/dev/null 2>&1; then fail "Grok Bot was not excluded"; fi
pass "truthful Cursor Claude Grok and Grok Bot capability status"

symlink_home=$tmp_dir/symlink
mkdir -p "$symlink_home"
ln -s "$profile" "$symlink_home/codex.json"
if ADVISOR_CONFIG_HOME=$symlink_home ADVISOR_MODEL_CATALOG=$catalog sh "$advisor" doctor --host codex --json >/dev/null 2>&1; then
  fail "doctor accepted a symlinked profile"
fi
if ADVISOR_CONFIG_HOME=$symlink_home ADVISOR_MODEL_CATALOG=$catalog sh "$advisor" configure --host codex \
  --advisor-model gpt-5.6-sol --advisor-effort ultra --grunt-model gpt-5.6-luna --grunt-effort high >/dev/null 2>&1; then
  fail "configure replaced a symlinked profile"
fi
pass "symlinked profile refusal"

remove_home=$tmp_dir/remove
ADVISOR_CONFIG_HOME=$remove_home ADVISOR_MODEL_CATALOG=$catalog sh "$advisor" configure --host codex \
  --advisor-model gpt-5.6-sol --advisor-effort ultra --grunt-model gpt-5.6-luna --grunt-effort high >/dev/null
ADVISOR_CONFIG_HOME=$remove_home ADVISOR_MODEL_CATALOG=$catalog ADVISOR_AGENT_DIR=$remove_home/agents sh "$advisor" apply --host codex >/dev/null
[ -f "$remove_home/agents/advisor-grunt.toml" ] || fail "apply did not install the rendered Codex role"
applied_doctor=$(ADVISOR_CONFIG_HOME=$remove_home ADVISOR_MODEL_CATALOG=$catalog ADVISOR_AGENT_DIR=$remove_home/agents sh "$advisor" doctor --host codex --json || true)
printf '%s\n' "$applied_doctor" | jq -e '.checks.generatedFiles.current == true and (has("diagnostics") | not)' >/dev/null || fail "doctor did not recognize the exact generated Codex role"
mkdir -p "$remove_home/sessions"
printf '%s\n' keep > "$remove_home/unrelated.txt"
runtime_id=11111111-1111-4111-8111-111111111111
malformed_policy=$(jq -cn '{advisorModel:1,advisorEffort:"ultra",gruntModel:"gpt-5.6-luna",gruntEffort:"high"}')
malformed_fingerprint=$(printf '%s' "$malformed_policy" | shasum -a 256 | awk '{print $1}')
jq -n --arg runtime "$runtime_id" --arg fingerprint "$malformed_fingerprint" --argjson policy "$malformed_policy" \
  '{schemaVersion:1,host:"codex",runtimeId:$runtime,policy:$policy,policyFingerprint:$fingerprint,createdAt:"2026-08-21T00:00:00Z"}' > "$remove_home/sessions/$runtime_id.json"
chmod 600 "$remove_home/sessions/$runtime_id.json"
if ADVISOR_CONFIG_HOME=$remove_home ADVISOR_MODEL_CATALOG=$catalog ADVISOR_AGENT_DIR=$remove_home/agents sh "$advisor" remove --host codex >/dev/null 2>&1; then
  fail "remove accepted a malformed snapshot ownership record"
fi
[ -f "$remove_home/codex.json" ] && [ -f "$remove_home/agents/advisor-grunt.toml" ] && [ -f "$remove_home/sessions/$runtime_id.json" ] || fail "failed remove partially deleted Advisor state"
policy=$(jq -cn '{advisorModel:"gpt-5.6-sol",advisorEffort:"ultra",gruntModel:"gpt-5.6-luna",gruntEffort:"high"}')
fingerprint=$(printf '%s' "$policy" | shasum -a 256 | awk '{print $1}')
jq -n --arg runtime "$runtime_id" --arg fingerprint "$fingerprint" --argjson policy "$policy" \
  '{schemaVersion:1,host:"codex",runtimeId:$runtime,policy:$policy,policyFingerprint:$fingerprint,createdAt:"2026-08-21T00:00:00Z"}' > "$remove_home/sessions/$runtime_id.json"
chmod 600 "$remove_home/sessions/$runtime_id.json"
ADVISOR_CONFIG_HOME=$remove_home ADVISOR_MODEL_CATALOG=$catalog ADVISOR_AGENT_DIR=$remove_home/agents sh "$advisor" remove --host codex >/dev/null
[ ! -e "$remove_home/codex.json" ] && [ ! -e "$remove_home/sessions/$runtime_id.json" ] && [ ! -e "$remove_home/agents/advisor-grunt.toml" ] || fail "remove left Advisor-owned state"
[ "$(cat "$remove_home/unrelated.txt")" = keep ] || fail "remove changed an unrelated file"
ADVISOR_CONFIG_HOME=$remove_home ADVISOR_MODEL_CATALOG=$catalog ADVISOR_AGENT_DIR=$remove_home/agents sh "$advisor" remove --host codex >/dev/null
pass "remove is scoped and idempotent"

printf '%s\n' "VERIFY CONFIG PASSED"
