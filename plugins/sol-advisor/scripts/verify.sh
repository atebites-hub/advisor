#!/bin/sh
# Repository-local verification for Sol Advisor's selective native three-role architecture.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1
installer=$script_dir/install-agents.sh
runtime_inspector=$script_dir/inspect-agent-runtime.sh
odw_inspector=$script_dir/inspect-odw-run.sh
templates=$plugin_dir/agents
manifest=$plugin_dir/.codex-plugin/plugin.json
skill=$plugin_dir/skills/orchestration/SKILL.md
contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
operations=$plugin_dir/skills/orchestration/references/operations.md
odw_reference=$plugin_dir/skills/orchestration/references/odw.md
readme=$repo_dir/README.md
ui=$plugin_dir/skills/orchestration/agents/openai.yaml
retired_contract=$plugin_dir/skills/orchestration/references/luna-task-lane.md
hooks_config=$plugin_dir/hooks/hooks.json
spawn_guard=$plugin_dir/hooks/enforce-luna-subagent.sh
session_context=$plugin_dir/hooks/session-context.sh

tmp_base=/tmp
tmp_env=$(printenv TMPDIR 2>/dev/null || true)
if [ -n "$tmp_env" ]; then tmp_base=$tmp_env; fi
case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_dir=''
cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    case "$tmp_dir" in
      "$tmp_base"/sol-advisor-verify.*) rm -rf "$tmp_dir" ;;
      *) printf '%s\n' "REFUSING cleanup of unexpected directory: $tmp_dir" >&2 ;;
    esac
  fi
}
trap cleanup 0 HUP INT TERM
tmp_dir=$(mktemp -d "$tmp_base/sol-advisor-verify.XXXXXX") || fail "could not create disposable verification directory"

current_file=sol-advisor-luna-subagent.toml
retired_luna_file=sol-advisor-luna-implementer.toml
retired_terra_file=sol-advisor-terra-implementer.toml
retired_sol_file=sol-advisor-sol-reviewer.toml
retired_luna_sha256s='fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb 5cfaf77f14757074ca5d3cfecd0b8204c91dc14eff8d6119985c64416ddf4853 12fa9180a292876e6731bc325779123bcd931c3caa902fbf90d676a31833be84'
retired_terra_sha256s='4425a8c1f21ce8c6af93f96adc253bbc33ea301f1389b3fa8ce350be08584eca 06c318e5e93f37452635906394e6ea69fb6a65ba9e6ad7172d37b444e0dc871d dc329fe87f6f6610c13157ec16432f91c79cf5a541ee3e7448f6afb165dd18ce 77ed2f36bb149da5d9032230c3d6f5e5cd56b059b3fa5f59085249bba06e1f3a'
retired_sol_sha256s='0333acf0ef562bcfebd06009ac09bd1dd8cbc04c4cf28e08e9e049bd8bf202d2'

snapshot_files() {
  target=$1
  if [ ! -d "$target" ]; then
    printf '%s\n' MISSING
    return
  fi
  find "$target" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort | while IFS= read -r path; do
    if [ -L "$path" ]; then
      printf 'L %s -> %s\n' "$(basename "$path")" "$(readlink "$path")"
    elif [ -f "$path" ]; then
      shasum -a 256 "$path"
    else
      printf 'O %s\n' "$(basename "$path")"
    fi
  done
}

write_legacy_roles() {
  target=$1
  mkdir -p "$target"
  cat > "$target/$retired_luna_file" <<'LEGACY_LUNA'
name = "sol_advisor_luna_implementer"
description = "Sol Advisor's routine implementation lane for bounded, fully specified work."
model = "gpt-5.6-luna"
model_reasoning_effort = "max"

developer_instructions = """
You are Sol Advisor's routine implementation worker. Execute the supplied five-part
implementation specification exactly when it is bounded and largely determined by
the contract. Preserve stated interfaces and constraints, make only the files you
own, and adapt to concurrent edits instead of reverting work you do not own.

Surface material ambiguity, missing acceptance criteria, scope conflicts, or failed
verification rather than redesigning the architecture. Run the requested checks and
report actual evidence. Do not silently substitute a different role, model, or
reasoning level; this installed custom-agent profile is the required routine lane.
"""
LEGACY_LUNA
  cat > "$target/$retired_terra_file" <<'LEGACY_TERRA'
name = "sol_advisor_terra_implementer"
description = "Sol Advisor's complex implementation lane for context-heavy or higher-risk work."
model = "gpt-5.6-terra"
model_reasoning_effort = "max"

developer_instructions = """
You are Sol Advisor's complex implementation worker. Resolve difficult implementation
details within the settled architecture, including context-heavy, higher-risk, or
wider-blast-radius work. Preserve every stated interface and constraint, stay within
the owned file set, and document material judgment calls.

You are not alone in the codebase: preserve concurrent edits and do not revert
unrelated work. Surface ambiguity, scope conflicts, or verification failures rather
than changing the architecture without direction. Run the requested checks and report
actual evidence. Do not silently substitute a different role, model, or reasoning
level; this installed custom-agent profile is the required complex lane.
"""
LEGACY_TERRA
  [ "$(shasum -a 256 "$target/$retired_luna_file" | awk '{print $1}')" = "fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb" ] || fail "legacy Luna fixture digest drifted"
  [ "$(shasum -a 256 "$target/$retired_terra_file" | awk '{print $1}')" = "4425a8c1f21ce8c6af93f96adc253bbc33ea301f1389b3fa8ce350be08584eca" ] || fail "legacy Terra fixture digest drifted"
  write_retired_sol "$target"
}

