# Luna Subagent Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Sol/Ultra the only primary-task judgment and review lane while every supported child spawn is a fresh, role-pinned Luna/High task.

**Architecture:** Bundle a synchronous `PreToolUse` guard at the plugin's native `hooks/hooks.json` path and allow only one exact custom child role. Safely migrate exact historical role files to that one profile, validate the exact runtime tuple, and make all active plugin guidance describe the same three-route workflow.

**Tech Stack:** POSIX `sh`, `jq`, Python 3 standard-library `tomllib`, JSON, TOML, Markdown, Codex plugin lifecycle hooks.

## Global Constraints

- The primary task is exactly `gpt-5.6-sol` with `ultra` reasoning; the plugin verifies this prerequisite but does not edit global Codex model configuration.
- Every child is exactly `gpt-5.6-luna` with `high` reasoning through `agent_type: sol_advisor_luna_subagent` and `fork_turns: none`.
- The primary task owns architecture, material ambiguity, integration, verification, final review, and acceptance; no reviewer child exists.
- Nonconforming supported `spawn_agent` calls are denied, never silently rewritten.
- The hook is plugin-wide when enabled and trusted. Documentation must not claim coverage for untrusted, disabled, crashed, or specialized opt-out paths.
- Terra, Luna/Max, the Sol reviewer child, and the `full` route have no active role or routing behavior.
- One child is the default maximum; multiple Luna/High children require explicitly independent parallel work.
- Historical role names and hashes may appear only in bounded migration or spawn-enforcement fixtures and cleanup code.
- The installer removes only byte-exact historical Sol Advisor profiles, refuses unsafe or modified destinations before mutation, and leaves unrelated files untouched.
- Reuse the existing `jq`, shell, and Python requirements; add no dependency.
- Each source task ends with `sh plugins/sol-advisor/scripts/verify.sh` passing and its own commit.

---

## File Structure

### Create

- `plugins/sol-advisor/hooks/hooks.json` — registers the plugin-wide synchronous spawn guard.
- `plugins/sol-advisor/hooks/enforce-luna-subagent.sh` — parses one `PreToolUse` payload and either allows silence or emits a supported deny response.
- `plugins/sol-advisor/agents/sol-advisor-luna-subagent.toml` — the only active custom child profile.

### Delete

- `plugins/sol-advisor/agents/sol-advisor-luna-implementer.toml`
- `plugins/sol-advisor/agents/sol-advisor-terra-implementer.toml`
- `plugins/sol-advisor/agents/sol-advisor-sol-reviewer.toml`

### Modify

- `plugins/sol-advisor/scripts/verify.sh` — executable regression suite for hooks, inventory, migration, runtime evidence, contracts, and release copy.
- `plugins/sol-advisor/scripts/install-agents.sh` — install/check one profile and safely retire exact historical profiles.
- `plugins/sol-advisor/scripts/inspect-agent-runtime.sh` — reject every runtime tuple except the generic Luna/High child.
- `plugins/sol-advisor/skills/orchestration/SKILL.md` — primary Sol/Ultra and three-route orchestration contract.
- `plugins/sol-advisor/skills/orchestration/references/role-contracts.md` — exact child packet, spawn, and parent acceptance contract.
- `plugins/sol-advisor/skills/orchestration/references/operations.md` — trust, install, preflight, runtime, and release operations.
- `plugins/sol-advisor/.codex-plugin/plugin.json` — v0.7.0 metadata and two-model product description.
- `plugins/sol-advisor/skills/orchestration/agents/openai.yaml` — matching UI copy.
- `README.md` — user installation, hook trust, routes, limitations, and updates.

## Interfaces Between Tasks

- Task 1 produces `hooks/hooks.json` and `hooks/enforce-luna-subagent.sh`; later tasks rely on the exact allow contract but do not modify it.
- Task 2 produces the `sol_advisor_luna_subagent` role and installer contract; Tasks 3–5 use that exact role name.
- Task 3 produces the exact accepted runtime tuple and active orchestration wording; Task 4 exposes it in release metadata and user documentation.
- Task 5 mutates only the installed local plugin/agent state after every repository check passes.

---

### Task 1: Add the plugin-wide spawn guard

**Files:**

- Create: `plugins/sol-advisor/hooks/hooks.json`
- Create: `plugins/sol-advisor/hooks/enforce-luna-subagent.sh`
- Modify/Test: `plugins/sol-advisor/scripts/verify.sh:14-22,159-164`

**Interfaces:**

- Consumes: Codex `PreToolUse` JSON on standard input with `tool_name` and `tool_input`.
- Produces: no output and exit `0` for the one allowed contract; otherwise a JSON `permissionDecision: deny` response and exit `0`, or exit `2` when `jq` itself is unavailable.

- [ ] **Step 1: Add failing hook packaging and behavior checks**

Add these variables after the existing `ui` assignment in `verify.sh`:

```sh
hooks_config=$plugin_dir/hooks/hooks.json
spawn_guard=$plugin_dir/hooks/enforce-luna-subagent.sh
```

Add both variables to the existing `for required in ...` loop. Immediately after the required-file check, add:

```sh
jq -e '
  (.hooks.PreToolUse | length) == 1 and
  .hooks.PreToolUse[0].matcher == "spawn_agent|Agent" and
  (.hooks.PreToolUse[0].hooks | length) == 1 and
  .hooks.PreToolUse[0].hooks[0].type == "command" and
  (.hooks.PreToolUse[0].hooks[0].command |
    contains("${PLUGIN_ROOT}/hooks/enforce-luna-subagent.sh"))
' "$hooks_config" >/dev/null || fail "spawn guard hook configuration is invalid"

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

assert_spawn_denied "missing role" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"fork_turns":"none"}}'
assert_spawn_denied "built-in worker" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"worker","fork_turns":"none"}}'
assert_spawn_denied "retired Terra role" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_terra_implementer","fork_turns":"none"}}'
assert_spawn_denied "retired Sol role" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_sol_reviewer","fork_turns":"none"}}'
assert_spawn_denied "inherited context" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_luna_subagent","fork_turns":"all"}}'
assert_spawn_denied "model override" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_luna_subagent","fork_turns":"none","model":"gpt-5.6-luna"}}'
assert_spawn_denied "effort override" '{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","tool_input":{"agent_type":"sol_advisor_luna_subagent","fork_turns":"none","reasoning_effort":"high"}}'
assert_spawn_denied "malformed JSON" 'not-json'
pass "plugin-wide spawn guard allows only the exact fresh Luna subagent contract"
```

