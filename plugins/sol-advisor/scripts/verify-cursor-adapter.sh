#!/bin/sh
set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }
must_fail() { label=$1; shift; if "$@" >/dev/null 2>&1; then fail "$label unexpectedly succeeded"; fi; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1
advisor=$plugin_dir/bin/advisor
installer=$script_dir/install-cursor.sh
finder=$script_dir/find-helper.sh
cursor_hooks=$plugin_dir/hosts/cursor/hooks/hooks.json
cursor_session=$plugin_dir/hosts/cursor/hooks/session-context.sh
cursor_commands=$plugin_dir/hosts/cursor/commands
odw_inspector=$script_dir/inspect-odw-run.sh

tmp_base=${TMPDIR:-/tmp}; case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_base=$(CDPATH= cd "$tmp_base" && pwd -P)
tmp=$(mktemp -d "$tmp_base/advisor-cursor-verify.XXXXXX") || fail "could not create test directory"
cleanup() { case "$tmp" in "$tmp_base"/advisor-cursor-verify.*) rm -rf "$tmp" ;; esac; }
trap cleanup 0 HUP INT TERM

allowed_plugin_keys='["agents","author","category","commands","description","displayName","homepage","hooks","keywords","license","logo","mcpServers","minClientVersions","name","publisher","repository","rules","skills","tags","variables","version"]'
jq -e --argjson allowed "$allowed_plugin_keys" '
  .name == "sol-advisor" and .displayName == "Advisor" and .version == "0.9.3" and
  .skills == "./plugins/sol-advisor/skills" and
  .commands == "./plugins/sol-advisor/hosts/cursor/commands" and
  .hooks == "./plugins/sol-advisor/hosts/cursor/hooks/hooks.json" and
  (has("agents") | not) and (has("mcpServers") | not) and (has("variables") | not) and
  (.description | test("Cursor CLI"; "i")) and
  (.description | test("strict delegation"; "i")) and
  ((keys - $allowed) | length) == 0 and
  (.author | type == "object" and (keys - ["email","name"] | length) == 0 and (.name | type == "string" and length > 0))
' "$repo_dir/.cursor-plugin/plugin.json" >/dev/null || fail "Cursor plugin.json is not official-schema valid or overclaims"

jq -e '
  .name == "sol-advisor" and (.plugins | length) == 1 and
  ((keys - ["metadata","name","owner","plugins"]) | length) == 0 and
  (.owner | type == "object" and (keys - ["email","name"] | length) == 0) and
  (.plugins[0].name == "sol-advisor") and
  (.plugins[0].source == ".") and
  (.plugins[0].description | type == "string" and length > 0) and
  ((.plugins[0] | keys) - ["description","minClientVersions","name","source"] | length) == 0 and
  (.plugins[0] | has("version") | not) and (.plugins[0] | has("keywords") | not)
' "$repo_dir/.cursor-plugin/marketplace.json" >/dev/null || fail "Cursor marketplace.json is not official-schema valid"
pass "Cursor plugin.json and marketplace.json match the official Cursor schemas"

for skill in advisor orchestration; do
  skill_file=$plugin_dir/skills/$skill/SKILL.md
  [ -f "$skill_file" ] || fail "missing skill: $skill"
  awk '
    BEGIN { fm=0; name=0; desc=0 }
    NR==1 && $0=="---" { fm=1; next }
    fm==1 && $0=="---" { exit }
    fm==1 && $0 ~ /^name:[[:space:]]*[^[:space:]]/ { name=1 }
    fm==1 && $0 ~ /^description:[[:space:]]*.+/ { desc=1 }
    END { exit !(name && desc) }
  ' "$skill_file" || fail "skill $skill is missing name+description frontmatter"
done
for command in advisor orchestration; do
  command_file=$cursor_commands/$command.md
  [ -f "$command_file" ] || fail "missing Cursor command: $command"
  awk '
    BEGIN { fm=0; name=0; desc=0 }
    NR==1 && $0=="---" { fm=1; next }
    fm==1 && $0=="---" { exit }
    fm==1 && $0 ~ /^name:[[:space:]]*[^[:space:]]/ { name=1 }
    fm==1 && $0 ~ /^description:[[:space:]]*.+/ { desc=1 }
    END { exit !(name && desc) }
  ' "$command_file" || fail "command $command is missing name+description frontmatter"
