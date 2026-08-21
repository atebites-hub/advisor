# Automatic Sol Advisor Session Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically activate the existing Sol Advisor orchestration contract in every fresh or restored supported Codex task without requiring an explicit skill invocation.

**Architecture:** Add one synchronous plugin `SessionStart` hook that writes the canonical orchestration `SKILL.md` to stdout, which Codex adds as developer context. Keep the existing `PreToolUse` Luna/High spawn guard unchanged, then update release copy and prove ordinary prompts activate the workflow in fresh CLI and desktop tasks.

**Tech Stack:** POSIX `sh`, `jq`, JSON, YAML, Markdown, Codex plugin lifecycle hooks.

## Global Constraints

- The primary task remains exactly GPT-5.6 Sol / Ultra; the plugin does not edit global Codex model configuration.
- The documented hook input does not expose reasoning effort, so the release must not claim machine-verifiable Ultra enforcement.
- Every supported child remains the exact installed `sol_advisor_luna_subagent` profile pinned to GPT-5.6 Luna / High with `fork_turns: none`.
- Sol / Ultra in the primary task owns architecture, judgment, verification, final review, and acceptance.
- The existing spawn guard remains deny-first and is not changed to rewrite tool input.
- The companion Luna profile and installer remain unchanged.
- Both lifecycle behaviors require the plugin to be enabled, the current hook definition to be trusted through `/hooks`, and a fresh task after installation or upgrade.
- Disabled, untrusted, failed, and specialized hook-bypass paths remain outside the claimed boundary.
- Reuse the existing shell and `jq` requirements; add no dependency and no duplicate policy file.
- Use the canonical `plugins/sol-advisor/skills/orchestration/SKILL.md` as the only injected orchestration source.
- Source verification, installed state, hook trust, CLI smoke, and desktop smoke are separate acceptance claims.

---

## File Structure

### Modify

- `plugins/sol-advisor/hooks/hooks.json` — register automatic `SessionStart` activation alongside the unchanged spawn guard.
- `plugins/sol-advisor/scripts/verify.sh` — test hook shape, canonical context output, v0.7.1 release copy, and unchanged Luna enforcement.
- `plugins/sol-advisor/.codex-plugin/plugin.json` — bump v0.7.1 and describe automatic activation.
- `plugins/sol-advisor/skills/orchestration/agents/openai.yaml` — remove the obsolete explicit skill invocation from the UI prompt.
- `plugins/sol-advisor/skills/orchestration/references/operations.md` — distinguish activation from spawn enforcement and update maintainer coverage.
- `README.md` — document automatic activation, trust, fresh-task, and Sol/Ultra requirements.

### Do not modify

- `plugins/sol-advisor/skills/orchestration/SKILL.md` — canonical policy injected unchanged.
- `plugins/sol-advisor/hooks/enforce-luna-subagent.sh` — existing spawn enforcement remains authoritative.
- `plugins/sol-advisor/agents/sol-advisor-luna-subagent.toml`
- `plugins/sol-advisor/scripts/install-agents.sh`
- `plugins/sol-advisor/scripts/inspect-agent-runtime.sh`
- `plugins/sol-advisor/skills/orchestration/references/role-contracts.md`

## Interfaces Between Tasks

- Task 1 produces the `SessionStart` hook and a verifier that proves its stdout is byte-identical to the canonical skill.
- Task 2 consumes that green hook, publishes matching v0.7.1 metadata and user guidance, and leaves the core orchestration and Luna contracts unchanged.
- Task 3 consumes the committed v0.7.1 checkout, installs and trusts it, proves runtime behavior in fresh tasks, and pushes the accepted commits to `origin/main`.

---

### Task 1: Add automatic canonical session context

**Files:**

- Modify: `plugins/sol-advisor/scripts/verify.sh:186-232`
- Modify: `plugins/sol-advisor/hooks/hooks.json:1-18`

**Interfaces:**