- [ ] **Step 2: Run the verifier and confirm the test fails for missing hook files**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: exit `1` with `FAIL: required file missing:` naming `plugins/sol-advisor/hooks/hooks.json`.

- [ ] **Step 3: Create the native plugin hook configuration**

Create `plugins/sol-advisor/hooks/hooks.json` exactly as:

```json
{
  "description": "Require every supported subagent spawn to use Sol Advisor's fresh Luna / High profile.",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "spawn_agent|Agent",
        "hooks": [
          {
            "type": "command",
            "command": "sh \"${PLUGIN_ROOT}/hooks/enforce-luna-subagent.sh\"",
            "timeout": 5,
            "statusMessage": "Enforcing Luna / High subagents"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Create the minimal deny-only guard**

Create `plugins/sol-advisor/hooks/enforce-luna-subagent.sh` exactly as:

```sh
#!/bin/sh
# Allow only Sol Advisor's role-pinned, fresh Luna / High child contract.

set -eu

reason='Sol Advisor requires agent_type=sol_advisor_luna_subagent, fork_turns=none, and no per-spawn model or reasoning_effort override.'

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$reason The jq dependency is unavailable." >&2
  exit 2
fi

payload=$(cat)
if printf '%s\n' "$payload" | jq -e '
  .hook_event_name == "PreToolUse" and
  .tool_name == "spawn_agent" and
  (.tool_input | type) == "object" and
  .tool_input.agent_type == "sol_advisor_luna_subagent" and
  .tool_input.fork_turns == "none" and
  (.tool_input | has("model") | not) and
  (.tool_input | has("reasoning_effort") | not)
' >/dev/null 2>&1; then
  exit 0
fi

jq -cn --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
```

- [ ] **Step 5: Run focused syntax checks and the full verifier**

Run:

```sh
jq empty plugins/sol-advisor/hooks/hooks.json
sh -n plugins/sol-advisor/hooks/enforce-luna-subagent.sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: both syntax commands exit `0`; the verifier ends with the existing v0.6.0 `VERIFY PASSED` line plus the new spawn-guard pass line.

- [ ] **Step 6: Commit the independently green guard**

```sh
git add plugins/sol-advisor/hooks plugins/sol-advisor/scripts/verify.sh
git commit -m "feat: enforce Luna subagent spawns"
```

---

### Task 2: Replace three roles with one Luna/High profile and safe migration

**Files:**

- Create: `plugins/sol-advisor/agents/sol-advisor-luna-subagent.toml`
- Delete: `plugins/sol-advisor/agents/sol-advisor-luna-implementer.toml`
- Delete: `plugins/sol-advisor/agents/sol-advisor-terra-implementer.toml`
- Delete: `plugins/sol-advisor/agents/sol-advisor-sol-reviewer.toml`
- Modify: `plugins/sol-advisor/scripts/install-agents.sh:6-24,38-142,154-309`
- Modify/Test: `plugins/sol-advisor/scripts/verify.sh:39-365`

**Interfaces:**

- Consumes: an optional `--target-dir`, `--check`, and `--check-role luna`.
- Produces: exactly one current profile, no byte-exact retired Sol Advisor profiles, no partial mutation after any preflight conflict.

- [ ] **Step 1: Change the verifier's inventory expectation first**

Replace the role filename/digest declarations with:

```sh
current_file=sol-advisor-luna-subagent.toml
retired_luna_file=sol-advisor-luna-implementer.toml
retired_terra_file=sol-advisor-terra-implementer.toml
retired_sol_file=sol-advisor-sol-reviewer.toml
retired_luna_sha256s='fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb 5cfaf77f14757074ca5d3cfecd0b8204c91dc14eff8d6119985c64416ddf4853 12fa9180a292876e6731bc325779123bcd931c3caa902fbf90d676a31833be84'
retired_terra_sha256s='4425a8c1f21ce8c6af93f96adc253bbc33ea301f1389b3fa8ce350be08584eca 06c318e5e93f37452635906394e6ea69fb6a65ba9e6ad7172d37b444e0dc871d dc329fe87f6f6610c13157ec16432f91c79cf5a541ee3e7448f6afb165dd18ce 77ed2f36bb149da5d9032230c3d6f5e5cd56b059b3fa5f59085249bba06e1f3a'
retired_sol_sha256s='0333acf0ef562bcfebd06009ac09bd1dd8cbc04c4cf28e08e9e049bd8bf202d2'
```

Replace the Python TOML inventory block with:

```sh
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
```

- [ ] **Step 2: Run the verifier and confirm the inventory test fails**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: exit `1` with an inventory error listing the three current TOMLs instead of `sol-advisor-luna-subagent.toml`.

- [ ] **Step 3: Create the generic role and delete the retired source profiles**

Create `plugins/sol-advisor/agents/sol-advisor-luna-subagent.toml` exactly as:

```toml
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
checks and return exact commands and concrete evidence. Do not perform final review,
accept the deliverable, or spawn subagents. Do not substitute another role, model, or
reasoning level; this profile is pinned to GPT-5.6 Luna / High.
"""
```

Delete the three retired TOMLs listed in this task's file list.

- [ ] **Step 4: Replace installer classification with current-versus-retired states**

Remove `role_selected`, `classify_current_or_legacy`, and `replace_legacy_role`. Keep the existing `fail`, `report_preflight_error`, `path_exists`, `sha256_file`, `same_state`, and `install_missing` helpers. Add:

```sh
classify_current() {
  destination=$1
  template=$2
  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  elif cmp -s "$template" "$destination"; then
    printf '%s\n' current
  else
    printf '%s\n' conflict
  fi
}

classify_retired() {
  destination=$1
  known_digests=$2
  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  else
    digest=$(sha256_file "$destination")
    if [ -z "$digest" ]; then
      printf '%s\n' unreadable
      return
    fi
    for known_digest in $known_digests; do
      if [ "$digest" = "$known_digest" ]; then
        printf '%s\n' retired
        return
      fi
    done
    printf '%s\n' conflict
  fi
}

retire_exact() {
  label=$1
  destination=$2
  known_digests=$3
  [ "$(classify_retired "$destination" "$known_digests")" = retired ] ||
    fail "$label destination changed after preflight and will not be removed: $destination"
  rm "$destination" || fail "could not retire exact $label profile: $destination"
  printf '%s\n' "RETIRED: $destination"
}
```

Replace the usage block with:

```sh
usage() {
  cat <<'EOF'
Usage: install-agents.sh [--target-dir PATH] [--check] [--check-role luna]

Install Sol Advisor's one Luna / High subagent profile and retire only byte-exact
Sol Advisor profiles shipped by earlier releases. Never overwrite or remove a
modified, nonregular, unreadable, or symlinked destination.

Without --target-dir, the target is "$CODEX_HOME/agents" when CODEX_HOME is already
set, otherwise "$HOME/.codex/agents".

Options:
  --target-dir PATH  Explicit destination directory (absolute or relative).
  --check            Verify the current profile and absence of retired profiles;
                     do not create, replace, or remove anything.
  --check-role luna  Equivalent Luna-only compatibility spelling for --check.
  --help             Show this help text.
EOF
}
```

Change the parser so `--check-role` accepts only `luna`:

```sh
--check-role)
  [ "$#" -ge 2 ] || fail "--check-role requires the role: luna."
  [ "$2" = luna ] || fail "unknown --check-role '$2'; expected luna."
  check_only=1
  shift 2
  ;;
```

- [ ] **Step 5: Replace the installer's role declarations and state machine**

Replace everything from the current role-file declarations through the final success line with:

```sh
current_file=sol-advisor-luna-subagent.toml
retired_luna_file=sol-advisor-luna-implementer.toml
retired_terra_file=sol-advisor-terra-implementer.toml
retired_sol_file=sol-advisor-sol-reviewer.toml

current_template=$template_dir/$current_file
current_destination=$target_dir/$current_file
retired_luna_destination=$target_dir/$retired_luna_file
retired_terra_destination=$target_dir/$retired_terra_file
retired_sol_destination=$target_dir/$retired_sol_file

retired_luna_sha256s='fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb 5cfaf77f14757074ca5d3cfecd0b8204c91dc14eff8d6119985c64416ddf4853 12fa9180a292876e6731bc325779123bcd931c3caa902fbf90d676a31833be84'
retired_terra_sha256s='4425a8c1f21ce8c6af93f96adc253bbc33ea301f1389b3fa8ce350be08584eca 06c318e5e93f37452635906394e6ea69fb6a65ba9e6ad7172d37b444e0dc871d dc329fe87f6f6610c13157ec16432f91c79cf5a541ee3e7448f6afb165dd18ce 77ed2f36bb149da5d9032230c3d6f5e5cd56b059b3fa5f59085249bba06e1f3a'
retired_sol_sha256s='0333acf0ef562bcfebd06009ac09bd1dd8cbc04c4cf28e08e9e049bd8bf202d2'

[ -f "$current_template" ] && [ ! -L "$current_template" ] ||
  fail "shipped template is missing or not a regular file: $current_template"

preflight_failed=0
if path_exists "$target_dir"; then
  if [ -L "$target_dir" ] || [ ! -d "$target_dir" ]; then
    report_preflight_error "target directory is not a real directory: $target_dir"
  fi
fi

current_state=$(classify_current "$current_destination" "$current_template")
retired_luna_state=$(classify_retired "$retired_luna_destination" "$retired_luna_sha256s")
retired_terra_state=$(classify_retired "$retired_terra_destination" "$retired_terra_sha256s")
retired_sol_state=$(classify_retired "$retired_sol_destination" "$retired_sol_sha256s")

if [ "$check_only" -eq 1 ]; then
  [ "$current_state" = current ] ||
    report_preflight_error "Luna subagent template is $current_state, not the current exact file: $current_destination"
  [ "$retired_luna_state" = missing ] ||
    report_preflight_error "retired Luna implementer remains $retired_luna_state: $retired_luna_destination"
  [ "$retired_terra_state" = missing ] ||
    report_preflight_error "retired Terra implementer remains $retired_terra_state: $retired_terra_destination"
  [ "$retired_sol_state" = missing ] ||
    report_preflight_error "retired Sol reviewer remains $retired_sol_state: $retired_sol_destination"
else
  case "$current_state" in current|missing) ;; *) report_preflight_error "Luna subagent destination is $current_state and will not be replaced: $current_destination" ;; esac
  case "$retired_luna_state" in retired|missing) ;; *) report_preflight_error "retired Luna destination is $retired_luna_state and will not be removed: $retired_luna_destination" ;; esac
  case "$retired_terra_state" in retired|missing) ;; *) report_preflight_error "retired Terra destination is $retired_terra_state and will not be removed: $retired_terra_destination" ;; esac
  case "$retired_sol_state" in retired|missing) ;; *) report_preflight_error "retired Sol destination is $retired_sol_state and will not be removed: $retired_sol_destination" ;; esac
fi

[ "$preflight_failed" -eq 0 ] || exit 1

if [ "$check_only" -eq 1 ]; then
  printf '%s\n' "CHECK PASSED: the Luna / High subagent profile is current and retired Sol Advisor profiles are absent."
  exit 0
fi

if [ ! -d "$target_dir" ]; then
  mkdir -p "$target_dir" || fail "could not create target directory: $target_dir"
fi
[ -d "$target_dir" ] && [ ! -L "$target_dir" ] ||
  fail "target directory changed after preflight: $target_dir"

same_state "Luna subagent" "$current_state" "$(classify_current "$current_destination" "$current_template")"
same_state "retired Luna" "$retired_luna_state" "$(classify_retired "$retired_luna_destination" "$retired_luna_sha256s")"
same_state "retired Terra" "$retired_terra_state" "$(classify_retired "$retired_terra_destination" "$retired_terra_sha256s")"
same_state "retired Sol" "$retired_sol_state" "$(classify_retired "$retired_sol_destination" "$retired_sol_sha256s")"

case "$current_state" in
  missing) install_missing "$current_template" "$current_destination" ;;
  current) printf '%s\n' "ALREADY CURRENT: $current_destination" ;;
esac
case "$retired_luna_state" in retired) retire_exact "Luna implementer" "$retired_luna_destination" "$retired_luna_sha256s" ;; esac
case "$retired_terra_state" in retired) retire_exact "Terra implementer" "$retired_terra_destination" "$retired_terra_sha256s" ;; esac
case "$retired_sol_state" in retired) retire_exact "Sol reviewer" "$retired_sol_destination" "$retired_sol_sha256s" ;; esac

[ "$(classify_current "$current_destination" "$current_template")" = current ] ||
  fail "post-install exactness check failed: $current_destination"
for retired_destination in "$retired_luna_destination" "$retired_terra_destination" "$retired_sol_destination"; do
  if path_exists "$retired_destination"; then
    fail "post-install retired profile remains: $retired_destination"
  fi
done

printf '%s\n' "INSTALL PASSED: the Luna / High subagent profile is current and retired Sol Advisor profiles are absent."
```

