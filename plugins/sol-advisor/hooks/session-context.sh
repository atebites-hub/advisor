#!/bin/sh
set -eu

fail() { printf '%s\n' "ERROR: $*" >&2; exit 1; }
path_exists() { [ -e "$1" ] || [ -L "$1" ]; }
valid_id() { printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; }
valid_model() { printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:+/-]{0,255}$'; }
valid_effort() { printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'; }

command -v jq >/dev/null 2>&1 || fail "jq is unavailable."
plugin_root=${PLUGIN_ROOT-}
case "$plugin_root" in /*) ;; *) fail "PLUGIN_ROOT must be absolute." ;; esac
skill=$plugin_root/skills/orchestration/SKILL.md
[ -f "$skill" ] && [ ! -L "$skill" ] || fail "Advisor orchestration skill is unavailable."

payload=$(jq -ce 'if type == "object" then . else error("invalid hook payload") end' 2>/dev/null) || fail "invalid hook payload."
event=$(printf '%s\n' "$payload" | jq -r '.hook_event_name // empty')

if [ "$event" = SubagentStart ]; then
  agent_type=$(printf '%s\n' "$payload" | jq -r '.agent_type // empty')
  [ "$agent_type" = advisor_grunt ] || exit 0
  agent_id=$(printf '%s\n' "$payload" | jq -r '.agent_id // empty')
  [ -n "$agent_id" ] || fail "advisor_grunt SubagentStart omitted agent_id."
  cat <<'EOF'
# Advisor bounded grunt

Execute only the supplied bounded objective within its explicit ownership,
interfaces, constraints, and verification. Preserve concurrent edits; do not
broaden scope, spawn subagents, accept your own result, or render the final verdict.
Return exact changes, checks, evidence, and remaining concerns to the advisor.
EOF
  exit 0
fi

[ "$event" = SessionStart ] || fail "unsupported hook event."
source=$(printf '%s\n' "$payload" | jq -r '.source // empty')
case "$source" in startup|resume|clear|compact) ;; *) fail "invalid SessionStart source." ;; esac
runtime_id=$(printf '%s\n' "$payload" | jq -r '.session_id // empty')
valid_id "$runtime_id" || fail "SessionStart omitted a valid session_id."

if [ "${ODW_HOST-}" = codex ] && [ "${ODW_REQUIRE_CWD-}" = 1 ]; then
  cat <<'EOF'
# Advisor ODW grunt

Execute only the bounded workflow-node prompt. Do not declare a route, spawn native
subagents, launch nested workflows, broaden scope, or render the final verdict.
Return exact work and verification evidence to the outer advisor. The ODW run owns
route selection; its immutable policy and completed runtime trace are the proof.
EOF
  exit 0
fi

if [ -n "${ADVISOR_CONFIG_HOME-}" ]; then config_dir=$ADVISOR_CONFIG_HOME
elif [ -n "${XDG_CONFIG_HOME-}" ]; then config_dir=$XDG_CONFIG_HOME/advisor
else [ -n "${HOME-}" ] || fail "HOME is unset."; config_dir=$HOME/.config/advisor
fi
case "$config_dir" in /*) ;; *) config_dir=$(pwd -P)/$config_dir ;; esac
case "$config_dir" in /|//) fail "refusing filesystem root as Advisor config home." ;; esac
profile=$config_dir/codex.json
sessions=$config_dir/sessions
snapshot=$sessions/$runtime_id.json
if path_exists "$config_dir" && { [ -L "$config_dir" ] || [ ! -d "$config_dir" ]; }; then fail "Advisor config home is unsafe."; fi
if path_exists "$sessions" && { [ -L "$sessions" ] || [ ! -d "$sessions" ]; }; then fail "Advisor sessions path is unsafe."; fi

validate_snapshot() {
  [ -f "$snapshot" ] && [ ! -L "$snapshot" ] || return 1
  if stat -c %a "$snapshot" >/dev/null 2>&1; then
    mode=$(stat -c %a "$snapshot")
  else
    mode=$(stat -f %Lp "$snapshot")
  fi || return 1
  [ "$mode" = 600 ] || return 1
  jq -e --arg runtime "$runtime_id" '
    type == "object" and keys == ["createdAt","host","policy","policyFingerprint","runtimeId","schemaVersion"] and
    .schemaVersion == 1 and .host == "codex" and .runtimeId == $runtime and
    (.createdAt | type == "string" and length > 0) and
    (.policyFingerprint | type == "string" and test("^[a-f0-9]{64}$")) and
    (.policy | type == "object" and keys == ["advisorEffort","advisorModel","gruntEffort","gruntModel"] and all(.[]; type == "string" and length > 0))
  ' "$snapshot" >/dev/null 2>&1 || return 1
  canonical=$(jq -c '{advisorModel:.policy.advisorModel,advisorEffort:.policy.advisorEffort,gruntModel:.policy.gruntModel,gruntEffort:.policy.gruntEffort}' "$snapshot")
  [ "$(printf '%s' "$canonical" | shasum -a 256 | awk '{print $1}')" = "$(jq -r '.policyFingerprint' "$snapshot")" ]
}

if path_exists "$snapshot"; then
  validate_snapshot || fail "existing session policy snapshot is unsafe or invalid."
  [ "$source" != startup ] || fail "duplicate startup session policy snapshot."
else
  [ "$source" = startup ] || fail "restored session has no immutable policy snapshot."
  advisor_model=gpt-5.6-sol; advisor_effort=ultra; grunt_model=gpt-5.6-luna; grunt_effort=high
  if path_exists "$profile"; then
    [ -f "$profile" ] && [ ! -L "$profile" ] || fail "Codex profile is unsafe."
    jq -e '
      type == "object" and keys == ["advisor","grunt","host","schemaVersion"] and .schemaVersion == 1 and .host == "codex" and
      (.advisor | type == "object" and keys == ["effort","model"]) and (.grunt | type == "object" and keys == ["effort","model"])
    ' "$profile" >/dev/null 2>&1 || fail "Codex profile schema is invalid."
    advisor_model=$(jq -r '.advisor.model' "$profile"); advisor_effort=$(jq -r '.advisor.effort' "$profile")
    grunt_model=$(jq -r '.grunt.model' "$profile"); grunt_effort=$(jq -r '.grunt.effort' "$profile")
  fi
  valid_model "$advisor_model" && valid_effort "$advisor_effort" && valid_model "$grunt_model" && valid_effort "$grunt_effort" || fail "profile tuple is unsafe."
  canonical=$(jq -cn --arg am "$advisor_model" --arg ae "$advisor_effort" --arg gm "$grunt_model" --arg ge "$grunt_effort" '{advisorModel:$am,advisorEffort:$ae,gruntModel:$gm,gruntEffort:$ge}')
  fingerprint=$(printf '%s' "$canonical" | shasum -a 256 | awk '{print $1}')
  mkdir -p "$sessions" || fail "could not create session snapshot directory."
  [ -d "$sessions" ] && [ ! -L "$sessions" ] || fail "session snapshot directory changed during setup."
  chmod 700 "$sessions" || fail "could not secure session snapshot directory."
  staged=$(mktemp "$sessions/.snapshot.XXXXXX") || fail "could not stage session snapshot."
  cleanup() { [ -z "${staged-}" ] || rm -f "$staged"; }
  trap cleanup 0 HUP INT TERM
  created=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  jq -n --arg runtime "$runtime_id" --arg created "$created" --arg fingerprint "$fingerprint" --argjson policy "$canonical" \
    '{schemaVersion:1,host:"codex",runtimeId:$runtime,policy:$policy,policyFingerprint:$fingerprint,createdAt:$created}' > "$staged" || fail "could not render session snapshot."
  chmod 600 "$staged" || fail "could not secure session snapshot."
  ln "$staged" "$snapshot" || fail "session snapshot already exists or could not be installed."
  rm -f "$staged"; staged=; trap - 0 HUP INT TERM
fi

cat "$skill"
