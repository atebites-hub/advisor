#!/bin/sh
set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1

required_files='
README.md
UPSTREAM.md
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
plugins/sol-advisor/scripts/smoke-odw-one-leaf.sh
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
grep -Fq 'marketplace add atebites-hub/advisor' "$repo_dir/README.md" || fail "README marketplace add is not atebites-hub/advisor"
grep -Fq 'sol-advisor@sol-advisor' "$repo_dir/README.md" || fail "README omits the upgrade-compatible package coordinate"
grep -Fq 'catalog-backed' "$repo_dir/README.md" || fail "README omits catalog-backed advisor/grunt pairs"
grep -Fq 'preset' "$repo_dir/README.md" || fail "README does not frame Sol/Luna as a Codex preset"
grep -Fq 'ultracode' "$repo_dir/README.md" && grep -Fq 'ultra mode' "$repo_dir/README.md" && grep -Fq 'multitask' "$repo_dir/README.md" ||
  fail "README omits the native-first orchestrator names"
grep -Fq 'Native-first vs ODW' "$repo_dir/README.md" || fail "README omits the native-first vs ODW matrix"
grep -Fq 'Native-first with ODW alignment required' "$repo_dir/README.md" ||
  fail "README omits required ODW alignment wording"
grep -Fq 'does **not** mean skip ODW' "$repo_dir/README.md" ||
  fail "README omits that native-first does not skip ODW"
grep -Fq 'ODW unused' "$repo_dir/README.md" ||
  fail "README omits that unused ODW is not a pass"
grep -Fq 'unproven' "$repo_dir/README.md" || fail "README omits unproven alignment status"
grep -Fq 'native_advisor_unverified' "$repo_dir/README.md" || fail "README omits Claude doctor code"
grep -Fq 'apply --host zcode' "$repo_dir/README.md" || fail "README omits ZCode apply"
grep -Fq 'configure --host zcode' "$repo_dir/README.md" || fail "README omits ZCode configure"
grep -Fq 'plugin_settings_required' "$repo_dir/README.md" || fail "README omits ZCode plugin_settings_required"
grep -Fq 'install/enable open-dynamic-workflows@0.3.0' "$repo_dir/README.md" || fail "README omits ODW install/enable seating gate"
grep -Fq 'git submodule update --init plugins/open-dynamic-workflows' "$repo_dir/README.md" ||
  fail "README omits the ODW submodule init command"
grep -Fq 'git submodule update --init plugins/open-dynamic-workflows' "$script_dir/smoke-odw-one-leaf.sh" ||
  fail "one-leaf smoke omits the exact submodule init command"
grep -Fq 'Does not soft-pass' "$script_dir/smoke-odw-one-leaf.sh" || fail "one-leaf smoke omits fail-closed wording"
grep -Fq 'does not auto-launch a run' "$script_dir/smoke-odw-one-leaf.sh" || fail "one-leaf smoke omits that it does not auto-launch"
grep -Fq 'does not auto-launch a run' "$repo_dir/README.md" || fail "README omits that one-leaf smoke does not auto-launch"
grep -Fq -- '--run-dir /absolute/.odw/.../runs/run-ID' "$repo_dir/README.md" || fail "README omits one-leaf --run-dir path"
grep -Fq -- '--run-dir /absolute/.odw/.../runs/run-ID' "$plugin_dir/skills/orchestration/references/odw.md" ||
  fail "odw.md omits one-leaf --run-dir path"
grep -Fq -- '--run-dir /absolute/.odw/.../runs/run-ID' "$plugin_dir/skills/orchestration/references/operations.md" ||
  fail "operations.md omits one-leaf --run-dir path"
grep -Fq 'Antigravity' "$repo_dir/README.md" && grep -Fq 'Copilot' "$repo_dir/README.md" && grep -Fq 'Lane B' "$repo_dir/README.md" ||
  fail "README omits Antigravity/Copilot deferred gaps"
if rg -n '^\| *Antigravity|^\| *GitHub Copilot|^\| *Copilot' "$repo_dir/README.md"; then
  fail "Antigravity/Copilot must not appear as support-table host rows"