done
pass "Cursor skills and commands declare name+description"

jq -e '
  .version == 1 and
  (.hooks | keys) == ["sessionStart"] and
  (.hooks.sessionStart | length) == 1 and
  .hooks.sessionStart[0].command == "./plugins/sol-advisor/hosts/cursor/hooks/session-context.sh" and
  (.hooks.sessionStart[0] | has("failClosed") | not) and
  (has("SessionStart") | not) and (has("PreToolUse") | not) and
  ((.hooks | keys | map(select(test("^[A-Z]")))) | length) == 0
' "$cursor_hooks" >/dev/null || fail "Cursor hooks must be camelCase sessionStart activation only"
[ -x "$cursor_session" ] || fail "Cursor sessionStart script is not executable"
if grep -Eq 'PreToolUse|SubagentStart|failClosed' "$cursor_hooks"; then
  fail "Cursor hooks registered enforcement or Codex events"
fi
pass "Cursor registers only a supported sessionStart activation hook"

write_fake_bin() {
  path=$1; contents=$2
  printf '%s\n' "$contents" > "$path"
  chmod 755 "$path"
}

bin_dir=$tmp/bin
mkdir -p "$bin_dir"
write_fake_bin "$bin_dir/cursor-agent" '#!/bin/sh
printf "%s\n" "cursor-agent 1.2.3"
'
write_fake_bin "$bin_dir/agent" '#!/bin/sh
if [ "${1-}" = --help ]; then
  printf "%s\n" "Usage: agent [options]" "--plugin-dir <path>" "agent mcp"
  exit 0
fi
printf "%s\n" "0.1.0"
'
write_fake_bin "$bin_dir/cursor" '#!/bin/sh
printf "%s\n" "Cursor 1.2.3"
'
write_fake_bin "$tmp/grok-agent" '#!/bin/sh
if [ "${1-}" = --help ]; then
  printf "%s\n" "Usage: grok agent"
  exit 0
fi
printf "%s\n" "grok 1.0.5"
'

PATH="$bin_dir:$PATH" HOME=$tmp ADVISOR_CONFIG_HOME=$tmp/config \
  sh "$advisor" doctor --host cursor --json > "$tmp/doctor-cursor-agent.json" || true
jq -e '
  .host == "cursor" and .strict == false and .code == "runtime_effort_attestation_unavailable" and
  .nativeLane == "disabled" and .odwLane == "disabled" and
  .checks.hostCli.present == true and
  (.checks.hostCli.version | test("cursor-agent"; "i")) and
  .diagnostics.cliBinary == "cursor-agent" and .diagnostics.cliKind == "cursor-agent" and
  .diagnostics.activationHook == true and .diagnostics.enforcementHook == false and
  (.diagnostics.nativeGaps | index("plugin_agents_cannot_pin_model_or_effort") >= 0) and
  (.diagnostics.nativeGaps | index("subagent_start_omits_child_effort") >= 0) and
  (.diagnostics.nativeGaps | index("subagent_stop_omits_child_model_and_effort") >= 0) and
  (.diagnostics.nativeGaps | index("hook_model_params_are_selected_settings") >= 0) and
  (.diagnostics.nativeGaps | index("hook_runner_fail_open") >= 0) and
  (.diagnostics.odwGaps | index("cursor_cli_has_no_effort_flag") >= 0) and
  (.diagnostics.odwGaps | index("print_result_omits_model_and_effort") >= 0) and
  (.diagnostics.odwGaps | index("stream_init_model_is_display_name") >= 0) and
  (.diagnostics.odwGaps | index("requested_model_is_not_runtime_attestation") >= 0) and
  (.diagnostics.odwGaps | index("no_role_or_parent_evidence") >= 0)
' "$tmp/doctor-cursor-agent.json" >/dev/null || fail "cursor-agent doctor did not report honest Cursor diagnostics"

mkdir -p "$tmp/agent-only/bin"
write_fake_bin "$tmp/agent-only/bin/agent" '#!/bin/sh
if [ "${1-}" = --help ]; then
  printf "%s\n" "Usage: agent [options]" "--plugin-dir <path>"
  exit 0