write_v050_roles() {
  target=$1
  mkdir -p "$target"
  cat > "$target/$retired_luna_file" <<'V050_LUNA'
name = "sol_advisor_luna_implementer"
description = "Sol Advisor's default routine implementation lane for bounded, fully specified work."
model = "gpt-5.6-luna"
model_reasoning_effort = "max"

developer_instructions = """
You are Sol Advisor's default routine implementation worker. Execute the supplied
five-part implementation specification when the work is bounded and largely
determined by the contract. Preserve every stated interface and constraint, stay
within the owned file set, and document material judgment calls.

You are not alone in the codebase: preserve concurrent edits and do not revert
unrelated work. Surface material ambiguity, scope conflicts, or verification failures
rather than redesigning the architecture. Run the requested checks and report actual
evidence. If one corrected attempt shows that the work is judgment-heavy, high-risk,
or misclassified as routine, stop and return that signal so the parent can escalate
it to Terra / High. Do not silently substitute a different role, model, or reasoning
level; this installed custom-agent profile is the required routine lane.
"""
V050_LUNA
  cat > "$target/$retired_terra_file" <<'V050_TERRA'
name = "sol_advisor_terra_implementer"
description = "Sol Advisor's explicit high-complexity escalation lane for judgment-heavy or high-risk work."
model = "gpt-5.6-terra"
model_reasoning_effort = "high"

developer_instructions = """
You are Sol Advisor's explicit high-complexity escalation worker. Execute the
supplied five-part implementation specification within the settled architecture when
the parent identifies judgment-heavy, high-risk, or wider-blast-radius work, or when
one corrected Luna attempt shows that routine routing was a misclassification.
Preserve every stated interface and constraint, stay within the owned file set, and
document material judgment calls.

You are not alone in the codebase: preserve concurrent edits and do not revert
unrelated work. Surface ambiguity, scope conflicts, or verification failures rather
than redesigning the architecture without direction. Run the requested checks and
report actual evidence. Do not silently substitute a different role, model, or
reasoning level; this installed custom-agent profile is the required escalation lane.
"""
V050_TERRA
  [ "$(shasum -a 256 "$target/$retired_luna_file" | awk '{print $1}')" = "5cfaf77f14757074ca5d3cfecd0b8204c91dc14eff8d6119985c64416ddf4853" ] || fail "v0.5.0 Luna fixture digest drifted"
  [ "$(shasum -a 256 "$target/$retired_terra_file" | awk '{print $1}')" = "dc329fe87f6f6610c13157ec16432f91c79cf5a541ee3e7448f6afb165dd18ce" ] || fail "v0.5.0 Terra fixture digest drifted"
  write_retired_sol "$target"
}

write_retired_sol() {
  target=$1
  cat > "$target/$retired_sol_file" <<'RETIRED_SOL'
name = "sol_advisor_sol_reviewer"
description = "Sol Advisor's fresh, read-only final review lane for inspected diffs and evidence."
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
sandbox_mode = "read-only"

developer_instructions = """
You are Sol Advisor's fresh final reviewer. Remain strictly read-only: do not create,
modify, delete, format, or implement files, and do not broaden the requested scope.
Inspect the actual files, accumulated change set, stated interfaces and constraints,
and verification evidence in a fresh context.

Return exactly one verdict: ship, fix-first, or rethink. Base the verdict on concrete,
evidence-backed findings. Use fix-first only for bounded required corrections and
rethink when the architecture or scope must change. Do not silently substitute a
different role, model, or reasoning level; this installed custom-agent profile is the
required read-only review lane.
"""
RETIRED_SOL
  [ "$(shasum -a 256 "$target/$retired_sol_file" | awk '{print $1}')" = "$retired_sol_sha256s" ] || fail "retired Sol fixture digest drifted"
}

for required in "$installer" "$runtime_inspector" "$odw_inspector" "$manifest" "$skill" "$contracts" "$operations" "$odw_reference" "$readme" "$ui" "$hooks_config" "$spawn_guard" "$session_context"; do
  test -f "$required" || fail "required file missing: $required"
done
test ! -e "$retired_contract" || fail "retired separate workflow contract remains: $retired_contract"
pass "required files present and retired contract absent"

jq -e '
  (.hooks.PreToolUse | length) == 1 and
  .hooks.PreToolUse[0].matcher == "collaborationspawn_agent|spawn_agent|Agent" and
  (.hooks.PreToolUse[0].hooks | length) == 1 and
  .hooks.PreToolUse[0].hooks[0].type == "command" and
  (.hooks.PreToolUse[0].hooks[0].command |
    contains("${PLUGIN_ROOT}/hooks/enforce-luna-subagent.sh"))
' "$hooks_config" >/dev/null || fail "spawn guard hook configuration is invalid"

jq -e '
  (.hooks.SessionStart | length) == 1 and
  .hooks.SessionStart[0].matcher == "startup|resume|clear|compact" and
  (.hooks.SessionStart[0].hooks | length) == 1 and
  .hooks.SessionStart[0].hooks[0].type == "command" and
  .hooks.SessionStart[0].hooks[0].command ==
    "sh \"${PLUGIN_ROOT}/hooks/session-context.sh\"" and
  .hooks.SessionStart[0].hooks[0].timeout == 5 and
  .hooks.SessionStart[0].hooks[0].statusMessage == "Activating Sol Advisor"
' "$hooks_config" >/dev/null || fail "automatic SessionStart hook configuration is invalid"

activation_command=$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$hooks_config")
run_session_context() {
  printf '%s\n' "$1" | PLUGIN_ROOT=$plugin_dir sh -c "$activation_command"
}

sol_context=$tmp_dir/sol-session-context.md
run_session_context '{"hook_event_name":"SessionStart","source":"startup","model":"gpt-5.6-sol"}' > "$sol_context" ||
  fail "Sol SessionStart context command failed"
cmp -s "$skill" "$sol_context" || fail "Sol SessionStart did not emit the canonical orchestration skill"

luna_context=$tmp_dir/luna-session-context.md
run_session_context '{"hook_event_name":"SessionStart","source":"startup","model":"gpt-5.6-luna"}' > "$luna_context" ||
  fail "Luna SessionStart context command failed"
grep -Fq '# Sol Advisor Luna / High Worker' "$luna_context" || fail "Luna SessionStart omitted worker identity"
grep -Fq 'Do not spawn subagents' "$luna_context" || fail "Luna SessionStart omitted child-spawn boundary"
grep -Fq 'Do not render the final verdict' "$luna_context" || fail "Luna SessionStart omitted review boundary"
if grep -Fq 'SELECTIVE ROUTE' "$luna_context"; then fail "Luna SessionStart emitted primary-task routing context"; fi
if cmp -s "$skill" "$luna_context"; then fail "Luna SessionStart emitted the primary orchestration skill"; fi

for invalid_session_payload in \
  'not-json' \
  '[]' \
  '{"hook_event_name":"SessionStart","source":"startup","model":"gpt-5.6-sol"}{"hook_event_name":"SessionStart","source":"startup","model":"gpt-5.6-sol"}' \
  '{"hook_event_name":"SessionStart","source":"startup"}' \
  '{"hook_event_name":"SessionStart","source":"invalid","model":"gpt-5.6-sol"}' \
  '{"hook_event_name":"PreToolUse","source":"startup","model":"gpt-5.6-sol"}'