- Consumes: Codex `SessionStart` sources `startup`, `resume`, `clear`, and `compact`, plus `${PLUGIN_ROOT}` supplied by the plugin runtime.
- Produces: the complete current `plugins/sol-advisor/skills/orchestration/SKILL.md` on stdout as developer context; the existing `PreToolUse` guard behavior is unchanged.

- [ ] **Step 1: Add the failing activation configuration and output checks**

In `plugins/sol-advisor/scripts/verify.sh`, insert this block immediately after the existing spawn-guard `jq` validation and before `run_spawn_guard()`:

```sh
jq -e '
  (.hooks.SessionStart | length) == 1 and
  .hooks.SessionStart[0].matcher == "startup|resume|clear|compact" and
  (.hooks.SessionStart[0].hooks | length) == 1 and
  .hooks.SessionStart[0].hooks[0].type == "command" and
  .hooks.SessionStart[0].hooks[0].command ==
    "cat \"${PLUGIN_ROOT}/skills/orchestration/SKILL.md\"" and
  .hooks.SessionStart[0].hooks[0].timeout == 5 and
  .hooks.SessionStart[0].hooks[0].statusMessage == "Activating Sol Advisor"
' "$hooks_config" >/dev/null || fail "automatic SessionStart hook configuration is invalid"

activation_command=$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$hooks_config")
activation_output=$tmp_dir/session-start-context.md
PLUGIN_ROOT=$plugin_dir sh -c "$activation_command" </dev/null > "$activation_output" ||
  fail "automatic SessionStart hook command failed"
cmp -s "$skill" "$activation_output" ||
  fail "automatic SessionStart hook did not emit the canonical orchestration skill"
pass "automatic SessionStart hook emits canonical orchestration context"
```

Do not alter the existing `PreToolUse` validation or spawn-guard fixtures.

- [ ] **Step 2: Run the verifier and confirm the new test fails**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: exit `1` with `FAIL: automatic SessionStart hook configuration is invalid` because `hooks.json` does not yet define `SessionStart`.

- [ ] **Step 3: Add the minimal native `SessionStart` hook**

Replace `plugins/sol-advisor/hooks/hooks.json` with exactly:

```json
{
  "description": "Automatically activate Sol Advisor and require every supported subagent spawn to use its fresh Luna / High profile.",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "cat \"${PLUGIN_ROOT}/skills/orchestration/SKILL.md\"",
            "timeout": 5,
            "statusMessage": "Activating Sol Advisor"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "collaborationspawn_agent|spawn_agent|Agent",
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

- [ ] **Step 4: Run focused syntax and canonical-output checks**

Run:

```sh
jq empty plugins/sol-advisor/hooks/hooks.json
activation_command=$(jq -r '.hooks.SessionStart[0].hooks[0].command' plugins/sol-advisor/hooks/hooks.json)
PLUGIN_ROOT=/Users/jaskarn/github/sol-advisor/plugins/sol-advisor sh -c "$activation_command" > /tmp/sol-advisor-session-context.md
cmp plugins/sol-advisor/skills/orchestration/SKILL.md /tmp/sol-advisor-session-context.md
```

Expected: every command exits `0`; `cmp` prints nothing.

- [ ] **Step 5: Run the full repository verifier**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
```

Expected: the verifier ends with `VERIFY PASSED: Sol Advisor v0.7.0 Sol / Ultra and Luna / High checks completed` and the new `PASS: automatic SessionStart hook emits canonical orchestration context`; `git diff --check` exits `0`.

- [ ] **Step 6: Commit the independently green activation hook**

```sh
git add plugins/sol-advisor/hooks/hooks.json plugins/sol-advisor/scripts/verify.sh
git commit -m "feat: activate Sol Advisor on session start"
```

---

### Task 2: Publish the automatic v0.7.1 workflow

**Files:**

- Modify/Test: `plugins/sol-advisor/scripts/verify.sh:234-245,470-499,550`
- Modify: `plugins/sol-advisor/.codex-plugin/plugin.json:3-22`
- Modify: `plugins/sol-advisor/skills/orchestration/agents/openai.yaml:1-3`
- Modify: `plugins/sol-advisor/skills/orchestration/references/operations.md:18-28,95-108`
- Modify: `README.md:10-39`