- [ ] **Step 6: Replace installer fixtures with one-role and retirement assertions**

Keep the existing embedded v0.2 and v0.5 Luna/Terra fixture bodies, but make both fixture writers call this exact Sol fixture instead of copying a source role that is now deleted:

```sh
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
```

At the end of each old fixture writer, assert its historical digests and call `write_retired_sol "$target"`. Add:

Within those two fixture writers, make these exact mechanical substitutions so no
deleted template variable remains:

```text
$luna_file  -> $retired_luna_file
$terra_file -> $retired_terra_file
$sol_file   -> $retired_sol_file
```

Keep each existing Luna/Terra digest assertion, then call `write_retired_sol "$target"`
instead of copying `$templates/$retired_sol_file`.

```sh
assert_only_current_profile() {
  target=$1
  cmp -s "$templates/$current_file" "$target/$current_file" || fail "current Luna subagent mismatch: $target"
  for retired_file in "$retired_luna_file" "$retired_terra_file" "$retired_sol_file"; do
    test ! -e "$target/$retired_file" && test ! -L "$target/$retired_file" || fail "retired profile remains: $target/$retired_file"
  done
}
```

Replace the installer test section with cases that perform these exact assertions:

```sh
grep -Fq "retired_luna_sha256s='$retired_luna_sha256s'" "$installer" || fail "installer retired Luna digest set mismatch"
grep -Fq "retired_terra_sha256s='$retired_terra_sha256s'" "$installer" || fail "installer retired Terra digest set mismatch"
grep -Fq "retired_sol_sha256s='$retired_sol_sha256s'" "$installer" || fail "installer retired Sol digest set mismatch"

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

migration_target=$tmp_dir/migration
write_legacy_roles "$migration_target"
sh "$installer" --target-dir "$migration_target"
assert_only_current_profile "$migration_target"

v050_migration_target=$tmp_dir/v050-migration
write_v050_roles "$v050_migration_target"
sh "$installer" --target-dir "$v050_migration_target"
assert_only_current_profile "$v050_migration_target"

modified_retired=$tmp_dir/modified-retired
write_v050_roles "$modified_retired"
printf '%s\n' modified >> "$modified_retired/$retired_terra_file"
before=$(snapshot_files "$modified_retired")
if sh "$installer" --target-dir "$modified_retired"; then fail "installer removed modified retired profile"; fi
after=$(snapshot_files "$modified_retired")
[ "$before" = "$after" ] || fail "modified retired refusal partially mutated target"
test ! -e "$modified_retired/$current_file" || fail "modified retired refusal installed the new profile"

unsafe=$tmp_dir/unsafe
mkdir "$unsafe"
ln -s "$templates/$current_file" "$unsafe/$retired_luna_file"
before=$(snapshot_files "$unsafe")
if sh "$installer" --target-dir "$unsafe"; then fail "installer accepted symlinked retired profile"; fi
after=$(snapshot_files "$unsafe")
[ "$before" = "$after" ] || fail "symlink refusal partially mutated target"

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
```

Keep the existing missing-target and target-directory-symlink cases unchanged. Replace
the `CODEX_HOME`, relative-path, and modified-current cases with:

```sh
codex_home=$tmp_dir/codex-home
CODEX_HOME="$codex_home" sh "$installer"
cmp -s "$templates/$current_file" "$codex_home/agents/$current_file" || fail "CODEX_HOME install mismatch"
test ! -e "$codex_home/config.toml" || fail "installer created config.toml"

relative_parent=$tmp_dir/relative-parent
mkdir "$relative_parent"
(cd "$relative_parent" && sh "$installer" --target-dir relative-agents)
cmp -s "$templates/$current_file" "$relative_parent/relative-agents/$current_file" || fail "relative target mismatch"

modified_current=$tmp_dir/modified-current
sh "$installer" --target-dir "$modified_current"
printf '%s\n' modified >> "$modified_current/$current_file"
before=$(snapshot_files "$modified_current")
if sh "$installer" --target-dir "$modified_current"; then fail "installer replaced modified current profile"; fi
after=$(snapshot_files "$modified_current")
[ "$before" = "$after" ] || fail "modified current refusal partially mutated target"
```

Remove both selective Terra/Sol test blocks because only `luna` remains selectable.