do
  if run_session_context "$invalid_session_payload" >/dev/null 2>&1; then
    fail "SessionStart context accepted invalid input: $invalid_session_payload"
  fi
done
pass "model-sensitive SessionStart emits canonical Sol context, bounded Luna context, and rejects invalid input"

run_spawn_guard() {
  printf '%s\n' "$1" | sh "$spawn_guard"
}

assert_spawn_denied() {
  label=$1
  payload=$2
  output=$(run_spawn_guard "$payload") || fail "$label guard invocation failed"
  printf '%s\n' "$output" | jq -e '
    .hookSpecificOutput.hookEventName == "PreToolUse" and
    .hookSpecificOutput.permissionDecision == "deny" and
    (.hookSpecificOutput.permissionDecisionReason | type == "string" and length > 0)
  ' >/dev/null || fail "$label was not denied with a supported PreToolUse response"
}

allowed_payload='{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_luna_subagent","fork_turns":"none","task_name":"fixture","message":"bounded fixture"}}'
allowed_output=$(run_spawn_guard "$allowed_payload") || fail "compliant Luna spawn guard invocation failed"
[ -z "$allowed_output" ] || fail "compliant Luna spawn emitted unexpected output"

allowed_collaboration_payload='{"hook_event_name":"PreToolUse","tool_name":"collaborationspawn_agent","tool_input":{"agent_type":"sol_advisor_luna_subagent","fork_turns":"none","task_name":"fixture","message":"bounded fixture"}}'
allowed_collaboration_output=$(run_spawn_guard "$allowed_collaboration_payload") || fail "compliant collaboration Luna spawn guard invocation failed"
[ -z "$allowed_collaboration_output" ] || fail "compliant collaboration Luna spawn emitted unexpected output"

allowed_agent_payload='{"hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"agent_type":"sol_advisor_luna_subagent","fork_turns":"none","mode":"code","task_name":"fixture","message":"bounded fixture"}}'
allowed_agent_output=$(run_spawn_guard "$allowed_agent_payload") || fail "compliant Agent alias guard invocation failed"
[ -z "$allowed_agent_output" ] || fail "compliant Agent alias emitted unexpected output"

assert_spawn_denied "missing role" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"fork_turns":"none"}}'
assert_spawn_denied "built-in worker" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"worker","fork_turns":"none"}}'
assert_spawn_denied "collaboration built-in worker" '{"hook_event_name":"PreToolUse","tool_name":"collaborationspawn_agent","tool_input":{"agent_type":"worker","fork_turns":"none"}}'
assert_spawn_denied "retired Terra role" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_terra_implementer","fork_turns":"none"}}'
assert_spawn_denied "retired Sol role" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_sol_reviewer","fork_turns":"none"}}'
assert_spawn_denied "inherited context" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_luna_subagent","fork_turns":"all"}}'
assert_spawn_denied "model override" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_luna_subagent","fork_turns":"none","model":"gpt-5.6-luna"}}'
assert_spawn_denied "effort override" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_luna_subagent","fork_turns":"none","reasoning_effort":"high"}}'
assert_spawn_denied "malformed JSON" 'not-json'
pass "plugin-wide spawn guard allows only the exact fresh Luna subagent contract"

jq empty "$manifest"
[ "$(jq -r '.version' "$manifest")" = 0.8.0 ] || fail "manifest version is not 0.8.0"
grep -Fq 'Sol / Ultra' "$manifest" || fail "manifest omits Sol / Ultra"
grep -Fq 'Luna / High' "$manifest" || fail "manifest omits Luna / High"
grep -Fiq 'solo is the default' "$manifest" || fail "manifest omits solo default"
grep -Fq 'delegate uses' "$manifest" || fail "manifest omits delegate contract"
grep -Fq 'audit keeps the verdict in the primary task' "$manifest" || fail "manifest omits audit contract"
grep -Fq 'denies supported child spawns' "$manifest" || fail "manifest omits spawn guard"
grep -Fq 'automatically activates in every fresh task' "$manifest" ||
  fail "manifest omits automatic activation"
if grep -Fq '$sol-advisor:orchestration' "$manifest"; then
  fail "manifest still requires explicit orchestration invocation"
fi
pass "manifest JSON and v0.8.0 automatic Sol / Ultra and Luna / High release language"

python3 - "$templates" <<'PY'
from pathlib import Path
import sys
import tomllib

root = Path(sys.argv[1])
expected = {
    "sol-advisor-luna-subagent.toml": {
        "name": "sol_advisor_luna_subagent",
        "model": "gpt-5.6-luna",
        "model_reasoning_effort": "high",
    },
}
actual = {path.name for path in root.glob("*.toml")}
if actual != set(expected):
    raise SystemExit(f"expected exactly {sorted(expected)}, found {sorted(actual)}")
for filename, pins in expected.items():
    data = tomllib.loads((root / filename).read_text(encoding="utf-8"))
    for field in ("name", "description", "developer_instructions"):
        if not isinstance(data.get(field), str) or not data[field].strip():
            raise SystemExit(f"{filename}: missing {field}")
    for field, value in pins.items():
        if data.get(field) != value:
            raise SystemExit(f"{filename}: {field}={data.get(field)!r}, expected {value!r}")
    instructions = data["developer_instructions"].lower()
    for phrase in ("do not perform final review", "do not spawn subagents"):
        if phrase not in instructions:
            raise SystemExit(f"{filename}: missing invariant {phrase!r}")
print("one exact Luna / High subagent role is valid")
PY
pass "exact one-role TOML inventory"

grep -Fq "retired_luna_sha256s='$retired_luna_sha256s'" "$installer" || fail "installer retired Luna digest set mismatch"
grep -Fq "retired_terra_sha256s='$retired_terra_sha256s'" "$installer" || fail "installer retired Terra digest set mismatch"
grep -Fq "retired_sol_sha256s='$retired_sol_sha256s'" "$installer" || fail "installer retired Sol digest set mismatch"
pass "immutable historical migration fingerprints"

