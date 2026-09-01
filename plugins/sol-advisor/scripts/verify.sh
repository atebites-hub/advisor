#!/bin/sh
set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1

required_files='
README.md
.agents/plugins/marketplace.json
.cursor-plugin/marketplace.json
.cursor-plugin/plugin.json
.claude-plugin/marketplace.json
.claude-plugin/plugin.json
.grok-plugin/marketplace.json
.grok-plugin/plugin.json
.zcode-plugin/plugin.json
marketplace.json
plugins/sol-advisor/.codex-plugin/plugin.json
plugins/sol-advisor/hooks/hooks.json
plugins/sol-advisor/hooks/session-context.sh
plugins/sol-advisor/hooks/enforce-codex.sh
plugins/sol-advisor/hosts/zcode/hooks/hooks.json
plugins/sol-advisor/hosts/zcode/hooks/enforce.sh
plugins/sol-advisor/bin/advisor
plugins/sol-advisor/templates/codex-advisor-grunt.toml.in
plugins/sol-advisor/scripts/install-agents.sh
plugins/sol-advisor/scripts/inspect-codex-runtime.sh
plugins/sol-advisor/scripts/inspect-zcode-runtime.sh
plugins/sol-advisor/scripts/inspect-odw-run.sh
plugins/sol-advisor/scripts/verify-config.sh
plugins/sol-advisor/scripts/verify-codex-adapter.sh
plugins/sol-advisor/scripts/verify-host-adapters.sh
plugins/sol-advisor/scripts/verify-cursor-adapter.sh
plugins/sol-advisor/scripts/verify-odw-inspector.sh
plugins/sol-advisor/scripts/install-cursor.sh
plugins/sol-advisor/scripts/find-helper.sh
plugins/sol-advisor/hosts/cursor/hooks/hooks.json
plugins/sol-advisor/hosts/cursor/hooks/session-context.sh
plugins/sol-advisor/hosts/cursor/commands/advisor.md
plugins/sol-advisor/hosts/cursor/commands/orchestration.md
plugins/sol-advisor/skills/advisor/SKILL.md
plugins/sol-advisor/skills/orchestration/SKILL.md
plugins/sol-advisor/skills/orchestration/agents/openai.yaml
plugins/sol-advisor/skills/orchestration/references/role-contracts.md
plugins/sol-advisor/skills/orchestration/references/operations.md
plugins/sol-advisor/skills/orchestration/references/odw.md'
printf '%s\n' "$required_files" | sed '/^$/d' | while IFS= read -r relative; do
  [ -f "$repo_dir/$relative" ] || fail "required file is missing: $relative"
done

for retired in \
  plugins/sol-advisor/agents/sol-advisor-luna-subagent.toml \
  plugins/sol-advisor/hooks/enforce-luna-subagent.sh \
  plugins/sol-advisor/scripts/inspect-agent-runtime.sh \
  plugins/sol-advisor/.cursor-plugin \
  plugins/sol-advisor/.claude-plugin \
  plugins/sol-advisor/.grok-plugin \
  plugins/sol-advisor/.zcode-plugin \
  hooks \
  skills \
  bin
do
  [ ! -e "$repo_dir/$retired" ] && [ ! -L "$repo_dir/$retired" ] || fail "retired active file remains: $retired"
done
pass "required package files are present and retired active files are absent"