fi
if [ "${1-}" = --version ]; then
  printf "%s\n" "agent 2.0.0"
  exit 0
fi
printf "%s\n" "agent 2.0.0"
'
PATH="$tmp/agent-only/bin:/usr/bin:/bin" HOME=$tmp ADVISOR_CONFIG_HOME=$tmp/config \
  sh "$advisor" doctor --host cursor --json > "$tmp/doctor-agent.json" || true
jq -e '.diagnostics.cliBinary == "agent" and .diagnostics.cliKind == "cursor-cli-agent" and .strict == false' \
  "$tmp/doctor-agent.json" >/dev/null || fail "Cursor CLI agent binary was not recognized"

mkdir -p "$tmp/grok-only/bin"
cp "$tmp/grok-agent" "$tmp/grok-only/bin/agent"
chmod 755 "$tmp/grok-only/bin/agent"
PATH="$tmp/grok-only/bin:/usr/bin:/bin" HOME=$tmp ADVISOR_CONFIG_HOME=$tmp/config \
  sh "$advisor" doctor --host cursor --json > "$tmp/doctor-grok-agent.json" || true
jq -e '.checks.hostCli.present == false and .diagnostics.cliKind == "none" and .strict == false' \
  "$tmp/doctor-grok-agent.json" >/dev/null || fail "non-Cursor agent binary was claimed as Cursor CLI"
pass "doctor recognizes cursor-agent and Cursor CLI agent, not a Grok agent"

plugin_root=$tmp/plugin-root
mkdir -p "$plugin_root/.cursor-plugin" "$plugin_root/plugins"
cp "$repo_dir/.cursor-plugin/plugin.json" "$plugin_root/.cursor-plugin/plugin.json"
cp -R "$plugin_dir" "$plugin_root/plugins/sol-advisor"
CURSOR_PLUGIN_ROOT=$plugin_root HOME=$tmp PATH=/usr/bin:/bin ADVISOR_CONFIG_HOME=$tmp/config \
  sh "$advisor" doctor --host cursor --json > "$tmp/doctor-plugin-root.json" || true
jq -e --arg root "$plugin_root" '
  .diagnostics.pluginRoot == $root and .diagnostics.pluginRootSource == "CURSOR_PLUGIN_ROOT" and
  .checks.generatedFiles.current == true and .checks.hooks.configured == true
' "$tmp/doctor-plugin-root.json" >/dev/null || fail "CURSOR_PLUGIN_ROOT was not treated as the Cursor plugin root"

PLUGIN_ROOT=$plugin_root HOME=$tmp PATH=/usr/bin:/bin ADVISOR_CONFIG_HOME=$tmp/config \
  sh "$advisor" doctor --host cursor --json > "$tmp/doctor-plugin-root-env.json" || true
jq -e --arg root "$plugin_root" '.diagnostics.pluginRoot == $root and .diagnostics.pluginRootSource == "PLUGIN_ROOT"' \
  "$tmp/doctor-plugin-root-env.json" >/dev/null || fail "PLUGIN_ROOT was not treated as the Cursor plugin root"

ODW_HOST=cursor HOME=$tmp PATH=/usr/bin:/bin ADVISOR_CONFIG_HOME=$tmp/config \
  sh "$advisor" doctor --host cursor --json > "$tmp/doctor-odw-host.json" || true
jq -e '.diagnostics.odwHost == "cursor" and .odwLane == "disabled" and .strict == false' \
  "$tmp/doctor-odw-host.json" >/dev/null || fail "ODW_HOST=cursor was not reported honestly"
pass "doctor honors CURSOR_PLUGIN_ROOT, PLUGIN_ROOT, and ODW_HOST=cursor"

must_fail "Cursor configure" env ADVISOR_CONFIG_HOME=$tmp/config sh "$advisor" configure --host cursor \
  --advisor-model cursor/advisor --advisor-effort max --grunt-model cursor/grunt --grunt-effort high
must_fail "Cursor apply" env ADVISOR_CONFIG_HOME=$tmp/config sh "$advisor" apply --host cursor
must_fail "Cursor remove" env ADVISOR_CONFIG_HOME=$tmp/config sh "$advisor" remove --host cursor
must_fail "Cursor ODW inspect" sh "$odw_inspector" --host cursor "$tmp"
if ! sh "$odw_inspector" --host cursor "$tmp" 2>"$tmp/odw-cursor.err"; then
  grep -Fq 'unsupported Advisor ODW host: cursor' "$tmp/odw-cursor.err" || fail "Cursor ODW rejection did not name the host"