assert_only_current_profile() {
  target=$1
  cmp -s "$templates/$current_file" "$target/$current_file" || fail "current Luna subagent mismatch: $target"
  for retired_file in "$retired_luna_file" "$retired_terra_file" "$retired_sol_file"; do
    test ! -e "$target/$retired_file" && test ! -L "$target/$retired_file" || fail "retired profile remains: $target/$retired_file"
  done
}

clean_target=$tmp_dir/clean
sh "$installer" --target-dir "$clean_target"
assert_only_current_profile "$clean_target"
sh "$installer" --target-dir "$clean_target" --check
sh "$installer" --target-dir "$clean_target" --check --check-role luna
before=$(snapshot_files "$clean_target")
sh "$installer" --target-dir "$clean_target"
after=$(snapshot_files "$clean_target")
[ "$before" = "$after" ] || fail "idempotent install changed current state"

for invalid_role in terra sol worker; do
  if sh "$installer" --target-dir "$clean_target" --check-role "$invalid_role" >/dev/null 2>&1; then
    fail "invalid role was accepted: $invalid_role"
  fi
done
pass "clean install, exact checks, idempotence, and invalid-role refusal"

missing_target=$tmp_dir/missing
if sh "$installer" --target-dir "$missing_target" --check; then fail "--check accepted missing target"; fi
test ! -e "$missing_target" || fail "--check mutated missing target"
pass "missing-target check refusal is non-mutating"

target_symlink=$tmp_dir/target-symlink
mkdir "$tmp_dir/target-real"
ln -s "$tmp_dir/target-real" "$target_symlink"
before=$(snapshot_files "$tmp_dir/target-real")
if sh "$installer" --target-dir "$target_symlink"; then fail "installer accepted symlinked target directory"; fi
after=$(snapshot_files "$tmp_dir/target-real")
[ "$before" = "$after" ] || fail "symlinked target refusal mutated target"
pass "symlinked target-directory refusal is non-mutating"

codex_home=$tmp_dir/codex-home
CODEX_HOME="$codex_home" sh "$installer"
cmp -s "$templates/$current_file" "$codex_home/agents/$current_file" || fail "CODEX_HOME install mismatch"
test ! -e "$codex_home/config.toml" || fail "installer created config.toml"
relative_parent=$tmp_dir/relative-parent
mkdir "$relative_parent"
(cd "$relative_parent" && sh "$installer" --target-dir relative-agents)
cmp -s "$templates/$current_file" "$relative_parent/relative-agents/$current_file" || fail "relative target mismatch"
pass "CODEX_HOME and relative target behavior"

migration_target=$tmp_dir/migration
write_legacy_roles "$migration_target"
sh "$installer" --target-dir "$migration_target"
assert_only_current_profile "$migration_target"
pass "exact historical migration"

v050_migration_target=$tmp_dir/v050-migration
write_v050_roles "$v050_migration_target"
sh "$installer" --target-dir "$v050_migration_target"
assert_only_current_profile "$v050_migration_target"
pass "exact v0.5.0 migration"

modified_retired=$tmp_dir/modified-retired
write_v050_roles "$modified_retired"
printf '%s\n' modified >> "$modified_retired/$retired_terra_file"
before=$(snapshot_files "$modified_retired")
if sh "$installer" --target-dir "$modified_retired"; then fail "installer removed modified retired profile"; fi
after=$(snapshot_files "$modified_retired")
[ "$before" = "$after" ] || fail "modified retired refusal partially mutated target"
test ! -e "$modified_retired/$current_file" || fail "modified retired refusal installed the new profile"
pass "modified retired refusal with zero partial mutation"

modified_current=$tmp_dir/modified-current
sh "$installer" --target-dir "$modified_current"
printf '%s\n' modified >> "$modified_current/$current_file"
before=$(snapshot_files "$modified_current")
if sh "$installer" --target-dir "$modified_current"; then fail "installer replaced modified current Luna"; fi
after=$(snapshot_files "$modified_current")
[ "$before" = "$after" ] || fail "modified current Luna refusal partially mutated target"
pass "modified current-role refusal with zero partial mutation"

unsafe=$tmp_dir/unsafe
mkdir "$unsafe"
ln -s "$templates/$current_file" "$unsafe/$retired_luna_file"
before=$(snapshot_files "$unsafe")
if sh "$installer" --target-dir "$unsafe"; then fail "installer accepted symlinked Luna"; fi
after=$(snapshot_files "$unsafe")
[ "$before" = "$after" ] || fail "symlink refusal partially mutated target"
pass "symlink refusal with zero partial mutation"

nonregular=$tmp_dir/nonregular
mkdir -p "$nonregular/$retired_sol_file"
before=$(snapshot_files "$nonregular")
if sh "$installer" --target-dir "$nonregular"; then fail "installer accepted nonregular retired profile"; fi
after=$(snapshot_files "$nonregular")
[ "$before" = "$after" ] || fail "nonregular refusal partially mutated target"

unrelated=$tmp_dir/unrelated
mkdir "$unrelated"
printf '%s\n' 'name = "user_agent"' > "$unrelated/user-agent.toml"
sh "$installer" --target-dir "$unrelated"
grep -Fq 'name = "user_agent"' "$unrelated/user-agent.toml" || fail "installer changed unrelated agent"
assert_only_current_profile "$unrelated"
pass "nonregular refusal and unrelated agent preservation"

runtime_sessions=$tmp_dir/runtime-sessions
runtime_day=$runtime_sessions/2026/08/15
mkdir -p "$runtime_day"
runtime_id=11111111-1111-7111-8111-111111111111
runtime_rollout=$runtime_day/rollout-2026-08-15T00-00-00-$runtime_id.jsonl
printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK_PROMPT"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$runtime_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"sol_advisor_luna_subagent\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"high","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture"}}' \
  > "$runtime_rollout"
runtime_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$runtime_id")
printf '%s\n' "$runtime_output" | jq -e --arg id "$runtime_id" '
  .thread_id == $id and .agent_role == "sol_advisor_luna_subagent"
  and .model == "gpt-5.6-luna" and .effort == "high"
  and .sandbox_policy_type == "danger-full-access"
  and .permission_profile_type == "disabled"
