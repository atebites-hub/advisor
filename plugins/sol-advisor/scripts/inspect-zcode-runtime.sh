#!/bin/sh
set -eu

fail() { printf '%s\n' "ERROR: $*" >&2; exit 1; }
valid_id() { printf '%s\n' "$1" | LC_ALL=C grep -Eq '^sess_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; }
valid_token() { printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:+/-]{0,255}$'; }
file_mode() { stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1" 2>/dev/null; }

command -v jq >/dev/null 2>&1 || fail "jq is unavailable."
expected_runtime_version=0.16.3
mode= role= config= route= result=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode|--role|--config|--route|--result)
      option=$1; [ "$#" -ge 2 ] && [ -n "$2" ] || fail "$option requires a value."
      case "$2" in --*) fail "$option requires an explicit value." ;; esac
      case "$option" in
        --mode) [ -z "$mode" ] || fail "duplicate --mode."; mode=$2 ;;
        --role) [ -z "$role" ] || fail "duplicate --role."; role=$2 ;;
        --config) [ -z "$config" ] || fail "duplicate --config."; config=$2 ;;
        --route) [ -z "$route" ] || fail "duplicate --route."; route=$2 ;;
        --result) [ -z "$result" ] || fail "duplicate --result."; result=$2 ;;
      esac
      shift 2 ;;
    *) fail "unknown or positional argument: $1" ;;
  esac
done
case "$mode" in native|odw) ;; '') fail "--mode is required." ;; *) fail "unknown mode: $mode" ;; esac

validate_attestation='def nonempty: type == "string" and length > 0;
  type == "object" and keys == ["executor","model","parentSessionId","policySource","reasoningEffort","role","rolePolicy","rolePolicyFingerprint","route","runtimeId","runtimeVersion","schemaVersion","sessionId","type"] and
  .type == "zcode_runtime_attestation" and .schemaVersion == 1 and .executor == "zcode" and
  (.runtimeId | nonempty) and (.sessionId | nonempty) and .runtimeId == .sessionId and
  (.runtimeVersion | nonempty) and (.model | nonempty) and (.reasoningEffort | nonempty)'