else
  fail "Cursor ODW inspect unexpectedly succeeded"
fi
pass "Cursor still refuses configure/apply/remove and ODW inspection"

HOME=$tmp sh "$installer" --repo "$repo_dir" --mode link >/dev/null
installed=$tmp/.cursor/plugins/local/sol-advisor
[ -L "$installed" ] || fail "default Cursor install is not a symlink of the repository"
[ -f "$installed/.cursor-plugin/plugin.json" ] || fail "linked Cursor plugin is missing its manifest"
[ -x "$installed/plugins/sol-advisor/bin/advisor" ] || fail "linked Cursor plugin is missing the packaged helper"
[ -f "$tmp/.cursor/skills/advisor/SKILL.md" ] || fail "Cursor CLI skills fallback did not install advisor"
[ -f "$tmp/.cursor/skills/orchestration/SKILL.md" ] || fail "Cursor CLI skills fallback did not install orchestration"
if command -v advisor >/dev/null 2>&1; then
  case "$(command -v advisor)" in
    "$tmp"/*) fail "install added advisor to PATH" ;;
  esac
fi
HOME=$tmp sh "$installer" --check >/dev/null || fail "install --check failed for a valid local plugin"
finder_path=$(HOME=$tmp sh "$finder")
[ "$finder_path" = "$installed/plugins/sol-advisor/bin/advisor" ] || fail "find-helper did not resolve the local Cursor plugin helper"
mkdir -p "$tmp/no-plugin"
packaged_helper=$(CURSOR_PLUGIN_ROOT= PLUGIN_ROOT= HOME=$tmp/no-plugin sh "$finder")
[ "$packaged_helper" = "$advisor" ] || fail "find-helper did not fall back to the packaged helper"
case "$packaged_helper" in
  /plugins/*) fail "empty CURSOR_PLUGIN_ROOT resolved to $packaged_helper" ;;
esac

copy_home=$tmp/copy-home
mkdir -p "$copy_home"
HOME=$copy_home sh "$installer" --repo "$repo_dir" --mode copy >/dev/null
copy_plugin=$copy_home/.cursor/plugins/local/sol-advisor
[ -d "$copy_plugin" ] && [ ! -L "$copy_plugin" ] || fail "copy install did not create a real directory"
[ -f "$copy_plugin/.cursor-plugin/plugin.json" ] || fail "copy install omitted plugin.json"
[ -x "$copy_plugin/plugins/sol-advisor/bin/advisor" ] || fail "copy install omitted helper"
pass "Cursor local plugin and ~/.cursor/skills fallback install without a PATH binary"

payload=$tmp/session-start.json
jq -n '{hook_event_name:"sessionStart",session_id:"conv-1",composer_mode:"agent",is_background_agent:false}' > "$payload"
CURSOR_PLUGIN_ROOT=$repo_dir sh "$cursor_session" < "$payload" > "$tmp/session-out.json"
jq -e '.additional_context | type == "string" and test("SELECTIVE ROUTE")' "$tmp/session-out.json" >/dev/null ||
  fail "Cursor sessionStart did not inject orchestration context"
ODW_HOST=cursor CURSOR_PLUGIN_ROOT=$repo_dir sh "$cursor_session" < "$payload" > "$tmp/session-odw.json"
jq -e '.additional_context | type == "string" and (test("bounded") ) and (test("SELECTIVE ROUTE") | not)' \
  "$tmp/session-odw.json" >/dev/null || fail "Cursor ODW worker context claimed Advisor routing"
printf '%s\n' 'not-json' > "$tmp/bad-session.json"
CURSOR_PLUGIN_ROOT=$repo_dir sh "$cursor_session" < "$tmp/bad-session.json" > "$tmp/session-bad.json"
jq -e '. == {}' "$tmp/session-bad.json" >/dev/null || fail "malformed Cursor sessionStart must emit empty JSON"
pass "Cursor sessionStart injects JSON additional_context and stays activation-only"

printf '%s\n' "VERIFY CURSOR ADAPTER PASSED"