' >/dev/null || fail "runtime inspector returned wrong Luna/High evidence"
if printf '%s\n' "$runtime_output" | grep -Fq DO_NOT_LEAK; then fail "runtime inspector leaked payload"; fi
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" invalid >/dev/null 2>&1; then fail "runtime inspector accepted invalid id"; fi
zero_id=22222222-2222-7222-8222-222222222222
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$zero_id" >/dev/null 2>&1; then fail "runtime inspector accepted zero matches"; fi
assert_runtime_rejected() {
  fixture_id=$1
  fixture_role=$2
  fixture_model=$3
  fixture_effort=$4
  fixture_rollout=$runtime_day/rollout-2026-08-15T00-00-00-$fixture_id.jsonl
  printf '%s\n' \
    "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$fixture_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"$fixture_role\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
    "{\"type\":\"turn_context\",\"payload\":{\"model\":\"$fixture_model\",\"effort\":\"$fixture_effort\",\"sandbox_policy\":{\"type\":\"danger-full-access\"},\"permission_profile\":{\"type\":\"disabled\"},\"cwd\":\"/fixture\"}}" \
    > "$fixture_rollout"
  if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$fixture_id" >/dev/null 2>&1; then
    fail "runtime inspector accepted $fixture_role / $fixture_model / $fixture_effort"
  fi
}

assert_runtime_rejected 33333333-3333-7333-8333-333333333333 worker gpt-5.6-luna high
assert_runtime_rejected 44444444-4444-7444-8444-444444444444 sol_advisor_luna_subagent gpt-5.6-sol high
assert_runtime_rejected 55555555-5555-7555-8555-555555555555 sol_advisor_luna_subagent gpt-5.6-luna max

missing_id=66666666-6666-7666-8666-666666666666
printf '%s\n' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$missing_id\",\"agent_role\":\"sol_advisor_luna_subagent\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna"}}' \
  > "$runtime_day/rollout-2026-08-15T00-00-00-$missing_id.jsonl"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$missing_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted missing effort"
fi

conflict_id=77777777-7777-7777-8777-777777777777
printf '%s\n' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$conflict_id\",\"agent_role\":\"sol_advisor_luna_subagent\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"high"}}' \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"max"}}' \
  > "$runtime_day/rollout-2026-08-15T00-00-00-$conflict_id.jsonl"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$conflict_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted conflicting effort"
fi

duplicate_id=88888888-8888-7888-8888-888888888888
mkdir -p "$runtime_sessions/2026/08/16" "$runtime_sessions/2026/08/17"
for duplicate_day in 16 17; do
  printf '%s\n' \
    "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$duplicate_id\",\"agent_role\":\"sol_advisor_luna_subagent\"}}" \
    '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"high"}}' \
    > "$runtime_sessions/2026/08/$duplicate_day/rollout-2026-08-$duplicate_day-T00-00-00-$duplicate_id.jsonl"
done
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$duplicate_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted duplicate rollout matches"
fi
pass "runtime inspector Luna/High tuple and safe refusals"

odw_fixture_root=$(CDPATH= cd "$tmp_dir" && pwd -P)
odw_sessions=$odw_fixture_root/odw-sessions
odw_session_day=$odw_sessions/2026/08/21
odw_run=$odw_fixture_root/odw-project/.odw/demo/runs/run-fixture
mkdir -p "$odw_session_day" "$odw_run/agents"

odw_id_one=91111111-1111-7111-8111-111111111111
odw_id_two=92222222-2222-7222-8222-222222222222

write_odw_rollout() {
  fixture_id=$1
  fixture_model=$2
  fixture_effort=$3
  printf '%s\n' \
    "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$fixture_id\",\"parent_thread_id\":null,\"agent_role\":null,\"agent_path\":null,\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
    "{\"type\":\"turn_context\",\"payload\":{\"model\":\"$fixture_model\",\"effort\":\"$fixture_effort\",\"sandbox_policy\":{\"type\":\"workspace-write\"},\"permission_profile\":{\"type\":\"managed\"},\"cwd\":\"/fixture\"}}" \
    > "$odw_session_day/rollout-2026-08-21T00-00-00-$fixture_id.jsonl"
}

write_odw_trace() {
  trace_path=$1
  fixture_id=$2
  fixture_model=$3
  fixture_effort=$4
  jq -n \
    --arg id "$fixture_id" \
    --arg model "$fixture_model" \
    --arg effort "$fixture_effort" '
    {
      command: "codex",
      args: [
        "exec", "--json", "--skip-git-repo-check", "--color", "never",
        "--sandbox", "workspace-write", "-c",
        "shell_environment_policy.ignore_default_excludes=false",
        "-m", $model, "-c", ("model_reasoning_effort=" + ($effort | tojson)), "-"
      ],
      cwd: "/fixture",
      prompt: "DO_NOT_LEAK_PROMPT",
      durationMs: 10,
      exitCode: 0,
      isError: false,
      resultSubtype: "success",
      stderr: "DO_NOT_LEAK_STDERR",
      events: [
        {type: "thread.started", thread_id: $id},
        {type: "item.completed", item: {type: "agent_message", text: "DO_NOT_LEAK_OUTPUT"}},
        {type: "turn.completed", usage: {input_tokens: 1, output_tokens: 1}}
      ]
    }
  ' > "$trace_path"
}

printf '%s\n' 'export const meta = { name: "demo", description: "fixture" }' > "$odw_run/script.js"
printf '%s\n' \
  '{"type":"run_start","runId":"run-fixture"}' \
  '{"type":"agent_start","agentId":1,"cached":false}' \
  '{"type":"agent_start","agentId":2,"cached":false}' \
  '{"type":"agent_end","agentId":1,"ok":true,"cached":false}' \
  '{"type":"agent_end","agentId":2,"ok":true,"cached":false}' \
  '{"type":"run_end","runId":"run-fixture","ok":true,"failedAgents":0,"failedWorkflows":0}' \
  > "$odw_run/events.jsonl"
printf '%s\n' \
  '{"index":1,"cached":false,"result":"DO_NOT_LEAK_JOURNAL"}' \
  '{"index":2,"cached":false,"result":"DO_NOT_LEAK_JOURNAL"}' \
  > "$odw_run/journal.jsonl"

write_odw_trace "$odw_run/agents/agent-1.jsonl" "$odw_id_one" gpt-5.6-luna high
write_odw_trace "$odw_run/agents/agent-2.jsonl" "$odw_id_two" gpt-5.6-luna high
write_odw_rollout "$odw_id_one" gpt-5.6-luna high
write_odw_rollout "$odw_id_two" gpt-5.6-luna high