**Interfaces:**

- Consumes: the green `SessionStart` hook from Task 1 and the existing unchanged orchestration/Luna contracts.
- Produces: consistent v0.7.1 metadata, UI copy, user instructions, maintainer instructions, and release assertions that no longer require explicit skill invocation.

- [ ] **Step 1: Change release assertions first**

In `plugins/sol-advisor/scripts/verify.sh`, replace the current manifest version check and its pass message with:

```sh
[ "$(jq -r '.version' "$manifest")" = 0.7.1 ] || fail "manifest version is not 0.7.1"
```

After the existing manifest language assertions, add:

```sh
grep -Fq 'automatically activates in every fresh task' "$manifest" ||
  fail "manifest omits automatic activation"
if grep -Fq '$sol-advisor:orchestration' "$manifest"; then
  fail "manifest still requires explicit orchestration invocation"
fi
pass "manifest JSON and v0.7.1 automatic Sol / Ultra and Luna / High release language"
```

Remove the old v0.7.0 manifest `pass` line.

After the existing `/hooks` README assertion, add:

```sh
grep -Fq 'automatically loads the orchestration contract' "$readme" ||
  fail "README omits automatic activation"
grep -Fq 'SessionStart' "$operations" || fail "operations omit SessionStart activation"
grep -Fq 'PreToolUse' "$operations" || fail "operations omit spawn enforcement"
grep -Fq 'automatic' "$ui" || fail "UI copy omits automatic activation"
if grep -Fq '$orchestration' "$ui"; then
  fail "UI prompt still requires explicit orchestration invocation"
fi
```

Replace the final verifier line with:

```sh
printf '%s\n' "VERIFY PASSED: Sol Advisor v0.7.1 automatic Sol / Ultra and Luna / High checks completed in $tmp_dir"
```

- [ ] **Step 2: Run the verifier and confirm the release test fails**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: exit `1` with `FAIL: manifest version is not 0.7.1`.

- [ ] **Step 3: Update the manifest to v0.7.1 automatic activation**

In `plugins/sol-advisor/.codex-plugin/plugin.json`, set these exact fields:

```json
"version": "0.7.1",
"description": "Automatically activated Codex-native routing with a Sol / Ultra primary task and Luna / High children."
```

Replace `interface.shortDescription`, `interface.longDescription`, and `interface.defaultPrompt` with:

```json
"shortDescription": "Automatically keep judgment and review in Sol / Ultra; enforce Luna / High for every supported child.",
"longDescription": "Sol Advisor automatically activates in every fresh task, keeps GPT-5.6 Sol / Ultra in the primary task for architecture, material judgment, verification, review, and acceptance, and uses one native GPT-5.6 Luna / High child for bounded work. Solo is the default; audit keeps the verdict in the primary task. A trusted plugin hook denies supported child spawns outside the exact Luna / High contract, and runtime evidence must confirm the role, model, and effort.",
"defaultPrompt": [
  "Build and verify this feature with automatic Sol Advisor routing.",
  "Keep judgment and final review in Sol / Ultra; use only the Luna / High child for bounded delegated work."
]
```

Keep all other manifest fields unchanged.

- [ ] **Step 4: Remove explicit invocation from the skill UI prompt**

Replace `plugins/sol-advisor/skills/orchestration/agents/openai.yaml` with exactly:

```yaml
interface:
  display_name: "Sol Advisor Orchestration"
  short_description: "Automatic Sol / Ultra judgment and review with Luna / High children"
  default_prompt: "Build and verify this task with automatic solo, delegate, or audit routing; keep judgment and final review in Sol / Ultra."
```

- [ ] **Step 5: Document activation and enforcement as separate trusted hooks**

In `README.md`, replace the paragraph beginning `After installation, open /hooks` with:

```markdown
After installation, open `/hooks`, review and trust the Sol Advisor lifecycle hooks,
then start a fresh task on Sol / Ultra. The trusted `SessionStart` hook automatically
loads the orchestration contract for ordinary prompts; no explicit skill invocation is
required. The trusted `PreToolUse` hook enforces supported child spawns. Until the
hooks are trusted, neither automatic activation nor spawn enforcement is active.
```

In `plugins/sol-advisor/skills/orchestration/references/operations.md`, replace the `## Hook trust and boundary` section and its two paragraphs with:

```markdown
## Automatic activation, hook trust, and boundary

The plugin's synchronous `SessionStart` hook emits the canonical orchestration
`SKILL.md` as developer context on `startup`, `resume`, `clear`, and `compact`. The
separate synchronous `PreToolUse` hook denies supported child spawns that do not use
the exact contract above.

Review and trust both lifecycle behaviors through `/hooks` after installation or every
hook definition change, then start a fresh task. Disabled, untrusted, failed, and
specialized opt-out paths are not covered; runtime evidence remains required. The
hooks do not select or prove the primary task's reasoning effort.
```

Replace the maintainer-verification release sentence with:

```markdown
The v0.7.1 verifier covers automatic canonical `SessionStart` context, one role, spawn
guard fixtures, Luna / High runtime evidence, three routes, JSON/TOML validity, shell
syntax, installer migration safety, and absence of retired workflow references.
```

- [ ] **Step 6: Run complete source verification**

Run:

```sh
jq empty plugins/sol-advisor/.codex-plugin/plugin.json plugins/sol-advisor/hooks/hooks.json
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git status --short
```

Expected: JSON parsing succeeds; verifier ends with `VERIFY PASSED: Sol Advisor v0.7.1 automatic Sol / Ultra and Luna / High checks completed`; diff check exits `0`; status lists only the intended five modified files.

- [ ] **Step 7: Commit the independently green v0.7.1 release copy**

```sh
git add README.md plugins/sol-advisor/.codex-plugin/plugin.json plugins/sol-advisor/skills/orchestration/agents/openai.yaml plugins/sol-advisor/skills/orchestration/references/operations.md plugins/sol-advisor/scripts/verify.sh
git commit -m "docs: publish automatic Sol Advisor activation"
```

---

### Task 3: Verify installation, trust, fresh-task activation, and origin

**Files and external state:**

- Read-only source verification in `/Users/jaskarn/github/sol-advisor`.
- Mutate only the configured Sol Advisor marketplace/plugin and Sol Advisor-owned files under `/Users/jaskarn/.codex/agents` after source checks pass.
- Do not edit unrelated agents or global model configuration.
- Push accepted commits to `origin/main` only after source and live evidence are green.

**Interfaces:**

- Consumes: committed v0.7.1 checkout, enabled plugin, installed Luna profile, trusted current hook hash, and fresh GPT-5.6 Sol / Ultra tasks.
- Produces: separate evidence for source verification, installed version, hook trust, implicit activation, Luna/High runtime, wrong-spawn denial, Sol/Ultra review ownership, and synchronized `origin/main`.