- [ ] **Step 7: Run installer-focused checks and the full verifier**

Run:

```sh
sh -n plugins/sol-advisor/scripts/install-agents.sh
temp_agents=$(mktemp -d)
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir "$temp_agents"
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir "$temp_agents" --check
find "$temp_agents" -mindepth 1 -maxdepth 1 -print
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: the `find` command prints only `sol-advisor-luna-subagent.toml`; the verifier ends with `VERIFY PASSED`.

- [ ] **Step 8: Commit the independently green role migration**

```sh
git add plugins/sol-advisor/agents plugins/sol-advisor/scripts/install-agents.sh plugins/sol-advisor/scripts/verify.sh
git commit -m "feat: migrate to one Luna High child role"
```

---

### Task 3: Enforce the runtime tuple and simplify orchestration contracts

**Files:**

- Modify: `plugins/sol-advisor/scripts/inspect-agent-runtime.sh:97-155`
- Modify/Test: `plugins/sol-advisor/scripts/verify.sh:367-444`
- Modify: `plugins/sol-advisor/skills/orchestration/SKILL.md`
- Modify: `plugins/sol-advisor/skills/orchestration/references/role-contracts.md`
- Modify: `plugins/sol-advisor/skills/orchestration/references/operations.md`

**Interfaces:**

- Consumes: one exact child rollout thread ID or public spawn metadata.
- Produces: only the accepted role/model/effort tuple; all decisions and final review stay in the primary Sol/Ultra task.

- [ ] **Step 1: Change runtime fixtures and contract assertions first**

Change the valid rollout fixture to:

```sh
printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK_PROMPT"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$runtime_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"sol_advisor_luna_subagent\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"high","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture"}}' \
  > "$runtime_rollout"
```

Assert `.agent_role == "sol_advisor_luna_subagent"`, `.model == "gpt-5.6-luna"`, and `.effort == "high"`. Add three sibling rollouts with unique lowercase UUIDs and one wrong value each—role `worker`, model `gpt-5.6-sol`, and effort `max`—and assert each inspector invocation exits nonzero.

Use this helper and exact cases:

```sh
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
```

Replace the active contract checks with:

```sh
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
for mode in solo delegate audit; do
  grep -Fq "\`$mode\`" "$skill" || fail "skill omits $mode mode"
  grep -Fq "\`$mode\`" "$contracts" || fail "contracts omit $mode mode"
done
for active_document in "$skill" "$contracts" "$operations"; do
  if grep -Eqi 'gpt-5\.6-terra|Luna / Max|sol_advisor_(terra_implementer|sol_reviewer)|mode:.*full|`full`' "$active_document"; then
    fail "retired active routing remains in $active_document"
  fi
done
pass "Sol / Ultra primary and Luna / High child contracts are consistent"
```

- [ ] **Step 2: Run the verifier and confirm the runtime or contract test fails**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: exit `1` because the inspector still accepts a wrong tuple or because active documents still describe Sol/High, Luna/Max, Terra, reviewer children, and `full`.

- [ ] **Step 3: Make the runtime inspector validate the exact tuple**

In the inspector's `jq` decision chain, after the unique model and effort checks and before constructing the output object, add:

```jq
    elif $agent_role != "sol_advisor_luna_subagent" then
      error("unexpected agent role")
    elif $models[0] != "gpt-5.6-luna" then
      error("unexpected model")
    elif $efforts[0] != "high" then
      error("unexpected effort")
```

Do not change the allowlisted output fields or the prompt-leak protections.

- [ ] **Step 4: Replace the skill with the exact three-route contract**

Replace `plugins/sol-advisor/skills/orchestration/SKILL.md` with:

```markdown
---
name: orchestration
description: "Codex-native routing with a Sol / Ultra primary task, Luna / High children, and primary-task review."
---

# Sol Advisor Orchestration

Act as the architect and final reviewer. Own the user's intent, architecture, route,
decomposition, material judgment, parent verification, review, and acceptance. Routes
are exactly `solo`, `delegate`, and `audit`. Solo is the default.
One child is the default maximum; use more only for explicitly independent parallel work.

Read [references/role-contracts.md](references/role-contracts.md) before delegation.
Use [references/operations.md](references/operations.md) for hook trust, exact spawn,
preflight, runtime evidence, migration, and release procedures.

## Confirm the primary task

Run the primary Codex task on gpt-5.6-sol with ultra reasoning. Verify model and effort
when runtime metadata exposes them. If either differs, stop before task tools and ask
the user to select Sol / Ultra. If effort is not observable, ask the user to confirm it
and stop until confirmed. A skill cannot change the primary model or effort.

## Declare the route before task tools

Emit exactly one declaration before the first task tool call:

~~~text
SELECTIVE ROUTE
mode: solo | delegate | audit
risk: concise task-specific rationale
~~~

No task tool call may precede this declaration. Choose `solo` unless delegation or a
review-only task has a concrete benefit. Change the route only when new evidence
justifies it; record that evidence and never silently downgrade.

## Use only the Luna / High child

For any delegation, verify the installed role with `install-agents.sh --check
--check-role luna`. Treat an untrusted or disabled plugin hook as inactive enforcement
and stop before delegation. Spawn exactly:

~~~text
agent_type: sol_advisor_luna_subagent
fork_turns: none
~~~

Do not attach model or reasoning overrides. Public spawn metadata is authoritative for
role, model, and effort. Use the local runtime inspector only for omitted fields. The
accepted tuple is `sol_advisor_luna_subagent`, `gpt-5.6-luna`, and `high`; missing or
conflicting evidence invalidates the child result.

## Route delivery

- `solo`: implement, test, verify, and self-review in the primary task; spawn no child.
- `delegate`: give one Luna / High child a complete bounded packet; then inspect its
  complete output, rerun verification, review, and accept or reject it in the primary
  task.
- `audit`: review the target directly in the primary task. A Luna / High child may
  gather bounded evidence but cannot render the verdict.