for executable in \
  "$plugin_dir/bin/advisor" \
  "$plugin_dir/hooks/session-context.sh" \
  "$plugin_dir/hooks/enforce-codex.sh" \
  "$plugin_dir/hosts/zcode/hooks/enforce.sh" \
  "$plugin_dir/hosts/cursor/hooks/session-context.sh" \
  "$script_dir"/*.sh
do
  [ -x "$executable" ] || fail "script is not executable: $executable"
  sh -n "$executable" || fail "shell syntax failed: $executable"
done
pass "shell entrypoints are executable and syntactically valid"

find "$repo_dir" -name '*.json' -not -path '*/.git/*' -exec jq empty {} + || fail "JSON validation failed"
pass "all repository JSON parses"
if rg -n 'stat -f %Lp .*2>/dev/null \|\| stat -c %a' "$plugin_dir" >/dev/null; then
  fail "GNU-unsafe BSD-first stat remains; prefer stat -c %a then BSD stat -f %Lp"
fi
pass "file mode probes prefer GNU stat -c %a"

codex_manifest=$plugin_dir/.codex-plugin/plugin.json
jq -e '
  .name == "sol-advisor" and .version == "0.9.3" and
  .interface.displayName == "Advisor" and
  (.description | test("advisor/grunt"; "i")) and
  (.interface.longDescription | test("Open Dynamic Workflows 0.3.0"))
' "$codex_manifest" >/dev/null || fail "Codex manifest identity or release metadata is invalid"

jq -e '
  .name == "sol-advisor" and .version == "0.9.3" and
  .skills == "./plugins/sol-advisor/skills" and
  .commands == "./plugins/sol-advisor/hosts/cursor/commands" and
  .hooks == "./plugins/sol-advisor/hosts/cursor/hooks/hooks.json" and
  .displayName == "Advisor" and
  (.description | test("Cursor CLI"; "i")) and
  (.description | test("strict delegation"; "i")) and
  (has("agents") | not) and (has("mcpServers") | not)
' "$repo_dir/.cursor-plugin/plugin.json" >/dev/null || fail "Cursor plugin.json is not a first-class Cursor plugin with disabled strict delegation"
for manifest in \
  "$repo_dir/.claude-plugin/plugin.json" \
  "$repo_dir/.grok-plugin/plugin.json"
do
  jq -e '
    .name == "sol-advisor" and .version == "0.9.3" and
    .skills == "./plugins/sol-advisor/skills" and
    (.description | test("experimental detection; strict delegation disabled"; "i")) and
    (has("agents") | not) and (has("hooks") | not) and (has("mcpServers") | not)
  ' "$manifest" >/dev/null || fail "experimental manifest overclaims or has wrong version: $manifest"
done
jq -e '
  .name == "sol-advisor" and .version == "0.9.3" and
  .hooks == "./plugins/sol-advisor/hosts/zcode/hooks/hooks.json" and .skills == "./plugins/sol-advisor/skills" and
  (.userConfig | keys == ["advisor_effort","advisor_model","grunt_effort","grunt_model"]) and
  all(.userConfig[]; .type == "string" and .required == true and .sensitive == false)
' "$repo_dir/.zcode-plugin/plugin.json" >/dev/null || fail "ZCode manifest contract is invalid"
pass "all host manifests use Advisor 0.9.3 and truthful support labels"

catalogs="
$repo_dir/.agents/plugins/marketplace.json
$repo_dir/.claude-plugin/marketplace.json
$repo_dir/.grok-plugin/marketplace.json
$repo_dir/marketplace.json"
printf '%s\n' "$catalogs" | sed '/^$/d' | while IFS= read -r catalog; do
  jq -e '(.plugins | length) == 1 and .plugins[0].name == "sol-advisor" and .plugins[0].version == "0.9.3"' "$catalog" >/dev/null ||
    fail "catalog identity/version is invalid: $catalog"
  source_path=$(jq -r '.plugins[0].source | if type == "object" then .path else . end' "$catalog")
  case "$source_path" in .|./*|plugins/*) ;; *) fail "catalog source is not repository-relative: $catalog" ;; esac
  [ -d "$repo_dir/${source_path#./}" ] || fail "catalog source does not resolve: $catalog -> $source_path"
done
jq -e '
  .name == "sol-advisor" and (.plugins | length) == 1 and .plugins[0].name == "sol-advisor" and .plugins[0].source == "." and
  ((.plugins[0] | keys) - ["description","minClientVersions","name","source"] | length) == 0
' "$repo_dir/.cursor-plugin/marketplace.json" >/dev/null || fail "Cursor marketplace.json is not official-schema valid"
source_path=$(jq -r '.plugins[0].source' "$repo_dir/.cursor-plugin/marketplace.json")
[ -d "$repo_dir/${source_path#./}" ] || fail "Cursor catalog source does not resolve"
jq -e '.interface.displayName == "Advisor"' "$repo_dir/.agents/plugins/marketplace.json" >/dev/null || fail "Codex catalog display name is not Advisor"
for catalog in "$repo_dir/marketplace.json" "$repo_dir/.cursor-plugin/marketplace.json" "$repo_dir/.claude-plugin/marketplace.json" "$repo_dir/.grok-plugin/marketplace.json"; do
  [ "$(jq -r '.plugins[0].source | if type == "object" then .path else . end' "$catalog")" = . ] || fail "non-Codex host must install the repository-root package: $catalog"
done
[ "$(jq -r '.plugins[0].source.path' "$repo_dir/.agents/plugins/marketplace.json")" = ./plugins/sol-advisor ] || fail "Codex catalog must install only the Codex package root"
pass "catalog sources resolve inside the repository"

jq -e '
  (.hooks.SessionStart | length) == 1 and .hooks.SessionStart[0].matcher == "startup|resume|clear|compact" and
  .hooks.SessionStart[0].hooks[0].command == "sh \"${PLUGIN_ROOT}/hooks/session-context.sh\"" and
  (.hooks.PreToolUse | length) == 1 and .hooks.PreToolUse[0].matcher == "collaborationspawn_agent|spawn_agent|Agent|mcp__open_dynamic_workflows__workflow|mcp__open-dynamic-workflows__workflow" and
  .hooks.PreToolUse[0].hooks[0].command == "sh \"${PLUGIN_ROOT}/hooks/enforce-codex.sh\"" and
  (.hooks.SubagentStart | length) == 1 and .hooks.SubagentStart[0].matcher == ".*"
' "$plugin_dir/hooks/hooks.json" >/dev/null || fail "Codex lifecycle hook wiring is invalid"
jq -e '
  (.hooks.SessionStart | length) == 1 and
  (.hooks.PreToolUse | length) == 1 and
  (.hooks.PostToolUse | length) == 1 and
  (.hooks.PostToolUseFailure | length) == 1 and
  all(.hooks[][]; all(.hooks[]; .command == "${CLAUDE_PLUGIN_ROOT}/plugins/sol-advisor/hosts/zcode/hooks/enforce.sh" and .timeoutMs == 5000))
' "$plugin_dir/hosts/zcode/hooks/hooks.json" >/dev/null || fail "ZCode lifecycle hook wiring is invalid"
pass "Codex and ZCode hooks point only at packaged strict handlers"

active_docs="
$repo_dir/README.md
$plugin_dir/.codex-plugin/plugin.json
$repo_dir/.cursor-plugin/plugin.json
$repo_dir/.claude-plugin/plugin.json
$repo_dir/.grok-plugin/plugin.json
$repo_dir/.zcode-plugin/plugin.json
$plugin_dir/skills/advisor/SKILL.md
$plugin_dir/skills/orchestration/SKILL.md
$plugin_dir/skills/orchestration/agents/openai.yaml
$plugin_dir/skills/orchestration/references/role-contracts.md
$plugin_dir/skills/orchestration/references/operations.md
$plugin_dir/skills/orchestration/references/odw.md"
if printf '%s\n' "$active_docs" | sed '/^$/d' | xargs rg -n -i 'terra|sol_advisor_|Sol Advisor|ODW v0\.2|0\.8\.0'; then
  fail "retired product or routing vocabulary remains in active surfaces"
fi
if rg -n 'gpt-5\.6-(sol|luna)' "$plugin_dir/skills" "$plugin_dir/.codex-plugin" "$repo_dir/.cursor-plugin/plugin.json" "$repo_dir/.claude-plugin/plugin.json" "$repo_dir/.grok-plugin/plugin.json" "$repo_dir/.zcode-plugin/plugin.json"; then
  fail "generic contracts hard-code the Codex default tuple"
fi
grep -Fq 'Grok Bot' "$repo_dir/README.md" || fail "README does not explicitly exclude Grok Bot"
grep -Fq 'vibe code normally' "$repo_dir/README.md" || fail "README omits the automatic ordinary-work flow"
grep -Fq 'shell `PATH`' "$repo_dir/README.md" || fail "README implies a PATH-installed command"
grep -Fq '~/.cursor/plugins/local/sol-advisor' "$repo_dir/README.md" || fail "README omits Cursor local plugin install"
grep -Fq 'agent --plugin-dir' "$repo_dir/README.md" || fail "README omits Cursor CLI --plugin-dir"
grep -Fq 'agent mcp' "$repo_dir/README.md" || fail "README omits agent mcp"
grep -Fq '~/.cursor/skills' "$repo_dir/README.md" || fail "README omits Cursor CLI skills fallback"
grep -Fq 'version 0.3.0' "$plugin_dir/skills/orchestration/references/odw.md" || fail "ODW compatibility version is missing"
for section in OBJECTIVE 'FILES AND OWNERSHIP' INTERFACES CONSTRAINTS VERIFICATION RETURN 'IMPLEMENTATION REPORT'; do
  grep -Fq "$section" "$plugin_dir/skills/orchestration/references/role-contracts.md" || fail "grunt packet omits $section"
done
pass "generic advisor/grunt documentation and user flow are current"

sh "$script_dir/verify-config.sh"
sh "$script_dir/verify-codex-adapter.sh"
sh "$script_dir/verify-host-adapters.sh"
sh "$script_dir/verify-cursor-adapter.sh"
sh "$script_dir/verify-odw-inspector.sh"

printf '%s\n' "VERIFY PASSED: Advisor 0.9.3 source, host, runtime, migration, and ODW checks"