odw_output=$(sh "$odw_inspector" --sessions-dir "$odw_sessions" "$odw_run") ||
  fail "ODW inspector rejected a valid two-node Luna/High run"
printf '%s\n' "$odw_output" | jq -e \
  --arg one "$odw_id_one" --arg two "$odw_id_two" '
  .run_id == "run-fixture" and .agent_count == 2 and
  (.agents | map(.agent_id) == [1, 2]) and
  (.agents | map(.thread_id) == [$one, $two]) and
  all(.agents[]; .model == "gpt-5.6-luna" and .effort == "high")
' >/dev/null || fail "ODW inspector returned incorrect allowlisted evidence"
if printf '%s\n' "$odw_output" | grep -Eq 'DO_NOT_LEAK|prompt|stderr|cwd|tokens'; then
  fail "ODW inspector leaked non-routing payload data"
fi

copy_odw_case() {
  case_name=$1
  case_run=$odw_fixture_root/$case_name/.odw/demo/runs/run-fixture
  mkdir -p "$(dirname "$case_run")"
  cp -R "$odw_run" "$case_run"
  printf '%s\n' "$case_run"
}

rewrite_json() {
  filter=$1
  target=$2
  jq "$filter" "$target" > "$tmp_dir/rewrite.json"
  mv "$tmp_dir/rewrite.json" "$target"
}

rewrite_jsonl() {
  filter=$1
  target=$2
  jq -c "$filter" "$target" > "$tmp_dir/rewrite.jsonl"
  mv "$tmp_dir/rewrite.jsonl" "$target"
}

assert_odw_rejected() {
  label=$1
  fixture_run=$2
  fixture_sessions=$3
  rejection_output=$tmp_dir/odw-rejection-output
  if sh "$odw_inspector" --sessions-dir "$fixture_sessions" "$fixture_run" > "$rejection_output" 2>&1; then
    fail "ODW inspector accepted $label"
  fi
  if grep -Eq 'DO_NOT_LEAK|prompt|stderr|JOURNAL' "$rejection_output"; then
    fail "ODW inspector leaked payload while rejecting $label"
  fi
}

zcode_run=$(copy_odw_case zcode)
rewrite_json '.command = "zcode"' "$zcode_run/agents/agent-1.jsonl"
assert_odw_rejected "ZCode executor" "$zcode_run" "$odw_sessions"

wrong_model_run=$(copy_odw_case wrong-model)
rewrite_json '(.args | index("gpt-5.6-luna")) as $i | .args[$i] = "gpt-5.6-sol"' "$wrong_model_run/agents/agent-1.jsonl"
assert_odw_rejected "wrong model flag" "$wrong_model_run" "$odw_sessions"

missing_model_run=$(copy_odw_case missing-model)
rewrite_json '(.args | index("-m")) as $i | .args = (.args[:$i] + .args[$i + 2:])' "$missing_model_run/agents/agent-1.jsonl"
assert_odw_rejected "missing model flag" "$missing_model_run" "$odw_sessions"

duplicate_model_run=$(copy_odw_case duplicate-model)
rewrite_json '.args += ["-m", "gpt-5.6-luna"]' "$duplicate_model_run/agents/agent-1.jsonl"
assert_odw_rejected "duplicate model flag" "$duplicate_model_run" "$odw_sessions"

wrong_effort_run=$(copy_odw_case wrong-effort)
rewrite_json '(.args | index("model_reasoning_effort=\"high\"")) as $i | .args[$i] = "model_reasoning_effort=\"medium\""' "$wrong_effort_run/agents/agent-1.jsonl"
assert_odw_rejected "wrong effort flag" "$wrong_effort_run" "$odw_sessions"

missing_effort_run=$(copy_odw_case missing-effort)
rewrite_json '(.args | index("model_reasoning_effort=\"high\"")) as $i | .args = (.args[:$i - 1] + .args[$i + 1:])' "$missing_effort_run/agents/agent-1.jsonl"
assert_odw_rejected "missing effort flag" "$missing_effort_run" "$odw_sessions"

duplicate_effort_run=$(copy_odw_case duplicate-effort)
rewrite_json '.args += ["-c", "model_reasoning_effort=\"high\""]' "$duplicate_effort_run/agents/agent-1.jsonl"
assert_odw_rejected "duplicate effort flag" "$duplicate_effort_run" "$odw_sessions"

missing_thread_run=$(copy_odw_case missing-thread)
rewrite_json '.events |= map(select(.type != "thread.started"))' "$missing_thread_run/agents/agent-1.jsonl"
assert_odw_rejected "missing thread id" "$missing_thread_run" "$odw_sessions"

duplicate_thread_run=$(copy_odw_case duplicate-thread)
rewrite_json "(.events[] | select(.type == \"thread.started\") | .thread_id) = \"$odw_id_one\"" "$duplicate_thread_run/agents/agent-2.jsonl"
assert_odw_rejected "duplicate thread id" "$duplicate_thread_run" "$odw_sessions"

failed_run=$(copy_odw_case failed-node)
rewrite_jsonl 'if .type == "agent_end" and .agentId == 1 then .ok = false else . end' "$failed_run/events.jsonl"
assert_odw_rejected "failed node" "$failed_run" "$odw_sessions"

skipped_run=$(copy_odw_case skipped-node)
rewrite_jsonl 'if .type == "agent_end" and .agentId == 1 then .skipped = true else . end' "$skipped_run/events.jsonl"
assert_odw_rejected "skipped node" "$skipped_run" "$odw_sessions"

cached_run=$(copy_odw_case cached-node)
rewrite_jsonl 'if .type == "agent_start" and .agentId == 1 then .cached = true else . end' "$cached_run/events.jsonl"
assert_odw_rejected "cached node" "$cached_run" "$odw_sessions"

partial_run=$(copy_odw_case partial-journal)
sed -n '1p' "$partial_run/journal.jsonl" > "$tmp_dir/partial-journal.jsonl"
mv "$tmp_dir/partial-journal.jsonl" "$partial_run/journal.jsonl"
assert_odw_rejected "partial journal" "$partial_run" "$odw_sessions"

missing_trace_run=$(copy_odw_case missing-trace)
mv "$missing_trace_run/agents/agent-2.jsonl" "$tmp_dir/missing-agent-2.jsonl"
assert_odw_rejected "missing trace" "$missing_trace_run" "$odw_sessions"

