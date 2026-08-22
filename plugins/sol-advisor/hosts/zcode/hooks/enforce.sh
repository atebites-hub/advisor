#!/bin/sh
set -eu

fail() { printf '%s\n' "ZCODE_STRICT_ADVISOR_HOOK_FAILURE: $*" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || fail "jq is unavailable"
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || fail "hook directory is unavailable"
plugin_root=$(CDPATH= cd "$script_dir/../../.." && pwd) || fail "Advisor package root is unavailable"
payload=$(jq -ce 'if type == "object" then . else error("invalid") end' 2>/dev/null) || fail "malformed hook payload"
tool=$(printf '%s\n' "$payload" | jq -r '.toolName // .tool_name // empty')
if [ "${ZCODE_ODW_PROTOCOL-}" = 1 ]; then
  printf '%s\n' "$payload" | jq -e '
    .runtimeAttestation as $a |
    ($a | type) == "object" and
    ($a | keys) == ["executor","model","parentSessionId","policySource","reasoningEffort","role","rolePolicy","rolePolicyFingerprint","route","runtimeId","runtimeVersion","schemaVersion","sessionId","type"] and
    $a.type == "zcode_runtime_attestation" and $a.schemaVersion == 1 and
    $a.executor == "zcode" and $a.route == "odw" and $a.runtimeVersion == "0.16.3" and
    ($a.runtimeId | type == "string" and length > 0) and $a.sessionId == $a.runtimeId and
    $a.role == "main" and $a.parentSessionId == null and $a.policySource == null and
    $a.rolePolicy == null and $a.rolePolicyFingerprint == null and
    ($a.model | type == "string" and length > 0) and
    ($a.reasoningEffort | type == "string" and length > 0)
  ' >/dev/null 2>&1 || fail "ODW worker attestation is missing, malformed, or native"
  case "$tool" in Agent|spawn_agent|spawn_subagent) fail "ODW workers cannot spawn nested native agents" ;; esac
  printf '%s\n' '{"continue":true}'
  exit 0
fi
att_role=$(printf '%s\n' "$payload" | jq -r '.runtimeAttestation.role // empty')
case "$att_role" in main) role=advisor ;; lite) role=grunt ;; *) fail "runtime role is unavailable" ;; esac
event=$(printf '%s\n' "$payload" | jq -r '.hookEventName // .hook_event_name // empty')
if [ -n "${ZCODE_CONFIG-}" ]; then config=$ZCODE_CONFIG
else [ -n "${HOME-}" ] || fail "HOME is unset"; config=$HOME/.zcode/cli/config.json
fi
printf '%s\n' "$payload" | sh "$plugin_root/scripts/inspect-zcode-runtime.sh" --mode native --role "$role" --config "$config" >/dev/null || fail "runtime attestation was rejected"
case "$tool" in Agent|spawn_agent|spawn_subagent)
  [ "$role" = advisor ] || fail "native grunt sessions cannot delegate"
  case "$event" in
    PreToolUse)
      printf '%s\n' "$payload" | jq -e '
        (.toolInput // .tool_input) as $input | ($input | type) == "object" and
        ($input | has("model") | not) and ($input | has("reasoning_effort") | not) and
        ($input | has("reasoningEffort") | not) and (($input.run_in_background // false) == false)
      ' >/dev/null 2>&1 || fail "native child route must be foreground with no alternate model or effort"
      ;;
    PostToolUse)
      child_payload=$(printf '%s\n' "$payload" | jq -ce '
        . as $event | .runtimeAttestation as $parent | .childRuntimeEvidence as $child |
        if ($event.toolCallId | type == "string" and length > 0) and
          ($child | type == "object" and keys == ["childSessionId","parentSessionId","parentToolCallId","runtimeAttestation","state"]) and
          ($child.childSessionId | type == "string" and length > 0) and
          ($child.parentSessionId | type == "string" and length > 0) and
          ($child.parentToolCallId | type == "string" and length > 0) and
          $child.state == "completed" and
          $child.parentSessionId == $parent.runtimeId and $child.parentToolCallId == $event.toolCallId and
          $child.childSessionId == $child.runtimeAttestation.runtimeId and
          $child.childSessionId == $child.runtimeAttestation.sessionId and
          $child.runtimeAttestation.parentSessionId == $parent.runtimeId and
          $child.runtimeAttestation.rolePolicy == $parent.rolePolicy and
          $child.runtimeAttestation.rolePolicyFingerprint == $parent.rolePolicyFingerprint
        then {hookEventName:"PostToolUse",state:$child.state,runtimeAttestation:$child.runtimeAttestation}
        else error("unjoined child evidence") end
      ' 2>/dev/null) || fail "native child completion evidence is missing or does not join the parent tool call"
      printf '%s\n' "$child_payload" | sh "$plugin_root/scripts/inspect-zcode-runtime.sh" --mode native --role grunt >/dev/null || fail "native child completion evidence was rejected"
      ;;
    PostToolUseFailure) fail "native child execution failed" ;;
    *) fail "native delegation hook event is unsupported" ;;
  esac
  ;;
esac
printf '%s\n' '{"continue":true}'