Keep judgment-heavy, high-risk, architectural, ambiguous, or wide-blast-radius work in
the Sol / Ultra primary task. Child work substitutes for primary-task work; do not
duplicate it.

## Specify and verify every child task

Every child packet contains OBJECTIVE, FILES AND OWNERSHIP, INTERFACES, CONSTRAINTS,
VERIFICATION, and the structured return defined in the role contracts. State exact
owned files, preserve concurrent edits, and do not widen scope.

Treat child reports as claims. Inspect the complete diff or artifact, verify changed
scope, rerun requested checks, and confirm runtime evidence. The primary task performs
final review after every correction; no reviewer child exists.

## State the platform boundary truthfully

The trusted plugin hook blocks supported `spawn_agent` calls, including the `Agent`
alias and code-mode calls. It is not an unbypassable platform policy: disabled,
untrusted, failed, or specialized opt-out paths are outside the guard. Never claim
enforcement without observed hook trust and runtime evidence.
```

- [ ] **Step 5: Rewrite the two references around one child and primary review**

Set the `role-contracts.md` title to `# Native Codex child contract` and its introduction
to: `Use this contract only with Sol Advisor's role-pinned Luna / High child. It does
not select the primary model or launch a nested CLI.` Keep the existing five-section
packet and structured implementation report verbatim, except change `Every Luna or
Terra prompt` to `Every Luna child prompt`. Delete every other current section, then
place these exact operational blocks before and after the retained packet:

```markdown
## Route and preflight

Before task tools, declare `solo`, `delegate`, or `audit`. Confirm Sol / Ultra in the
primary task. `solo` needs no companion check. Any route that spawns a child requires:

~~~sh
sh plugins/sol-advisor/scripts/install-agents.sh --check --check-role luna
~~~

The only valid spawn is:

~~~text
agent_type: sol_advisor_luna_subagent
fork_turns: none
~~~

Omit per-spawn model and effort fields. Require public metadata or inspector evidence
for `sol_advisor_luna_subagent`, `gpt-5.6-luna`, and `high` before accepting the result.

## Exact route contracts

- `solo`: the Sol / Ultra primary task implements, verifies, and self-reviews.
- `delegate`: one Luna / High child completes the bounded packet; the primary task
  inspects, reruns verification, reviews, and accepts or rejects it.
- `audit`: the Sol / Ultra primary task renders the verdict. A Luna / High child may
  gather bounded evidence only.

One child is the default maximum. Multiple children require explicitly independent
parallel work. High-judgment or architectural work remains in the primary task.

## Parent acceptance

The primary task must inspect the actual diff or artifact, confirm owned-file scope,
rerun every requested check, compare public and local runtime evidence when both exist,
and perform final review. Any correction invalidates the prior review and requires
verification plus a new primary-task review. Child claims never replace direct evidence.
```

In `operations.md`, remove reviewer isolation and all multi-role routing. Preserve the
existing repository-relative installer and runtime command forms. Order the final file
as `Role pin and spawn contract`, `Hook trust and boundary`, `Installation and
migration`, `Route preflight`, `Accepted runtime evidence`, `Parent acceptance`, and
`Maintainer verification`, using these exact facts:

```markdown
## Role pin and spawn contract

| Role type | Model | Effort | Use |
|---|---|---|---|
| sol_advisor_luna_subagent | gpt-5.6-luna | high | Bounded implementation, research, evidence, and testing |

~~~text
agent_type: sol_advisor_luna_subagent
fork_turns: none
~~~

Do not attach model or reasoning overrides.

## Hook trust and boundary

The plugin's synchronous `PreToolUse` hook denies supported child spawns that do not
use the exact contract above. Review and trust it through `/hooks` after installation
or every hook definition change. Disabled, untrusted, failed, and specialized opt-out
paths are not covered; runtime evidence remains required.

## Route preflight

The primary task must be Sol / Ultra. `solo` needs no child. `delegate` and any `audit`
evidence child require `install-agents.sh --check --check-role luna`. Cache a successful
check only for the current task and invalidate it after installation or configuration
changes.

## Accepted runtime evidence

Public spawn details are authoritative. When they omit model or effort, run the
repository-relative `../../scripts/inspect-agent-runtime.sh` for the exact child thread.
Accept only `sol_advisor_luna_subagent`, `gpt-5.6-luna`, and `high`. Missing,
conflicting, or different evidence invalidates the result; the inspector is not a
model-selection fallback.

## Parent acceptance

Every child receives the five-part packet from role-contracts.md. The Sol / Ultra
primary task owns architecture, diff or artifact inspection, verification reruns,
corrections, final review, and acceptance. A child never renders the final verdict.
```

Retain the existing safe inspector invocation examples and maintainer commands. Change the maintainer verifier description to v0.7.0, one role, hook fixtures, Luna/High evidence, and three routes.

The `Installation and migration` section must include these exact commands and outcome:

```markdown
~~~sh
sh plugins/sol-advisor/scripts/install-agents.sh
sh plugins/sol-advisor/scripts/install-agents.sh --check
~~~

The installer creates one Luna / High profile and removes only byte-exact historical
Sol Advisor profiles. Any modified, unsafe, unreadable, or conflicting destination
stops the whole preflight before mutation. Unrelated agent files remain untouched.
```

- [ ] **Step 6: Run focused runtime refusals and the full verifier**

Run:

```sh
sh -n plugins/sol-advisor/scripts/inspect-agent-runtime.sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
```

Expected: all commands exit `0`; verifier output includes exact runtime-tuple and three-route contract pass lines.

- [ ] **Step 7: Commit the independently green runtime and orchestration contract**

```sh
git add plugins/sol-advisor/scripts/inspect-agent-runtime.sh plugins/sol-advisor/scripts/verify.sh plugins/sol-advisor/skills/orchestration
git commit -m "feat: keep judgment and review in Sol Ultra"
```

---

### Task 4: Publish a consistent v0.7.0 plugin contract

**Files:**