missing_sessions=$odw_fixture_root/missing-odw-sessions/2026/08/21
mkdir -p "$missing_sessions"
cp "$odw_session_day/rollout-2026-08-21T00-00-00-$odw_id_one.jsonl" "$missing_sessions/"
assert_odw_rejected "missing rollout" "$odw_run" "$odw_fixture_root/missing-odw-sessions"

duplicate_sessions=$odw_fixture_root/duplicate-odw-sessions
cp -R "$odw_sessions" "$duplicate_sessions"
mkdir -p "$duplicate_sessions/2026/08/22"
cp "$odw_session_day/rollout-2026-08-21T00-00-00-$odw_id_one.jsonl" \
  "$duplicate_sessions/2026/08/22/rollout-2026-08-22T00-00-00-$odw_id_one.jsonl"
assert_odw_rejected "duplicate rollout" "$odw_run" "$duplicate_sessions"

wrong_runtime_sessions=$odw_fixture_root/wrong-runtime-sessions
cp -R "$odw_sessions" "$wrong_runtime_sessions"
rewrite_jsonl 'if .type == "turn_context" then .payload.model = "gpt-5.6-sol" else . end' \
  "$wrong_runtime_sessions/2026/08/21/rollout-2026-08-21T00-00-00-$odw_id_one.jsonl"
assert_odw_rejected "wrong runtime model" "$odw_run" "$wrong_runtime_sessions"

conflicting_runtime_sessions=$odw_fixture_root/conflicting-runtime-sessions
cp -R "$odw_sessions" "$conflicting_runtime_sessions"
printf '%s\n' \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"medium"}}' \
  >> "$conflicting_runtime_sessions/2026/08/21/rollout-2026-08-21T00-00-00-$odw_id_one.jsonl"
assert_odw_rejected "conflicting runtime effort" "$odw_run" "$conflicting_runtime_sessions"

native_role_sessions=$odw_fixture_root/native-role-sessions
cp -R "$odw_sessions" "$native_role_sessions"
rewrite_jsonl 'if .type == "session_meta" then .payload.agent_role = "sol_advisor_luna_subagent" else . end' \
  "$native_role_sessions/2026/08/21/rollout-2026-08-21T00-00-00-$odw_id_one.jsonl"
assert_odw_rejected "native role masquerading as ODW" "$odw_run" "$native_role_sessions"

symlink_parent=$odw_fixture_root/symlink-case/.odw/demo/runs
mkdir -p "$symlink_parent"
ln -s "$odw_run" "$symlink_parent/run-fixture"
assert_odw_rejected "symlinked run" "$symlink_parent/run-fixture" "$odw_sessions"

pass "ODW inspector proves every fresh Luna/High node and safely rejects invalid evidence"

for document in "$contracts" "$operations"; do
  grep -Fq 'agent_type: sol_advisor_luna_subagent' "$document" || fail "missing Luna subagent spawn in $document"
  grep -Fq 'fork_turns: none' "$document" || fail "missing fresh context in $document"
  if grep -Eq '^[[:space:]]*(model|reasoning_effort):' "$document"; then fail "per-spawn override remains in $document"; fi
done
grep -Fq 'gpt-5.6-sol with ultra reasoning' "$skill" || fail "skill omits primary Sol / Ultra requirement"
grep -Fq 'mode: solo | delegate | audit' "$skill" || fail "skill omits exact three-route declaration"
grep -Fq 'No task tool call may precede this declaration' "$skill" || fail "skill permits tool-before-route"
grep -Fq 'One child is the default maximum' "$skill" || fail "skill omits child limit"
grep -Fq 'final review' "$skill" || fail "skill omits primary review ownership"
grep -Fq '../../scripts/install-agents.sh' "$operations" || fail "operations does not resolve installer relatively"
grep -Fq '../../scripts/inspect-agent-runtime.sh' "$operations" || fail "operations does not resolve inspector relatively"
grep -Fq '/hooks' "$operations" || fail "operations omits hook trust"
grep -Fq 'references/odw.md' "$skill" || fail "skill does not route ODW work to its reference"
grep -Fq 'execution mechanism within `delegate` or `audit`' "$skill" || fail "skill does not keep ODW inside the three routes"
grep -Fq 'when the user explicitly asks for a repeatable/rerunnable multi-part workflow or audit' "$skill" || fail "skill omits explicit repeatable/rerunnable ODW selection"
grep -Fq 'Sol / Ultra primary task performs final review' "$skill" || fail "skill delegates ODW final review"
grep -Fq 'open-dynamic-workflows@open-dynamic-workflows' "$odw_reference" || fail "ODW reference omits installed-version preflight"
grep -Fq '"0.2.0"' "$odw_reference" || fail "ODW reference omits supported version"
grep -Fq 'const lunaAgent = (prompt, options = {}) => agent(prompt, {' "$odw_reference" || fail "ODW reference omits locked wrapper"
grep -Fq "executor: 'codex'" "$odw_reference" || fail "ODW reference omits Codex executor pin"
grep -Fq "model: 'gpt-5.6-luna'" "$odw_reference" || fail "ODW reference omits Luna pin"
grep -Fq "reasoningEffort: 'high'" "$odw_reference" || fail "ODW reference omits High pin"
grep -Fq 'exact active Codex workspace' "$odw_reference" || fail "ODW reference permits a substituted workflow cwd"
grep -Fq 'read-only applies to project source, not these evidence artifacts' "$odw_reference" || fail "ODW reference makes read-only workflows reject required run artifacts"
grep -Fq '$plugin_dir/scripts/inspect-odw-run.sh' "$odw_reference" || fail "ODW reference does not resolve the installed inspector"
grep -Fq 'Do not spawn subagents' "$odw_reference" || fail "ODW worker packet omits nested-agent boundary"
grep -Fq 'Do not render the final verdict' "$odw_reference" || fail "ODW worker packet omits review boundary"
grep -Fq 'cached' "$odw_reference" || fail "ODW reference omits cached-run refusal"
grep -Fq 'Open Dynamic Workflows' "$readme" || fail "README omits ODW compatibility"
grep -Fq 'ODW itself remains unchanged' "$readme" || fail "README obscures plugin-only boundary"
grep -Fq 'advanced operations' "$readme" || fail "README omits the combined operations reference"
grep -Fq 'inspect-odw-run.sh' "$operations" || fail "operations omit ODW runtime inspector"
grep -Fq '0.8.0' "$operations" || fail "operations omit v0.8.0 verification"
grep -Fq 'Open Dynamic Workflows' "$manifest" || fail "manifest omits ODW compatibility"
grep -Fq 'ODW' "$ui" || fail "UI copy omits ODW compatibility"
pass "ODW v0.2.0 authoring, Luna/High routing, evidence, and Sol-owned acceptance contract"
for mode in solo delegate audit; do
  grep -Fq "\`$mode\`" "$skill" || fail "skill omits $mode mode"
  grep -Fq "\`$mode\`" "$contracts" || fail "contracts omit $mode mode"