if [ "$mode" = native ]; then
  case "$role" in advisor|grunt) ;; *) fail "native mode requires --role advisor|grunt." ;; esac
  [ -z "$route$result" ] || fail "native mode does not accept --route or --result."
  payload=$(jq -ce 'if type == "object" then . else error("invalid payload") end' 2>/dev/null) || fail "native hook payload is malformed."
  attestation=$(printf '%s\n' "$payload" | jq -ce --arg version "$expected_runtime_version" "
    .runtimeAttestation as \$a |
    if (\$a | $validate_attestation) and \$a.route == \"native\" and \$a.runtimeVersion == \$version and
      (\$a.rolePolicy | type == \"object\" and keys == [\"advisorEffort\",\"advisorModel\",\"gruntEffort\",\"gruntModel\"] and all(.[]; type == \"string\" and length > 0)) and
      (\$a.rolePolicyFingerprint | type == \"string\" and test(\"^[a-f0-9]{64}\$\")) and
      (\$a.policySource == \"new\" or \$a.policySource == \"persisted\" or \$a.policySource == \"parent\")
    then \$a else error(\"invalid native attestation\") end
  " 2>/dev/null) || fail "native runtime attestation is missing, malformed, fallback, or wrong-version."
  runtime_id=$(printf '%s\n' "$attestation" | jq -r '.runtimeId'); valid_id "$runtime_id" || fail "native runtime id is invalid."
  policy=$(printf '%s\n' "$attestation" | jq -c '{advisorModel:.rolePolicy.advisorModel,advisorEffort:.rolePolicy.advisorEffort,gruntModel:.rolePolicy.gruntModel,gruntEffort:.rolePolicy.gruntEffort}')
  fingerprint=$(printf '%s' "$policy" | shasum -a 256 | awk '{print $1}')
  [ "$fingerprint" = "$(printf '%s\n' "$attestation" | jq -r '.rolePolicyFingerprint')" ] || fail "native role policy fingerprint is invalid."
  if [ "$role" = advisor ]; then
    printf '%s\n' "$attestation" | jq -e '.role == "main" and .parentSessionId == null and (.policySource == "new" or .policySource == "persisted") and .model == .rolePolicy.advisorModel and .reasoningEffort == .rolePolicy.advisorEffort' >/dev/null || fail "native advisor role, source, or tuple is invalid."
    parent=null; output_role=advisor
    event=$(printf '%s\n' "$payload" | jq -r '.hookEventName // .hook_event_name // empty')
    source=$(printf '%s\n' "$attestation" | jq -r '.policySource')
    if [ "$event" = SessionStart ] && [ "$source" = new ]; then
      if [ -z "$config" ]; then
        if [ -n "${ZCODE_CONFIG-}" ]; then config=$ZCODE_CONFIG
        else [ -n "${HOME-}" ] || fail "HOME is unset; pass --config."; config=$HOME/.zcode/cli/config.json
        fi
      fi
      [ -f "$config" ] && [ ! -L "$config" ] || fail "ZCode config is unavailable or unsafe."
      configured=$(jq -ce '
        if .plugins.enabled == true and .plugins.enabledPlugins["sol-advisor@sol-advisor"] == true and
        (.plugins.options["sol-advisor@sol-advisor"] | type == "object" and keys == ["advisor_effort","advisor_model","grunt_effort","grunt_model"] and all(.[]; type == "string" and length > 0))
        then .plugins.options["sol-advisor@sol-advisor"] else error("invalid settings") end
      ' "$config" 2>/dev/null) || fail "enabled Advisor plugin settings are incomplete or ambiguous."
      printf '%s\n' "$configured" | jq -e --argjson policy "$policy" '.advisor_model == $policy.advisorModel and .advisor_effort == $policy.advisorEffort and .grunt_model == $policy.gruntModel and .grunt_effort == $policy.gruntEffort' >/dev/null || fail "new root policy does not match current plugin settings."
    fi
  else
    printf '%s\n' "$attestation" | jq -e '.role == "lite" and (.parentSessionId | type == "string" and length > 0) and .parentSessionId != .runtimeId and .policySource == "parent" and .model == .rolePolicy.gruntModel and .reasoningEffort == .rolePolicy.gruntEffort' >/dev/null || fail "native grunt role, parent, source, or tuple is invalid."
    parent=$(printf '%s\n' "$attestation" | jq -r '.parentSessionId'); valid_id "$parent" || fail "native grunt parent id is invalid."
    output_role=advisor_grunt
  fi
  model=$(printf '%s\n' "$attestation" | jq -r '.model'); effort=$(printf '%s\n' "$attestation" | jq -r '.reasoningEffort')
  valid_token "$model" && valid_token "$effort" || fail "native observed tuple is unsafe."
  state=$(printf '%s\n' "$payload" | jq -r '.state // "running"')
  case "$state" in running|completed) ;; *) fail "native runtime state is not usable." ;; esac
  jq -cn --arg runtime "$runtime_id" --arg parent "$parent" --arg role "$output_role" --arg model "$model" --arg effort "$effort" --arg state "$state" \
    '{runtime_id:$runtime,parent_runtime_id:(if $parent == "null" then null else $parent end),role:$role,model:$model,effort:$effort,state:$state}'
  exit 0
fi

[ -z "$role$config" ] || fail "ODW mode does not accept --role or --config."
[ -n "$route" ] && [ -n "$result" ] || fail "ODW mode requires --route and --result."
[ -f "$route" ] && [ ! -L "$route" ] && [ "$(file_mode "$route")" = 600 ] || fail "ODW route is unavailable, unsafe, or not mode 600."
route_json=$(jq -ce 'if type == "object" and keys == ["executor","model","reasoningEffort"] and .executor == "zcode" and all(.[]; type == "string" and length > 0) then . else error("invalid route") end' "$route" 2>/dev/null) || fail "ODW route schema is invalid."
[ -f "$result" ] && [ ! -L "$result" ] || fail "ODW result is unavailable or unsafe."
runtime_id=$(jq -r '.routing.runtimeId // empty' "$result" 2>/dev/null); valid_id "$runtime_id" || fail "ODW runtime id is invalid."
canonical=$(printf '%s\n' "$route_json" | jq -c '{executor,model,reasoningEffort}')
fingerprint=$(printf '%s' "$canonical" | shasum -a 256 | awk '{print $1}')
attestation=$(jq -ce --arg runtime "$runtime_id" --arg version "$expected_runtime_version" --arg fingerprint "$fingerprint" --argjson route "$route_json" "
  if type == \"object\" and .command == \"zcode\" and .exitCode == 0 and .isError == false and .resultSubtype == \"success\" and
    .routing.runtimeId == \$runtime and .routing.policyFingerprint == \$fingerprint and .routing.executor == \$route.executor and .routing.model == \$route.model and .routing.reasoningEffort == \$route.reasoningEffort and
    ([.events[]? | select(.type == \"zcode_result\")] | length) == 1
  then [.events[] | select(.type == \"zcode_result\")][0].runtimeAttestation else error(\"invalid result\") end |
  if (. | $validate_attestation) and .route == \"odw\" and .runtimeVersion == \$version and .runtimeId == \$runtime and
    .role == \"main\" and .parentSessionId == null and .policySource == null and .rolePolicy == null and .rolePolicyFingerprint == null and
    .model == \$route.model and .reasoningEffort == \$route.reasoningEffort
  then . else error(\"invalid ODW attestation\") end
" "$result" 2>/dev/null) || fail "ODW ZCode result or runtime attestation is invalid."
jq -cn --arg runtime "$runtime_id" --arg model "$(printf '%s\n' "$attestation" | jq -r '.model')" --arg effort "$(printf '%s\n' "$attestation" | jq -r '.reasoningEffort')" \
  '{runtime_id:$runtime,parent_runtime_id:null,role:"odw",model:$model,effort:$effort,state:"completed"}'
