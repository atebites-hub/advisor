# ODW Luna / High Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every model-executing node in a Sol Advisor-governed Open Dynamic Workflows run use Codex GPT-5.6 Luna / High while the outer GPT-5.6 Sol / Ultra task retains architecture, verification, final review, and acceptance.

**Architecture:** Keep ODW v0.2.0 unchanged. Sol Advisor will provide a locked `lunaAgent()` authoring contract, route Luna sessions to bounded-worker startup context, and accept a completed workflow only after a repository-owned inspector joins ODW launch traces to the exact Codex rollout for every fresh node. Native `spawn_agent` enforcement remains unchanged and separate.

**Tech Stack:** POSIX `sh`, `jq`, Codex lifecycle hooks, Codex JSONL rollouts, ODW v0.2.0 run artifacts, Markdown, JSON, YAML.

## Global Constraints

- Modify only `/Users/jaskarn/github/sol-advisor`; do not edit, patch, fork, reinstall, or write into Open Dynamic Workflows source or cache.
- Support exactly ODW `0.2.0` in this release; any other installed version is unverified and must stop before workflow execution.
- The outer task must be `gpt-5.6-sol` with `ultra` reasoning and owns architecture, material judgment, verification, final review, and acceptance.
- Every ODW model node, including discovery, implementation, judging, verification, and synthesis, must use executor `codex`, model `gpt-5.6-luna`, and `reasoningEffort: 'high'`.
- ZCode, mixed executors, alternate models, alternate reasoning levels, raw `agent()` calls outside the locked wrapper, and caller overrides of routing fields are forbidden.
- A Luna synthesis result is a draft; it is never the final verdict.
- Native delegation remains the exact `sol_advisor_luna_subagent` with `fork_turns: none`; do not modify its TOML, installer, runtime inspector, or spawn guard.
- Reject cached, failed, skipped, partial, symlinked, missing, duplicate, conflicting, or otherwise unverifiable ODW evidence.
- Emit only allowlisted routing evidence; never print prompts, schemas, environment variables, stderr, arbitrary events, journal results, tokens, or full traces.
- Use only existing runtime dependencies. Do not add a package, test framework, configuration layer, or ODW-specific route.
- Official Codex hook behavior is grounded in [OpenAI's Hooks documentation](https://learn.chatgpt.com/docs/hooks): command hooks receive `model` on stdin, and `SessionStart` plain stdout becomes developer context. Reasoning effort is not present in the documented hook input and must be proven from rollout metadata.

---

## File Structure

### Create

- `plugins/sol-advisor/hooks/session-context.sh` — validate `SessionStart` input and emit either the canonical primary skill or compact Luna worker context.
- `plugins/sol-advisor/scripts/inspect-odw-run.sh` — validate one exact ODW v0.2.0 run and join each trace thread ID to one Codex rollout.
- `plugins/sol-advisor/skills/orchestration/references/odw.md` — define the ODW eligibility, version preflight, immutable wrapper, worker prompt, inspector call, and Sol-owned acceptance contract.

### Modify

- `plugins/sol-advisor/hooks/hooks.json` — replace unconditional skill output with the model-sensitive session-context command.
- `plugins/sol-advisor/scripts/verify.sh` — add startup-context fixtures, ODW run/rollout fixtures, release assertions, and shell syntax checks.
- `plugins/sol-advisor/skills/orchestration/SKILL.md` — make ODW an execution mechanism inside `delegate` or `audit`, never a fourth route.
- `plugins/sol-advisor/skills/orchestration/references/operations.md` — add installed-version, trace-inspection, hook-trust, and release procedures.
- `README.md` — explain automatic ODW compatibility and its evidence boundary without exposing maintainer internals.
- `plugins/sol-advisor/.codex-plugin/plugin.json` — publish version `0.8.0` and ODW compatibility copy.
- `plugins/sol-advisor/skills/orchestration/agents/openai.yaml` — mention automatic Luna / High routing for native and ODW workers.

### Deliberately Unchanged

- `plugins/sol-advisor/agents/sol-advisor-luna-subagent.toml`
- `plugins/sol-advisor/hooks/enforce-luna-subagent.sh`
- `plugins/sol-advisor/scripts/install-agents.sh`
- `plugins/sol-advisor/scripts/inspect-agent-runtime.sh`
- Every file outside `/Users/jaskarn/github/sol-advisor`

---

### Task 1: Route SessionStart Context by Active Model

**Files:**

- Create: `plugins/sol-advisor/hooks/session-context.sh`
- Modify: `plugins/sol-advisor/hooks/hooks.json:1-15`
- Test: `plugins/sol-advisor/scripts/verify.sh:9-24,186-218,606-609`
- Track: `docs/superpowers/plans/2026-08-21-odw-luna-high-compatibility.md`

**Interfaces:**

- Consumes: one Codex `SessionStart` JSON object on stdin with `hook_event_name`, `source`, and `model`; `${PLUGIN_ROOT}` points to the installed Sol Advisor plugin directory.
- Produces: plain stdout containing either the canonical `skills/orchestration/SKILL.md` for every non-Luna model or bounded-worker developer context for exactly `gpt-5.6-luna`; malformed input exits nonzero without context.
- Preserves: the existing `PreToolUse` matcher and `enforce-luna-subagent.sh` behavior byte-for-byte.

- [ ] **Step 1: Add failing SessionStart contract checks**

In `plugins/sol-advisor/scripts/verify.sh`, add this variable after `spawn_guard`:

```sh
session_context=$plugin_dir/hooks/session-context.sh
```

Add `"$session_context"` to the `for required in ...` list, then replace the existing `SessionStart` configuration and output check with:

```sh
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
```

Add `sh -n "$session_context"` beside the existing shell syntax checks.

- [ ] **Step 2: Run the verifier and confirm the new test fails for the missing selector**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: exit `1` with `FAIL: required file missing: .../hooks/session-context.sh`. The existing native spawn tests must not be edited to make this failure pass.

- [ ] **Step 3: Implement the minimal model-sensitive selector**

Create `plugins/sol-advisor/hooks/session-context.sh` with exactly:

```sh
#!/bin/sh
# Emit primary or bounded-worker context from validated SessionStart input.

set -eu

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "the jq dependency is unavailable."

plugin_root=${PLUGIN_ROOT-}
case "$plugin_root" in
  /*) ;;
  *) fail "PLUGIN_ROOT must be an absolute directory." ;;
esac

primary_skill=$plugin_root/skills/orchestration/SKILL.md
[ -f "$primary_skill" ] || fail "the canonical orchestration skill is unavailable."

payload=$(cat)
model=$(printf '%s\n' "$payload" | jq -ers '
  if length == 1 and (.[0] | type) == "object" and
    .[0].hook_event_name == "SessionStart" and
    (.[0].source == "startup" or .[0].source == "resume" or .[0].source == "clear" or .[0].source == "compact")
  then .[0].model
  else empty
  end
  | select(type == "string" and length > 0)
' 2>/dev/null) || fail "invalid SessionStart input."

if [ "$model" = gpt-5.6-luna ]; then
  cat <<'EOF'
# Sol Advisor Luna / High Worker

Act only as a bounded execution worker. Complete the supplied objective within its
explicit ownership, interfaces, constraints, and verification requirements.

- Do not act as the primary architect or broaden the settled scope.
- Do not spawn subagents or launch nested agent workflows.
- Do not render the final verdict or accept your own result.
- Preserve concurrent edits and never revert unrelated work.
- Return actual changes, exact verification evidence, judgment calls, and gaps.

The outer GPT-5.6 Sol / Ultra task owns architecture, material judgment, independent
verification, final review, and acceptance. Your active High effort must be proven from
runtime metadata; this context does not select or prove reasoning effort.
EOF
else
  cat "$primary_skill"
fi
```

Replace the `SessionStart` command in `plugins/sol-advisor/hooks/hooks.json` with:

```json
"command": "sh \"${PLUGIN_ROOT}/hooks/session-context.sh\""
```

Do not change the matcher, timeout, status message, or `PreToolUse` object.

- [ ] **Step 4: Run focused and full checks**

Run:

```sh
sh -n plugins/sol-advisor/hooks/session-context.sh
jq empty plugins/sol-advisor/hooks/hooks.json
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
```

Expected: shell and JSON parsing exit `0`; the verifier prints the new model-sensitive SessionStart `PASS`, all native Luna guard checks remain green, and `git diff --check` prints nothing.

- [ ] **Step 5: Commit the independently green startup-context change**

```sh
git add docs/superpowers/plans/2026-08-21-odw-luna-high-compatibility.md plugins/sol-advisor/hooks/session-context.sh plugins/sol-advisor/hooks/hooks.json plugins/sol-advisor/scripts/verify.sh
git commit -m "feat: route Luna sessions to worker context"
```

---

### Task 2: Inspect Every Fresh ODW Node and Codex Rollout

**Files:**

- Create: `plugins/sol-advisor/scripts/inspect-odw-run.sh`
- Test: `plugins/sol-advisor/scripts/verify.sh:9-24,410-480,606-609`

**Interfaces:**

- Consumes: `inspect-odw-run.sh [--sessions-dir DIR] /absolute/canonical/project/.odw/WORKFLOW/runs/RUN_ID`.
- Reads: `script.js`, `events.jsonl`, `journal.jsonl`, `agents/agent-N.jsonl`, and the one rollout filename ending in each trace `thread_id` below the selected sessions directory.
- Produces: one compact JSON object: `{run_id, agent_count, agents:[{agent_id,thread_id,model,effort}]}`.
- Rejects: noncanonical paths, symlinks, malformed or partial artifacts, cached/failed/skipped nodes, unaccounted traces, non-Codex executors, missing/duplicate/wrong model or effort flags, invalid/duplicate thread IDs, missing/duplicate rollouts, and conflicting runtime metadata.

- [ ] **Step 1: Add failing ODW inspector fixtures**

In `plugins/sol-advisor/scripts/verify.sh`, add this variable after `runtime_inspector`:

```sh
odw_inspector=$script_dir/inspect-odw-run.sh
```

Add `"$odw_inspector"` to the required-file list and `sh -n "$odw_inspector"` to shell syntax checks. Insert the following fixture block immediately after `pass "runtime inspector Luna/High tuple and safe refusals"`:

```sh
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
```

- [ ] **Step 2: Run the verifier and confirm it fails for the missing inspector**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: exit `1` with `FAIL: required file missing: .../scripts/inspect-odw-run.sh`.

- [ ] **Step 3: Implement the fail-closed ODW run inspector**

Create `plugins/sol-advisor/scripts/inspect-odw-run.sh` with exactly:

```sh
#!/bin/sh
# Emit only allowlisted routing evidence for one complete fresh ODW v0.2.0 run.

set -eu

usage() {
  cat <<'EOF'
Usage: inspect-odw-run.sh [--sessions-dir DIR] /absolute/project/.odw/WORKFLOW/runs/RUN_ID

Validate one complete fresh ODW v0.2.0 run and emit only agent ids, Codex thread ids,
models, and efforts. Without --sessions-dir, use "$CODEX_HOME/sessions" when
CODEX_HOME is set, otherwise "$HOME/.codex/sessions".
EOF
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "the jq dependency is unavailable."

sessions_dir=''
case "$#" in
  1)
    run_dir=$1
    ;;
  3)
    [ "$1" = "--sessions-dir" ] || {
      usage >&2
      exit 2
    }
    [ -n "$2" ] || fail "--sessions-dir requires a non-empty directory."
    sessions_dir=$2
    run_dir=$3
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

case "$run_dir" in
  /*) ;;
  *) fail "run directory must be an absolute canonical path." ;;
esac
[ -d "$run_dir" ] && [ ! -L "$run_dir" ] || fail "run directory is unavailable or unsafe."
physical_run_dir=$(CDPATH= cd "$run_dir" && pwd -P) || fail "run directory cannot be resolved."
[ "$physical_run_dir" = "$run_dir" ] || fail "run directory must not contain symlinks, dot segments, or a trailing slash."

run_id=$(basename "$run_dir")
runs_dir=$(dirname "$run_dir")
workflow_dir=$(dirname "$runs_dir")
odw_dir=$(dirname "$workflow_dir")
workflow_name=$(basename "$workflow_dir")
[ "$(basename "$runs_dir")" = runs ] || fail "run directory is not below an ODW runs directory."
[ "$(basename "$odw_dir")" = .odw ] || fail "run directory is not below .odw/WORKFLOW/runs."
printf '%s\n' "$run_id" | LC_ALL=C grep -Eq '^run-[A-Za-z0-9][A-Za-z0-9._-]*$' || fail "invalid ODW run id."
printf '%s\n' "$workflow_name" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' || fail "invalid ODW workflow name."

if find "$run_dir" -type l -print 2>/dev/null | grep -q .; then
  fail "ODW run contains a symlink."
fi

script_file=$run_dir/script.js
events_file=$run_dir/events.jsonl
journal_file=$run_dir/journal.jsonl
agents_dir=$run_dir/agents
for required_file in "$script_file" "$events_file" "$journal_file"; do
  [ -f "$required_file" ] && [ ! -L "$required_file" ] || fail "ODW run is missing a required regular artifact."
done
[ -d "$agents_dir" ] && [ ! -L "$agents_dir" ] || fail "ODW run is missing its agents directory."

if [ -z "$sessions_dir" ]; then
  if [ -n "${CODEX_HOME-}" ]; then
    sessions_dir=$CODEX_HOME/sessions
  else
    [ -n "${HOME-}" ] || fail "HOME is unset and CODEX_HOME was not supplied; pass --sessions-dir explicitly."
    sessions_dir=$HOME/.codex/sessions
  fi
fi
[ -d "$sessions_dir" ] || fail "sessions directory is unavailable."

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in
  /*) ;;
  *) tmp_base=/tmp ;;
esac
tmp_dir=''
cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    case "$tmp_dir" in
      "$tmp_base"/sol-advisor-odw.*) rm -rf "$tmp_dir" ;;
      *) printf '%s\n' "ERROR: refusing cleanup of unexpected temporary directory." >&2 ;;
    esac
  fi
}
trap cleanup 0 HUP INT TERM
tmp_dir=$(mktemp -d "$tmp_base/sol-advisor-odw.XXXXXX") || fail "could not create a temporary verification directory."

event_summary=$tmp_dir/event-summary.json
if ! jq -ce -s --arg expected_run_id "$run_id" '
  def positive_integer: type == "number" and . > 0 and . == floor;
  [ .[] | select(.type == "run_start") ] as $run_starts |
  [ .[] | select(.type == "run_end") ] as $run_ends |
  [ .[] | select(.type == "workflow_start") ] as $workflow_starts |
  [ .[] | select(.type == "workflow_end") ] as $workflow_ends |
  [ .[] | select(.type == "agent_start") ] as $starts |
  [ .[] | select(.type == "agent_end") ] as $ends |
  if ($run_starts | length) != 1 or ($run_ends | length) != 1 then
    error("missing or ambiguous run lifecycle")
  elif $run_starts[0].runId != $expected_run_id or $run_ends[0].runId != $expected_run_id then
    error("run id mismatch")
  elif $run_ends[0].ok != true or $run_ends[0].failedAgents != 0 or $run_ends[0].failedWorkflows != 0 then
    error("run did not complete cleanly")
  elif ($workflow_starts | length) != ($workflow_ends | length) or any($workflow_ends[]; .ok != true) then
    error("nested workflow lifecycle is incomplete")
  elif ($starts | length) == 0 or ($ends | length) != ($starts | length) then
    error("agent lifecycle is incomplete")
  elif any($starts[]; (.agentId | positive_integer) | not) or any($ends[]; (.agentId | positive_integer) | not) then
    error("invalid agent id")
  elif ($starts | map(.agentId) | unique | length) != ($starts | length) then
    error("duplicate agent start")
  elif ($ends | map(.agentId) | unique | length) != ($ends | length) then
    error("duplicate agent end")
  elif any($starts[]; .cached != false) or any($ends[]; .cached != false) then
    error("cached agent is not accepted")
  elif any($ends[]; .ok != true or .skipped == true) then
    error("failed or skipped agent")
  elif any($starts[]; .agentId as $id | ([ $ends[] | select(.agentId == $id) ] | length) != 1) then
    error("started agent is unaccounted for")
  elif any($ends[]; .agentId as $id | ([ $starts[] | select(.agentId == $id) ] | length) != 1) then
    error("ended agent has no start")
  else
    {run_id: $expected_run_id, agent_ids: ($starts | map(.agentId) | sort)}
  end
' "$events_file" > "$event_summary" 2>/dev/null; then
  fail "ODW events are missing, malformed, cached, failed, partial, or inconsistent."
fi

if ! jq -e -s --slurpfile events "$events_file" '
  [ $events[] | select(.type == "agent_start") | .agentId ] as $ids |
  (length == ($ids | length)) and
  ([ .[] | .index ] | sort) == ($ids | sort) and
  all(.[]; .cached == false)
' "$journal_file" >/dev/null 2>&1; then
  fail "ODW journal does not account for every fresh agent."
fi

agent_count=$(jq -r '.agent_ids | length' "$event_summary")
find "$agents_dir" -mindepth 1 -maxdepth 1 -print > "$tmp_dir/agent-entries"
entry_count=$(awk 'END { print NR + 0 }' "$tmp_dir/agent-entries")
[ "$entry_count" -eq "$agent_count" ] || fail "ODW trace inventory does not match started agents."
jq -r '.agent_ids[]' "$event_summary" > "$tmp_dir/agent-ids"
: > "$tmp_dir/evidence.jsonl"

while IFS= read -r agent_id; do
  trace_file=$agents_dir/agent-$agent_id.jsonl
  [ -f "$trace_file" ] && [ ! -L "$trace_file" ] || fail "ODW agent trace is missing or unsafe."

  if ! trace_evidence=$(jq -ce '
    (.args // null) as $args |
    [ .events[]? | select(.type == "thread.started") | .thread_id ] as $threads |
    [ .events[]? | select(.type == "turn.completed") ] as $completed |
    [ .events[]? | select(.type == "turn.failed" or .type == "error") ] as $failures |
    [ range(0; ($args | length)) as $i | select($args[$i] == "-m") | $args[$i + 1] ] as $models |
    [ $args[] | select(startswith("model_reasoning_effort=")) ] as $efforts |
    ($args | index("model_reasoning_effort=\"high\"")) as $effort_index |
    if .command != "codex" or ($args | type) != "array" or any($args[]; type != "string") then
      error("unexpected executor or arguments")
    elif $args[0] != "exec" or ([ $args[] | select(. == "--json") ] | length) != 1 then
      error("unexpected Codex invocation")
    elif $models != ["gpt-5.6-luna"] or any($args[]; startswith("--model") or startswith("model=")) then
      error("unexpected model selection")
    elif $efforts != ["model_reasoning_effort=\"high\""] or $effort_index == 0 or $args[$effort_index - 1] != "-c" then
      error("unexpected reasoning effort")
    elif .exitCode != 0 or .isError != false or .resultSubtype != "success" then
      error("agent process did not complete successfully")
    elif ($threads | length) != 1 or ($threads[0] | test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$") | not) then
      error("missing or ambiguous thread id")
    elif ($completed | length) != 1 or ($failures | length) != 0 then
      error("Codex turn did not complete cleanly")
    else
      {thread_id: $threads[0]}
    end
  ' "$trace_file" 2>/dev/null); then
    fail "ODW agent trace has invalid executor, routing, thread, or completion evidence."
  fi

  thread_id=$(printf '%s\n' "$trace_evidence" | jq -r '.thread_id')
  matches_file=$tmp_dir/matches-$agent_id
  if ! find "$sessions_dir" -type f -name "rollout-*-$thread_id.jsonl" -print > "$matches_file"; then
    fail "could not enumerate Codex rollout filenames."
  fi
  match_count=$(awk 'END { print NR + 0 }' "$matches_file")
  [ "$match_count" -eq 1 ] || fail "Codex rollout match is missing or ambiguous."
  IFS= read -r rollout_file < "$matches_file" || fail "could not read the matched rollout filename."
  [ -f "$rollout_file" ] || fail "matched Codex rollout is unavailable."

  if ! runtime_evidence=$(jq -ce -s --arg expected_thread_id "$thread_id" '
    [ .[] | select(.type == "session_meta") | .payload ] as $sessions |
    [ .[] | select(.type == "turn_context") | .payload ] as $turns |
    [ $turns[] | .model ] as $models |
    [ $turns[] | .effort ] as $efforts |
    if ($sessions | length) != 1 or ($turns | length) == 0 then
      error("missing or ambiguous runtime metadata")
    elif $sessions[0].id != $expected_thread_id then
      error("runtime thread id mismatch")
    elif $sessions[0].parent_thread_id != null or $sessions[0].agent_role != null or $sessions[0].agent_path != null then
      error("runtime is not a standalone ODW Codex session")
    elif any($models[]; type != "string" or length == 0) or any($efforts[]; type != "string" or length == 0) then
      error("missing model or effort")
    elif ($models | unique) != ["gpt-5.6-luna"] then
      error("unexpected or conflicting runtime model")
    elif ($efforts | unique) != ["high"] then
      error("unexpected or conflicting runtime effort")
    else
      {thread_id: $expected_thread_id, model: $models[0], effort: $efforts[0]}
    end
  ' "$rollout_file" 2>/dev/null); then
    fail "Codex rollout is missing, ambiguous, invalid, or inconsistent routing metadata."
  fi

  printf '%s\n' "$runtime_evidence" | jq -c --argjson agent_id "$agent_id" '
    {agent_id: $agent_id, thread_id, model, effort}
  ' >> "$tmp_dir/evidence.jsonl"
done < "$tmp_dir/agent-ids"

if ! jq -ce -s --arg run_id "$run_id" '
  . as $agents |
  if ($agents | map(.thread_id) | unique | length) != ($agents | length) then
    error("duplicate thread id")
  else
    {run_id: $run_id, agent_count: ($agents | length), agents: ($agents | sort_by(.agent_id))}
  end
' "$tmp_dir/evidence.jsonl"; then
  fail "ODW routing evidence could not be summarized safely."
fi
```

- [ ] **Step 4: Run focused fixture checks and the full verifier**

Run:

```sh
sh -n plugins/sol-advisor/scripts/inspect-odw-run.sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
```

Expected: the verifier accepts the two-node Luna / High fixture; rejects ZCode,
wrong/missing/duplicate launch flags, missing/duplicate thread IDs, failed/skipped/cached
nodes, partial journals, missing traces, missing/duplicate rollouts, wrong/conflicting
runtime metadata, native-role masquerading, and symlinks; emits no `DO_NOT_LEAK` value;
and ends green.

- [ ] **Step 5: Commit the independently green inspector**

```sh
git add plugins/sol-advisor/scripts/inspect-odw-run.sh plugins/sol-advisor/scripts/verify.sh
git commit -m "feat: verify ODW Luna High runtimes"
```

---

### Task 3: Publish the ODW Contract and v0.8.0 Release

**Files:**

- Create: `plugins/sol-advisor/skills/orchestration/references/odw.md`
- Modify: `plugins/sol-advisor/skills/orchestration/SKILL.md:10-17,38-72,77-82`
- Modify: `plugins/sol-advisor/skills/orchestration/references/operations.md:1-28,47-108`
- Modify: `README.md:1-63`
- Modify: `plugins/sol-advisor/.codex-plugin/plugin.json:1-22`
- Modify: `plugins/sol-advisor/skills/orchestration/agents/openai.yaml:1-3`
- Test: `plugins/sol-advisor/scripts/verify.sh:15-24,254-267,482-611`

**Interfaces:**

- Consumes: the green session selector and ODW inspector from Tasks 1 and 2.
- Produces: one documented authoring and acceptance contract for ODW v0.2.0, discoverable from the canonical orchestration skill and installed plugin UI.
- Preserves: exactly three routes (`solo`, `delegate`, `audit`); ODW is an execution mechanism under `delegate` or `audit` and does not change native child policy.

- [ ] **Step 1: Add failing release and documentation assertions**

In `plugins/sol-advisor/scripts/verify.sh`, add:

```sh
odw_reference=$plugin_dir/skills/orchestration/references/odw.md
```

Add `"$odw_reference"` to the required-file list. Change the manifest version assertion to `0.8.0`, its pass text to `v0.8.0`, and the final verifier line to:

```sh
printf '%s\n' "VERIFY PASSED: Sol Advisor v0.8.0 automatic Sol / Ultra, native Luna / High, and ODW Luna / High checks completed in $tmp_dir"
```

Replace the existing README assertion for `advanced native operations` with the
`advanced operations` assertion in the block below; do not leave both expectations.

Add these assertions after the existing orchestration-document checks:

```sh
grep -Fq 'references/odw.md' "$skill" || fail "skill does not route ODW work to its reference"
grep -Fq 'execution mechanism within `delegate` or `audit`' "$skill" || fail "skill does not keep ODW inside the three routes"
grep -Fq 'Sol / Ultra primary task performs final review' "$skill" || fail "skill delegates ODW final review"
grep -Fq 'open-dynamic-workflows@open-dynamic-workflows' "$odw_reference" || fail "ODW reference omits installed-version preflight"
grep -Fq '"0.2.0"' "$odw_reference" || fail "ODW reference omits supported version"
grep -Fq 'const lunaAgent = (prompt, options = {}) => agent(prompt, {' "$odw_reference" || fail "ODW reference omits locked wrapper"
grep -Fq "executor: 'codex'" "$odw_reference" || fail "ODW reference omits Codex executor pin"
grep -Fq "model: 'gpt-5.6-luna'" "$odw_reference" || fail "ODW reference omits Luna pin"
grep -Fq "reasoningEffort: 'high'" "$odw_reference" || fail "ODW reference omits High pin"
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
```

Add `"$odw_reference"` and `"$session_context"` to the active-document retired-routing scan. Keep the exact route loop limited to `solo delegate audit`.

- [ ] **Step 2: Run the verifier and confirm release assertions fail**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: exit `1` because `references/odw.md` does not exist. Do not weaken any Task 1 or Task 2 assertion.

- [ ] **Step 3: Add the canonical ODW authoring and acceptance reference**

Create `plugins/sol-advisor/skills/orchestration/references/odw.md` with:

````markdown
# Open Dynamic Workflows operations

Use ODW only when a task needs more agents than one conversation can coordinate or the
orchestration must be a rerunnable script. ODW is an execution mechanism within
`delegate` or `audit`; it is not a fourth route. The Sol / Ultra primary task owns the
workflow design, material judgment, independent verification, final review, and
acceptance.

ODW may exceed the native one-child default only because justified fanout is the reason
to choose it. Select a finite task-specific node count and obey ODW's concurrency and
total-agent limits.

## Preflight

Require enabled ODW v0.2.0 before authoring or running the workflow:

~~~sh
codex plugin list --json | jq -e '
  .installed[]
  | select(.pluginId == "open-dynamic-workflows@open-dynamic-workflows")
  | .version == "0.2.0" and .enabled == true
'
~~~

Any other version is unverified until its executor arguments and artifact format are
revalidated. Do not edit ODW, its installed source, or its cache to satisfy this check.

## Locked model node

Every inline script defines this wrapper once:

~~~js
const lunaAgent = (prompt, options = {}) => agent(prompt, {
  ...options,
  executor: 'codex',
  model: 'gpt-5.6-luna',
  reasoningEffort: 'high',
})
~~~

Every model call uses `lunaAgent()`. The script contains no other raw `agent()` call.
Review every resolved saved or nested script against the same rule before execution;
nested agents share the parent run's evidence inventory. The fixed fields follow
`...options`, so labels, phases, schemas, retries, `agentType`, and worktree isolation
remain configurable while executor, model, and effort cannot be overridden. ZCode and
mixed-executor workflows are invalid.

Each worker prompt includes this exact boundary:

~~~text
OBJECTIVE
State one observable bounded outcome and why it matters.

FILES AND OWNERSHIP
List the exact owned files or the exact read-only evidence scope.

INTERFACES
List the settled signatures, schemas, commands, and behavior.

CONSTRAINTS
- Preserve concurrent work and do not revert unrelated edits.
- Do not redesign the settled architecture or widen scope.
- Do not spawn subagents or nested workflows.
- Do not render the final verdict or accept your own result.

VERIFICATION
- Run the exact task-specific command.
- State the concrete output that proves success.

RETURN
Return changes, exact verification evidence, judgment calls, and gaps.
~~~

A Luna synthesis node may consolidate worker results, but its output is a draft for
independent Sol / Ultra review.

## Runtime acceptance

Do not accept the tool result by itself. Resolve the installed plugin path, bind
`run_dir` to the exact absolute run directory returned by ODW, and inspect it:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -n "$plugin_dir" && test "$plugin_dir" != null && test -f "$plugin_dir/scripts/inspect-odw-run.sh"
sh "$plugin_dir/scripts/inspect-odw-run.sh" "$run_dir"
~~~

The accepted output contains only `run_id`, `agent_count`, and per-node `agent_id`,
`thread_id`, `model`, and `effort`. Every node must report `gpt-5.6-luna` and `high`.
Missing, duplicate, conflicting, failed, skipped, symlinked, partial, ZCode, mixed,
wrong-route, or cached evidence invalidates the entire run. The first release does not
follow cached provenance; rerun every node live.

After inspection, the Sol / Ultra primary task independently checks the actual work,
reruns relevant verification, corrects or rejects failures, and performs final review.
The inspector proves routing only; it does not prove implementation quality.
````

- [ ] **Step 4: Link ODW into the canonical orchestration skill**

In `plugins/sol-advisor/skills/orchestration/SKILL.md`, replace the two reference lines below the opening paragraph with:

```markdown
Read [references/role-contracts.md](references/role-contracts.md) before native
delegation. Read [references/odw.md](references/odw.md) before using Open Dynamic
Workflows. Use [references/operations.md](references/operations.md) for hook trust,
preflight, runtime evidence, migration, and release procedures.
```

Insert this section after `## Route delivery` and before `## Specify and verify every child task`:

```markdown
## Use ODW only for scaled or rerunnable work

Open Dynamic Workflows is an execution mechanism within `delegate` or `audit`, never a
fourth route. Use it only when its own scale or repeatability criteria apply. Confirm
enabled ODW v0.2.0, author every model node through the immutable Luna / High wrapper in
`references/odw.md`, and prohibit ZCode or mixed executors.

Inspect the exact completed run before using any result. Missing, cached, failed, or
conflicting trace and rollout evidence invalidates the whole run. A Luna synthesis is
only a draft; the Sol / Ultra primary task performs final review and acceptance.
```

Extend the final platform-boundary paragraph with:

```markdown
ODW launches independent `codex exec` subprocesses outside the native spawn hook. Its
Sol Advisor boundary is locked authoring plus fail-closed post-run acceptance, not a
pre-spawn platform policy or a modification to ODW.
```

- [ ] **Step 5: Update operator guidance for both native and ODW paths**

Change the heading and opening sentence of `plugins/sol-advisor/skills/orchestration/references/operations.md` from native-only wording to:

```markdown
# Operations

This is the maintainer and operator reference for Sol Advisor's native custom-agent and
Open Dynamic Workflows paths. Keep the README user-facing; use this page when
installing, delegating, inspecting routing, or validating a release.
```

After `## Accepted runtime evidence`, append:

```markdown
## ODW v0.2.0 evidence

Before an ODW call, verify the installed plugin is enabled at exactly v0.2.0 and use the
locked wrapper in `odw.md`. After the call, bind `run_dir` to the exact absolute run
directory returned by ODW and run the installed inspector:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -n "$plugin_dir" && test "$plugin_dir" != null && test -f "$plugin_dir/scripts/inspect-odw-run.sh"
sh "$plugin_dir/scripts/inspect-odw-run.sh" "$run_dir"
~~~

Accept only complete fresh runs where every trace and matching rollout proves Codex
GPT-5.6 Luna / High. The inspector rejects caches and emits routing evidence only. The
Sol / Ultra primary still inspects artifacts, reruns checks, and performs final review.
```

Replace the maintainer-verification closing sentence with:

```markdown
The v0.8.0 verifier covers model-sensitive `SessionStart` context, one native role,
spawn-guard fixtures, native and ODW Luna / High runtime evidence, ODW failure and
leakage refusals, three routes, JSON/TOML validity, shell syntax, installer migration
safety, and absence of retired workflow references.
```

- [ ] **Step 6: Publish concise README, manifest, and UI copy**

Insert this paragraph after the route table in `README.md`:

```markdown
When enabled Open Dynamic Workflows v0.2.0 genuinely fits a large or rerunnable task,
Sol Advisor keeps workflow design and final review in Sol / Ultra, pins every ODW model
node to Codex Luna / High, and rejects the run unless traces and Codex runtime metadata
prove every node. ODW itself remains unchanged; workflows authored outside Sol Advisor
are outside this contract.
```

Change the README operations link label from `advanced native operations` to `advanced operations`, retaining the same target.

In `plugins/sol-advisor/.codex-plugin/plugin.json`, set:

```json
"version": "0.8.0",
"description": "Automatically activated Sol / Ultra orchestration with Luna / High native children and ODW workers."
```

Set the interface copy to:

```json
"shortDescription": "Keep judgment in Sol / Ultra; route native and ODW workers to Luna / High.",
"longDescription": "Sol Advisor automatically activates in every fresh task and keeps GPT-5.6 Sol / Ultra in the primary task for architecture, material judgment, verification, final review, and acceptance. Solo is the default; delegate uses an exact native GPT-5.6 Luna / High child or, when scale requires Open Dynamic Workflows v0.2.0, trace-verified Codex Luna / High workers; audit keeps the verdict in the primary task. A trusted hook denies supported child spawns outside the native Luna / High contract, and model-sensitive startup context bounds Luna workers. ODW remains unchanged, and post-run evidence must prove every workflow node.",
"defaultPrompt": [
  "Build and verify this feature with automatic Sol Advisor routing.",
  "Keep judgment and final review in Sol / Ultra; use only Luna / High for native and ODW worker execution."
]
```

Replace `plugins/sol-advisor/skills/orchestration/agents/openai.yaml` with:

```yaml
interface:
  display_name: "Sol Advisor Orchestration"
  short_description: "Automatic Sol / Ultra review with Luna / High native and ODW workers"
  default_prompt: "Build and verify this task with automatic solo, delegate, or audit routing; keep judgment and final review in Sol / Ultra."
```

- [ ] **Step 7: Run full source verification and inspect the exact release diff**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
jq empty plugins/sol-advisor/.codex-plugin/plugin.json plugins/sol-advisor/hooks/hooks.json
python3 - <<'PY'
from pathlib import Path
import tomllib

for path in Path("plugins/sol-advisor/agents").glob("*.toml"):
    tomllib.loads(path.read_text(encoding="utf-8"))
print("TOML OK")
PY
git diff --check
git status --short
git diff --stat
```

Expected: verifier ends with `VERIFY PASSED: Sol Advisor v0.8.0 ...`; JSON and TOML parse; diff check is silent; status and stat list only the files named in this plan plus the approved spec and plan documents already on the feature branch. Confirm no ODW installation or cache path appears in the diff.

- [ ] **Step 8: Commit the independently green v0.8.0 contract**

```sh
git add README.md plugins/sol-advisor/.codex-plugin/plugin.json plugins/sol-advisor/skills/orchestration/agents/openai.yaml plugins/sol-advisor/skills/orchestration/SKILL.md plugins/sol-advisor/skills/orchestration/references/odw.md plugins/sol-advisor/skills/orchestration/references/operations.md plugins/sol-advisor/scripts/verify.sh
git commit -m "docs: publish ODW Luna High routing"
```

---

### Task 4: Install and Prove Fresh CLI and Desktop Behavior

**Files:**

- Verify only: committed v0.8.0 checkout and installed plugin state
- Do not create an acceptance artifact unless the user explicitly requests one

**Interfaces:**

- Consumes: committed Tasks 1-3, enabled ODW v0.2.0, installed Sol Advisor v0.8.0, current trusted hook definition, and fresh GPT-5.6 Sol / Ultra tasks.
- Produces: separate evidence for source verification, installed versions, hook trust, automatic routing, all-node ODW Luna / High runtime, negative refusal, and Sol / Ultra final review on CLI and desktop.

- [ ] **Step 1: Reverify the committed source and unchanged native profile**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
sh plugins/sol-advisor/scripts/install-agents.sh --check --check-role luna
git status --short --branch
git log -4 --oneline
```

Expected: both checks pass; the feature branch is clean; the commits for design, session context, ODW inspection, and release contract are visible; the native Luna profile remains exact.

- [ ] **Step 2: Install or refresh only Sol Advisor, then verify both installed plugins**

Run from the repository root:

```sh
codex plugin marketplace add /Users/jaskarn/github/sol-advisor
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -n "$plugin_dir" && test "$plugin_dir" != null && test -d "$plugin_dir" && test -f "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh"
codex plugin list --json | jq -e '
  ([.installed[] | select(.pluginId == "sol-advisor@sol-advisor" and .version == "0.8.0" and .enabled == true)] | length) == 1 and
  ([.installed[] | select(.pluginId == "open-dynamic-workflows@open-dynamic-workflows" and .version == "0.2.0" and .enabled == true)] | length) == 1
'
```

Expected: installed Sol Advisor reports enabled v0.8.0; ODW independently remains enabled v0.2.0 at its existing source; only the Sol Advisor companion profile is installed. Stop if the installed ODW version differs—do not modify it.

- [ ] **Step 3: Review and trust the changed hook definition**

Start Codex CLI on the required primary tuple:

```sh
codex -m gpt-5.6-sol -c 'model_reasoning_effort="ultra"'
```

Open `/hooks`, verify the Sol Advisor `SessionStart` command names `session-context.sh`, verify the unchanged `PreToolUse` guard, and trust the current definition. Exit and start a second fresh CLI task with the same command.

Expected: both hooks are enabled and trusted for their current hashes. A task opened before trust is not acceptance evidence.

- [ ] **Step 4: Run a fresh CLI ODW release audit through the immutable wrapper**

Submit this exact repeatable-audit prompt without naming Sol Advisor or ODW:

```text
Run a repeatable, read-only release consistency audit of this repository. Independently
check model-sensitive hook behavior, ODW trace-to-rollout enforcement, and public v0.8.0
documentation and metadata; cross-check the findings and give me the final
evidence-backed verdict. Do not modify files.
```

After the route declaration and ODW v0.2.0 preflight, call the workflow tool with
`cwd: "/Users/jaskarn/github/sol-advisor"` and this exact inline script:

```js
export const meta = {
  name: 'sol-advisor-luna-smoke',
  description: 'Prove every ODW model node is Codex Luna High',
}

const lunaAgent = (prompt, options = {}) => agent(prompt, {
  ...options,
  executor: 'codex',
  model: 'gpt-5.6-luna',
  reasoningEffort: 'high',
})

const [hooks, evidence, release] = await parallel([
  () => lunaAgent(`OBJECTIVE
Audit model-sensitive SessionStart behavior against its verifier.

FILES AND OWNERSHIP
Read only plugins/sol-advisor/hooks/hooks.json,
plugins/sol-advisor/hooks/session-context.sh, and the related verify.sh assertions.

INTERFACES
Sol gets canonical primary context; Luna gets bounded-worker context; invalid input fails.

CONSTRAINTS
Preserve all files. Do not redesign, spawn subagents, or render the final verdict.

VERIFICATION
Run focused read-only shell and jq checks and report exact evidence.

RETURN
Return findings, commands, evidence, and gaps.`, {label: 'hooks-audit'}),
  () => lunaAgent(`OBJECTIVE
Audit ODW trace-to-rollout validation and its negative fixtures.

FILES AND OWNERSHIP
Read only plugins/sol-advisor/scripts/inspect-odw-run.sh and its verify.sh fixtures.

INTERFACES
Every accepted node must be a standalone Codex GPT-5.6 Luna / High runtime.

CONSTRAINTS
Preserve all files. Do not redesign, spawn subagents, or render the final verdict.

VERIFICATION
Run focused read-only shell and jq checks and report exact evidence.

RETURN
Return findings, commands, evidence, and gaps.`, {label: 'evidence-audit'}),
  () => lunaAgent(`OBJECTIVE
Audit v0.8.0 public documentation and metadata for one consistent routing contract.

FILES AND OWNERSHIP
Read only README.md, the plugin manifest, orchestration skill, ODW reference,
operations reference, and UI YAML.

INTERFACES
ODW stays inside delegate or audit; Luna synthesis is draft; Sol owns final review.

CONSTRAINTS
Preserve all files. Do not redesign, spawn subagents, or render the final verdict.

VERIFICATION
Cross-check exact version, model, effort, route, and boundary language.

RETURN
Return findings, commands, evidence, and gaps.`, {label: 'release-audit'}),
])

const draft = await lunaAgent(
  `OBJECTIVE
Cross-check three read-only release audits and produce a draft consistency summary.

INPUTS
Hooks audit: ${JSON.stringify(hooks)}
Evidence audit: ${JSON.stringify(evidence)}
Release audit: ${JSON.stringify(release)}

CONSTRAINTS
Do not spawn subagents. Do not render the final verdict or accept the release.

RETURN
Return agreements, conflicts, missing evidence, and a draft recommendation for Sol review.`,
  {label: 'draft-synthesis'},
)

return {hooks, evidence, release, draft}
```

Expected: the workflow succeeds with three independent audits plus one draft synthesis
and reports an exact run ID under `.odw/sol-advisor-luna-smoke/runs/`. The outer task
does not adopt the draft as its verdict.

- [ ] **Step 5: Inspect the exact run and independently review the result in Sol / Ultra**

Bind `accepted_run` to the exact absolute run directory in the workflow tool result;
do not discover it with a latest-run glob. Then run:

```sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
sh "$plugin_dir/scripts/inspect-odw-run.sh" "$accepted_run"
```

Expected: `agent_count` is `4`; every node has a distinct UUID and reports only
`gpt-5.6-luna` plus `high`. Inspect the reported commands and repository artifacts
independently in the outer task, state the Sol-owned final verdict, and record the outer
task's runtime metadata as `gpt-5.6-sol` plus `ultra` separately from worker evidence.

- [ ] **Step 6: Prove a wrong-model artifact is rejected without launching a wrong model**

Copy the accepted run into a disposable canonical `.odw/sol-advisor-luna-smoke/runs/`
layout under `mktemp -d`, change only one copied trace model argument from
`gpt-5.6-luna` to `gpt-5.6-sol` with `jq`, and run the inspector against the copied run
with the real sessions directory.

Run shape:

```sh
negative_base=${TMPDIR:-/tmp}
case "$negative_base" in /*) ;; *) negative_base=/tmp ;; esac
negative_base=$(CDPATH= cd "$negative_base" && pwd -P)
negative_root=$(mktemp -d "$negative_base/sol-advisor-odw-negative.XXXXXX")
accepted_run_id=$(basename "$accepted_run")
negative_run=$negative_root/.odw/sol-advisor-luna-smoke/runs/$accepted_run_id
mkdir -p "$(dirname "$negative_run")"
cp -R "$accepted_run" "$negative_run"
jq '(.args | index("gpt-5.6-luna")) as $i | .args[$i] = "gpt-5.6-sol"' \
  "$negative_run/agents/agent-1.jsonl" > "$negative_root/trace.json"
mv "$negative_root/trace.json" "$negative_run/agents/agent-1.jsonl"
if sh "$plugin_dir/scripts/inspect-odw-run.sh" "$negative_run"; then
  printf '%s\n' 'FAIL: wrong-model ODW trace was accepted' >&2
  exit 1
fi
case "$negative_root" in
  "$negative_base"/sol-advisor-odw-negative.*) rm -rf "$negative_root" ;;
  *) printf '%s\n' 'FAIL: refusing unexpected negative-root cleanup' >&2; exit 1 ;;
esac
```

Expected: the inspector exits nonzero with its generic invalid-routing error, emits no
prompt, result, stderr, token, or environment content, and removes only its guarded
disposable negative fixture.

- [ ] **Step 7: Repeat fresh-task acceptance in ChatGPT desktop**

Open a new desktop Codex task, select GPT-5.6 Sol with Ultra reasoning, and confirm
`/hooks` shows the current trusted Sol Advisor definition. Submit the exact audit prompt
and script from Step 4. Inspect the exact new run with Step 5's command and perform final
review in the desktop primary task.

Expected: route declaration precedes task tools; all four ODW nodes are distinct Luna /
High Codex sessions; the desktop root remains Sol / Ultra; and final review stays in the
root. A reused CLI run or a desktop task opened before v0.8.0 installation and hook
trust is invalid evidence.

- [ ] **Step 8: Remove only the two generated acceptance runs**

After recording both evidence sets, bind `cli_acceptance_run` and
`desktop_acceptance_run` to the two exact inspected run directories. Remove only those
directories, then remove empty generated parents without touching other ODW workflows:

```sh
for generated_run in "$cli_acceptance_run" "$desktop_acceptance_run"; do
  case "$generated_run" in
    /Users/jaskarn/github/sol-advisor/.odw/sol-advisor-luna-smoke/runs/run-*) rm -rf "$generated_run" ;;
    *) printf '%s\n' "FAIL: refusing unexpected acceptance cleanup: $generated_run" >&2; exit 1 ;;
  esac
done
rmdir /Users/jaskarn/github/sol-advisor/.odw/sol-advisor-luna-smoke/runs 2>/dev/null || true
rmdir /Users/jaskarn/github/sol-advisor/.odw/sol-advisor-luna-smoke 2>/dev/null || true
git status --short --branch
```

Expected: only the exact two generated run directories are removed. Existing ODW
workflows or runs remain untouched, and repository status contains no acceptance
artifacts.

- [ ] **Step 9: Report each completion layer separately**

Use this exact evidence matrix in the handoff, filling each cell only from observed output:

```text
Surface   Source green   Installed version   Hooks trusted   Auto route   ODW run fresh   All nodes Luna/High   Wrong trace rejected   Review Sol/Ultra
CLI       yes|no         value               yes|no          yes|no       yes|no          yes|no                yes|no                 yes|no
Desktop   yes|no         value               yes|no          yes|no       yes|no          yes|no                yes|no                 yes|no
```

Completion requires every cell to be observed, not inferred. Report any missing layer as `not verified`; do not collapse configured, source-tested, installed, trusted, runtime-tested, rejected, reviewed, committed, pushed, or merged into one claim.