done
for active_document in "$readme" "$manifest" "$skill" "$contracts" "$operations" "$odw_reference" "$session_context" "$ui" "$templates"/*.toml; do
  if grep -Eqi 'gpt-5\.6-terra|Luna / Max|Sol / High|sol_advisor_(terra_implementer|sol_reviewer)|\`full\`|mode:.*full' "$active_document"; then
    fail "retired active routing remains in $active_document"
  fi
done
pass "active release copy has no retired routing contract"

readme_lines=$(wc -l < "$readme" | tr -d ' ')
[ "$readme_lines" -le 110 ] || fail "README remains maintainer-sized ($readme_lines lines)"
grep -Fq 'codex plugin marketplace add' "$readme" || fail "README omits marketplace quick start"
grep -Fq 'codex plugin add' "$readme" || fail "README omits plugin quick start"
grep -Fq 'scripts/install-agents.sh' "$readme" || fail "README omits companion install"
grep -Fq '/hooks' "$readme" || fail "README omits hook trust"
grep -Fq 'automatically loads the orchestration contract' "$readme" ||
  fail "README omits automatic activation"
grep -Fq 'SessionStart' "$operations" || fail "operations omit SessionStart activation"
grep -Fq 'PreToolUse' "$operations" || fail "operations omit spawn enforcement"
grep -Fq 'automatic' "$ui" || fail "UI copy omits automatic activation"
if grep -Fq '$orchestration' "$ui"; then
  fail "UI prompt still requires explicit orchestration invocation"
fi
grep -Fq '| `solo` |' "$readme" || fail "README route table omits solo"
grep -Fq '| `delegate` |' "$readme" || fail "README route table omits delegate"
grep -Fq '| `audit` |' "$readme" || fail "README route table omits audit"
grep -Fq 'specialized paths' "$readme" || fail "README omits hook limitation"
if grep -Eq 'agent_type:|fork_turns:|inspect-agent-runtime|sandbox_policy|sandbox_mode' "$readme"; then
  fail "README exposes maintainer routing/runtime machinery"
fi
if grep -Fq -- '--check' "$readme"; then
  fail "README quick start repeats the post-install --check"
fi
grep -Fq 'advanced operations' "$readme" || fail "README omits operations link"
python3 - "$readme" <<'PY'
from pathlib import Path
import sys

lines = [line.strip() for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()]
install_lines = [line for line in lines if line.startswith("plugin_dir=\"") and "scripts/install-agents.sh" in line]
if len(install_lines) != 2:
    raise SystemExit(f"expected two guarded companion install examples, found {len(install_lines)}")
for line in install_lines:
    required = [
        'test -n "$plugin_dir"',
        'test "$plugin_dir" != null',
        'test -d "$plugin_dir"',
        'test -f "$plugin_dir/scripts/install-agents.sh"',
    ]
    if any(check not in line for check in required):
        raise SystemExit(f"unguarded companion install example: {line}")
    if line.index("sh \"") < line.index(required[-1]):
        raise SystemExit(f"installer executes before directory/file guards: {line}")
print("two companion install examples are fail-closed and guarded")
PY
pass "README is concise, user-first, route-tabled, and keeps maintainer machinery out"

python3 - "$readme" "$manifest" "$skill" "$contracts" "$operations" "$ui" "$templates" <<'PY'
from pathlib import Path
import sys

roots = [Path(value) for value in sys.argv[1:]]
terms = [
    "list_" + "projects",
    "list_" + "threads",
    "create_" + "thread",
    "wait_" + "threads",
    "read_" + "thread",
    "send_" + "message_to_thread",
    "client" + "ThreadId",
    "app-" + "task",
    "app " + "task",
    "Luna " + "task",
    "task-" + "lane",
]
paths = []
for root in roots:
    if root.is_file():
        paths.append(root)
    elif root.is_dir():
        paths.extend(path for path in root.rglob("*") if path.is_file())
for path in paths:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    for term in terms:
        if term in text:
            raise SystemExit(f"obsolete workflow reference {term!r} remains in {path}")
print("obsolete workflow references are absent")
PY

grep -Fq 'Sol / Ultra runs the show' "$readme" || fail "README omits primary ownership"
grep -Fq 'Luna / High' "$readme" || fail "README omits Luna / High child path"
grep -Fq 'Attention Heads' "$readme" || fail "README lost Attention Heads section"
grep -Fq 'https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor' "$readme" || fail "README changed Attention Heads link"
grep -Fq 'https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor' "$readme" || fail "README changed Subscribe link"
pass "README selective routing and preserved Go deeper links"

for document in "$readme" "$manifest" "$skill" "$contracts" "$ui"; do
  if grep -Eqi 'Terra / High is the sole implementation producer|one role-pinned .*handles all implementation|route all implementation through.*Terra|delegate all implementation to (the )?(native )?Terra' "$document"; then
    fail "stale single-mode implementation claim remains in $document"
  fi
done
for forbidden in sol_advisor_terra_max sol-advisor-terra-max; do
  if rg -n "$forbidden" "$readme" "$manifest" "$skill" "$contracts" "$ui" "$templates"; then fail "forbidden second Terra role remains"; fi
done
pass "obsolete single-lane claims and second Terra role absent"

sh -n "$installer"
sh -n "$runtime_inspector"
sh -n "$odw_inspector"
sh -n "$script_dir/verify.sh"
sh -n "$session_context"
pass "shell syntax"

printf '%s\n' "VERIFY PASSED: Sol Advisor v0.8.0 automatic Sol / Ultra, native Luna / High, and ODW Luna / High checks completed in $tmp_dir"