- [ ] **Step 1: Re-run source acceptance before changing installed state**

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git status --short --branch
git log -5 --oneline --decorate
```

Expected: verifier passes; diff check exits `0`; branch is clean and ahead of `origin/main` only by the approved design, plan, and implementation commits.

- [ ] **Step 2: Capture current installed state**

Run:

```sh
codex plugin list --json | jq '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | {version, enabled, source}'
find /Users/jaskarn/.codex/agents -mindepth 1 -maxdepth 1 -type f -name 'sol-advisor-*.toml' -print -exec shasum -a 256 {} \;
```

Expected: an evidence snapshot of the installed plugin and only Sol Advisor-owned agent paths; do not infer v0.7.1 from the checkout.

- [ ] **Step 3: Install the v0.7.1 checkout and verify the companion profile**

Run:

```sh
codex plugin marketplace remove sol-advisor
codex plugin marketplace add /Users/jaskarn/github/sol-advisor --json
codex plugin add sol-advisor@sol-advisor --json
plugin_dir=$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')
test -n "$plugin_dir" && test "$plugin_dir" != null && test -d "$plugin_dir"
codex plugin list --json | jq -e '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .version == "0.7.1" and .enabled == true'
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check --check-role luna
```

Expected: plugin list reports enabled v0.7.1 and the installer reports the exact Luna/High profile current. If an installed Sol Advisor file is modified or unsafe, stop and report its exact path instead of replacing it.

- [ ] **Step 4: Trust the changed hook definition and start a fresh CLI task**

Start:

```sh
codex -m gpt-5.6-sol -c 'model_reasoning_effort="ultra"'
```

Open `/hooks`, review the Sol Advisor `SessionStart` and `PreToolUse` entries, and trust the current definition. Exit that task and start another fresh task with the same command.

Expected: `/hooks` shows the plugin hook trusted at its current hash and the fresh task has no pending-trust warning. Do not count the pre-trust task as activation evidence.

- [ ] **Step 5: Prove implicit CLI activation with an ordinary prompt**

In the fresh CLI task, submit exactly:

```text
Inspect the current repository status and explain which route you will use before running any task tool. Then perform one read-only repository check.
```

Do not name the plugin or orchestration skill.

Expected: the primary emits one `SELECTIVE ROUTE` declaration before its first task tool, identifies `solo`, `delegate`, or `audit`, and keeps final judgment in the Sol / Ultra task.

- [ ] **Step 6: Reconfirm CLI Luna enforcement and root review**

Ask the same fresh task to delegate one bounded read-only check using the configured Sol Advisor child. Inspect the returned child ID:

```sh
plugin_dir=$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')
printf 'Child thread UUID: ' >&2
IFS= read -r child_thread_id
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" "$child_thread_id"
```

Expected JSON: `agent_role` is `sol_advisor_luna_subagent`, `model` is `gpt-5.6-luna`, and `effort` is `high`. The Sol / Ultra primary independently checks the returned evidence and renders the final conclusion.

Then request a deliberate `agent_type: worker`, `fork_turns: none` enforcement probe.

Expected: the call is denied before a child ID exists and the reason names the exact Luna contract.

- [ ] **Step 7: Repeat implicit activation and enforcement in ChatGPT desktop**

Open a new Codex task in the ChatGPT desktop app, select GPT-5.6 Sol with Ultra reasoning, and confirm `/hooks` reports the current Sol Advisor hook trusted. Submit the ordinary prompt from Step 5 without naming the plugin, then repeat the valid Luna child and invalid built-in worker probes from Step 6.

Expected: the route declaration precedes task tools; the valid child reports Luna/High; the invalid spawn creates no child; and the root task performs final review. A task opened before v0.7.1 installation or hook trust is invalid evidence.

- [ ] **Step 8: Record the acceptance matrix**

Report actual evidence in this form, using `not verified` rather than inference:

```text
Surface          Source  Installed  Hook trusted  Implicit route  Luna/High runtime  Wrong spawn denied  Review stayed Sol/Ultra
Codex CLI        yes/no  yes/no     yes/no        yes/no          yes/no             yes/no               yes/no
ChatGPT desktop  yes/no  yes/no     yes/no        yes/no          yes/no             yes/no               yes/no
```

- [ ] **Step 9: Push the accepted release to origin**

Run:

```sh
git push origin main
git status --short --branch
git rev-parse HEAD
git rev-parse origin/main
```

Expected: push succeeds; branch is clean and synchronized; the two revision hashes are identical.

---

## Final Completion Check

Before claiming the plugin is done, run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git status --short --branch
codex plugin list --json | jq -e '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .version == "0.7.1" and .enabled == true'
git rev-parse HEAD
git rev-parse origin/main
```

Completion requires a green verifier, clean synchronized branch, installed/enabled v0.7.1, trusted current hook definition, fresh-task implicit activation in both CLI and desktop, Luna/High child evidence, wrong-spawn denial, and Sol/Ultra primary review evidence. Report any missing surface as `not verified`; do not collapse configured, installed, trusted, source-tested, live-tested, and pushed into one claim.