fi
grep -Fq 'https://github.com/atebites-hub/advisor.git' "$repo_dir/UPSTREAM.md" || fail "UPSTREAM.md origin is not atebites-hub/advisor"
grep -Fq 'DannyMac180/sol-advisor' "$repo_dir/UPSTREAM.md" || fail "UPSTREAM.md dropped the true-fork parent"
grep -Fq "github.repository == 'atebites-hub/advisor'" "$repo_dir/.github/workflows/sync-upstream.yml" ||
  fail "sync-upstream.yml is not gated on atebites-hub/advisor"
grep -Fq "github.repository == 'atebites-hub/advisor'" "$repo_dir/.github/workflows/cleanup-artifacts.yml" ||
  fail "cleanup-artifacts.yml is not gated on atebites-hub/advisor"
if rg -n 'github.com/atebites-hub/sol-advisor' \
  "$repo_dir/marketplace.json" \
  "$repo_dir/.cursor-plugin" \
  "$repo_dir/.claude-plugin" \
  "$repo_dir/.grok-plugin" \
  "$plugin_dir/.codex-plugin"; then
  fail "active plugin catalogs still point at the pre-rename GitHub slug"
fi
grep -Fq 'catalog-backed advisor/grunt pair' "$plugin_dir/bin/advisor" || fail "advisor helper usage omits catalog-backed pairs"
grep -Fq 'apply --host codex|zcode' "$plugin_dir/bin/advisor" || fail "advisor helper usage omits ZCode apply"
grep -Fq 'install/enable open-dynamic-workflows@0.3.0' "$plugin_dir/bin/advisor" || fail "advisor helper omits ODW install/enable hint"
grep -Fq 'defer_to_native_when_present' "$plugin_dir/bin/advisor" || fail "advisor helper omits Claude native-first seating"
grep -Fq 'nativeAdvisor=unverified' "$plugin_dir/bin/advisor" || fail "advisor helper omits honest Claude nativeAdvisor=unverified"
grep -Fq 'ODW alignment required' "$plugin_dir/bin/advisor" || fail "advisor helper omits required ODW alignment"
grep -Fq 'Antigravity' "$plugin_dir/skills/orchestration/references/operations.md" &&
  grep -Fq 'Copilot' "$plugin_dir/skills/orchestration/references/operations.md" ||
  fail "operations.md omits Antigravity/Copilot deferred gaps"
grep -Fq 'alignment required' "$plugin_dir/skills/orchestration/references/operations.md" ||
  fail "operations.md omits required ODW alignment"
grep -Fq 'ODW unused' "$plugin_dir/skills/orchestration/references/operations.md" ||
  fail "operations.md omits that unused ODW is not a pass"
grep -Fq 'ultracode' "$plugin_dir/skills/orchestration/references/odw.md" || fail "odw.md omits native-first Claude path"
grep -Fq 'ODW must still align' "$plugin_dir/skills/orchestration/references/odw.md" ||
  fail "odw.md omits required ODW alignment"
grep -Fq 'unproven' "$plugin_dir/skills/orchestration/references/odw.md" ||
  fail "odw.md omits unproven alignment status"
grep -Fq 'native_advisor_unverified' "$plugin_dir/skills/advisor/SKILL.md" || fail "advisor skill omits Claude doctor code"
grep -Fq 'does not' "$plugin_dir/skills/advisor/SKILL.md" &&
  grep -Fq 'skip ODW' "$plugin_dir/skills/advisor/SKILL.md" ||
  fail "advisor skill omits that defer_to_native does not skip ODW"
grep -Fq 'ODW unused' "$plugin_dir/skills/orchestration/SKILL.md" ||
  fail "orchestration skill omits that unused ODW is not a pass"
grep -Fq 'version 0.3.0' "$plugin_dir/skills/orchestration/references/odw.md" || fail "ODW compatibility version is missing"
grep -Fq 'install/enable open-dynamic-workflows@0.3.0' "$plugin_dir/skills/orchestration/references/odw.md" ||
  fail "odw.md omits install/enable seating wording"
grep -Fq 'apply --host zcode' "$plugin_dir/skills/orchestration/references/operations.md" ||
  fail "operations.md omits ZCode apply"
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