- Modify: `plugins/sol-advisor/.codex-plugin/plugin.json`
- Modify: `plugins/sol-advisor/skills/orchestration/agents/openai.yaml`
- Modify: `README.md`
- Modify/Test: `plugins/sol-advisor/scripts/verify.sh:165-173,446-551`

**Interfaces:**

- Consumes: the hook, role, installer, runtime, and route contracts from Tasks 1–3.
- Produces: one truthful v0.7.0 user journey and release verifier.

- [ ] **Step 1: Update release-copy assertions first**

Replace the old manifest and README product-copy assertions with:

```sh
jq empty "$manifest"
[ "$(jq -r '.version' "$manifest")" = 0.7.0 ] || fail "manifest version is not 0.7.0"
grep -Fq 'Sol / Ultra' "$manifest" || fail "manifest omits Sol / Ultra"
grep -Fq 'Luna / High' "$manifest" || fail "manifest omits Luna / High"
grep -Fq 'solo is the default' "$manifest" || fail "manifest omits solo default"
grep -Fq 'delegate uses' "$manifest" || fail "manifest omits delegate contract"
grep -Fq 'audit keeps the verdict in the primary task' "$manifest" || fail "manifest omits audit contract"
grep -Fq 'denies supported child spawns' "$manifest" || fail "manifest omits spawn guard"

readme_lines=$(wc -l < "$readme" | tr -d ' ')
[ "$readme_lines" -le 110 ] || fail "README remains maintainer-sized ($readme_lines lines)"
grep -Fq 'codex plugin marketplace add' "$readme" || fail "README omits marketplace quick start"
grep -Fq 'codex plugin add' "$readme" || fail "README omits plugin quick start"
grep -Fq 'scripts/install-agents.sh' "$readme" || fail "README omits companion install"
grep -Fq '/hooks' "$readme" || fail "README omits hook trust"
grep -Fq '| `solo` |' "$readme" || fail "README route table omits solo"
grep -Fq '| `delegate` |' "$readme" || fail "README route table omits delegate"
grep -Fq '| `audit` |' "$readme" || fail "README route table omits audit"
grep -Fq 'specialized paths' "$readme" || fail "README omits hook limitation"
```

Use this active-source retirement check; intentionally exclude installer migration code and verifier fixtures:

```sh
for active_document in "$readme" "$manifest" "$skill" "$contracts" "$operations" "$ui" "$templates"; do
  if grep -Eqi 'gpt-5\.6-terra|Luna / Max|Sol / High|sol_advisor_(terra_implementer|sol_reviewer)|`full`|mode:.*full' "$active_document"; then
    fail "retired active contract remains in $active_document"
  fi
done
```

Retain README checks for both guarded installer command lines and both unchanged Attention Heads URLs. Change the final verifier line to:

```sh
printf '%s\n' "VERIFY PASSED: Sol Advisor v0.7.0 Sol / Ultra and Luna / High checks completed in $tmp_dir"
```

- [ ] **Step 2: Run the verifier and confirm release metadata fails**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: exit `1` because the manifest is still v0.6.0 or README still advertises retired routes/models.

- [ ] **Step 3: Replace manifest interface copy**

Replace `plugins/sol-advisor/.codex-plugin/plugin.json` with:

```json
{
  "name": "sol-advisor",
  "version": "0.7.0",
  "description": "Codex-native routing with a Sol / Ultra primary task and Luna / High children.",
  "author": {"name": "Daniel McAteer", "url": "https://github.com/DannyMac180"},
  "homepage": "https://github.com/DannyMac180/sol-advisor#readme",
  "repository": "https://github.com/DannyMac180/sol-advisor",
  "license": "MIT",
  "keywords": ["codex", "orchestration", "multi-agent", "gpt-5.6"],
  "skills": "./skills/",
  "interface": {
    "displayName": "Sol Advisor",
    "shortDescription": "Keep judgment and review in Sol / Ultra; enforce Luna / High for every supported child.",
    "longDescription": "Sol Advisor keeps GPT-5.6 Sol / Ultra in the primary task for architecture, material judgment, verification, review, and acceptance. Solo is the default; delegate uses the one native GPT-5.6 Luna / High child for bounded work; audit keeps the verdict in the primary task. A trusted plugin hook denies supported child spawns outside the exact Luna / High contract, and runtime evidence must confirm the role, model, and effort.",
    "developerName": "Daniel McAteer",
    "category": "Productivity",
    "capabilities": ["Interactive", "Write", "Lifecycle hooks"],
    "websiteURL": "https://github.com/DannyMac180/sol-advisor",
    "defaultPrompt": [
      "Use $sol-advisor:orchestration to declare a SELECTIVE ROUTE before task tools, then build and verify this feature.",
      "Keep judgment and final review in Sol / Ultra; use only the Luna / High child for bounded delegated work."
    ]
  }
}
```

- [ ] **Step 4: Replace UI metadata**

Set `plugins/sol-advisor/skills/orchestration/agents/openai.yaml` to:

```yaml
interface:
  display_name: "Sol Advisor Orchestration"
  short_description: "Sol / Ultra judgment and review with Luna / High children"
  default_prompt: "Use $orchestration to declare a solo, delegate, or audit route before task tools; keep judgment and final review in Sol / Ultra."
```

- [ ] **Step 5: Rewrite the concise README journey**

Preserve the title, both Attention Heads paragraphs/URLs, guarded install command shape, update command shape, operations link, and local-development commands. Make the surrounding copy state exactly these behaviors:

```markdown
**Sol / Ultra runs the show. It owns judgment and review; every supported child is
Luna / High.**

You need a current Codex CLI or ChatGPT desktop app with plugins enabled, GPT-5.6
Sol / Ultra for the primary task, GPT-5.6 Luna / High access, native custom-agent
support, and jq.

The companion installer leaves one exact Luna / High profile and safely retires only
byte-exact Sol Advisor profiles from older releases. It refuses modified, unsafe,
nonregular, symlinked, unreadable, or conflicting destinations without partial
mutation and does not edit Codex configuration.

After installation, open `/hooks`, review and trust the Sol Advisor hook, then start a
fresh task. Until the hook is trusted, supported spawn calls are not enforced.

| Mode | Use it when | Delivery |
|---|---|---|
| `solo` | Default; primary-task execution is appropriate. | Sol / Ultra implements, verifies, and self-reviews. |
| `delegate` | A bounded packet benefits from separate execution. | Luna / High executes; Sol / Ultra verifies and reviews. |
| `audit` | The requested outcome is a review. | Sol / Ultra renders the verdict; Luna / High may gather bounded evidence. |

The trusted hook blocks supported `spawn_agent` calls unless they use the exact fresh
Luna / High profile. [OpenAI's Codex hooks documentation](https://learn.chatgpt.com/docs/hooks)
notes that specialized paths may bypass ordinary tool hooks, so runtime evidence is
still required and the plugin does not claim an unbypassable platform policy.
```

Keep README at 110 lines or fewer.

- [ ] **Step 6: Run the release verifier and inspect the complete diff**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git status --short
git diff --stat
git diff -- plugins/sol-advisor README.md
```

Expected: verifier ends with the v0.7.0 success line; `git diff --check` exits `0`; status contains only planned files; no active release copy advertises Terra, Luna/Max, Sol/High, a reviewer child, or `full`.

- [ ] **Step 7: Commit the independently green v0.7.0 release contract**

```sh
git add README.md plugins/sol-advisor/.codex-plugin/plugin.json plugins/sol-advisor/skills/orchestration/agents/openai.yaml plugins/sol-advisor/scripts/verify.sh
git commit -m "docs: publish the Sol Ultra and Luna High workflow"
```

---

### Task 5: Verify installed behavior in Codex CLI and ChatGPT desktop

**Files:**

- Mutate installed state only after source verification: the configured Sol Advisor marketplace/plugin and the user's Sol Advisor-owned agent profiles.
- Do not edit: unrelated `~/.codex/agents` files or global model configuration.

**Interfaces:**

- Consumes: committed v0.7.0 checkout, enabled/trusted plugin, fresh Sol/Ultra tasks.
- Produces: separate source, installation, trust, valid-spawn, invalid-spawn, and primary-review evidence for each surface.

- [ ] **Step 1: Re-run source acceptance before touching installed state**

```sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git status --short --branch
```

Expected: verifier passes, diff check exits `0`, and the branch is clean.

- [ ] **Step 2: Capture the pre-install state without changing it**

```sh
codex plugin list --json | jq '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | {version, enabled, source}'
find /Users/jaskarn/.codex/agents -mindepth 1 -maxdepth 1 -type f -name 'sol-advisor-*.toml' -print -exec shasum -a 256 {} \;
```

Expected: an evidence snapshot of the currently installed plugin and only Sol Advisor-owned profile paths/hashes.

- [ ] **Step 3: Point the personal marketplace at the checkout and install v0.7.0**

The existing marketplace has the same name, so replace only that configured source:

```sh
codex plugin marketplace remove sol-advisor
codex plugin marketplace add /Users/jaskarn/github/sol-advisor --json
codex plugin add sol-advisor@sol-advisor --json
plugin_dir=$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')
test -n "$plugin_dir" && test "$plugin_dir" != null && test -d "$plugin_dir"
codex plugin list --json | jq -e '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .version == "0.7.0" and .enabled == true'
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
```

Expected: plugin list reports version `0.7.0`; installer reports the Luna/High profile current and any byte-exact retired profiles removed. If a retired profile is modified or unsafe, stop and report its exact path instead of deleting it.

- [ ] **Step 4: Trust the hook and start a fresh CLI task**

Start:

```sh
codex -m gpt-5.6-sol -c 'model_reasoning_effort="ultra"'
```

In that CLI task, run `/hooks`, review the Sol Advisor `PreToolUse` command, trust it, and start a fresh task after trust is recorded.

Expected: `/hooks` shows the plugin source and trusted current hash; no untrusted-hook warning remains in the fresh task.

- [ ] **Step 5: Prove valid and invalid CLI spawns**

In the fresh CLI task, request one bounded `sol_advisor_luna_subagent` spawn with `fork_turns: none`. Copy its returned UUID through standard input, then inspect it:

```sh
plugin_dir=$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')
printf 'Child thread UUID: ' >&2
IFS= read -r child_thread_id
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" "$child_thread_id"
```

Expected JSON fields: `agent_role` is `sol_advisor_luna_subagent`, `model` is `gpt-5.6-luna`, and `effort` is `high`.

Then request a deliberate enforcement probe using `agent_type: worker` and `fork_turns: none`.

Expected: the tool call is denied before a child ID is created, and the reason requires the exact Luna role. The Sol/Ultra primary task then reviews the valid child's artifact or evidence itself.

- [ ] **Step 6: Repeat the same proof in ChatGPT desktop**

Open a new Codex task in the ChatGPT desktop app, select GPT-5.6 Sol with Ultra reasoning, use `/hooks` to confirm the same trusted hook, and repeat the valid Luna child plus invalid built-in worker probe.

Expected: the valid child reports the same runtime tuple; the invalid call creates no child; the root task renders final review and acceptance.

- [ ] **Step 7: Record the acceptance matrix**

Report this matrix with actual evidence, using `not verified` rather than inference for any unavailable surface:

```text
Surface          Source  Installed  Hook trusted  Luna/High runtime  Wrong spawn denied  Review stayed Sol/Ultra
Codex CLI        yes/no  yes/no     yes/no        yes/no             yes/no               yes/no
ChatGPT desktop  yes/no  yes/no     yes/no        yes/no             yes/no               yes/no
```

Also report every retired Sol Advisor profile removed and state that removal was irreversible except through reinstalling the historical plugin version.

---

## Final Completion Check

Before claiming completion, run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git status --short --branch
git log -5 --oneline
```

Completion requires four independently green source commits, a clean working tree, and the installed-state matrix. Do not equate repository verification with hook trust or live behavior.
