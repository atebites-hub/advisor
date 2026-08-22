# Advisor Native Adapters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generalize the current Codex-only Sol Advisor package into Advisor, with exact configurable advisor/grunt tuples, strict native and ODW acceptance on hosts that expose runtime proof, and truthful fail-closed status on hosts that do not.

**Architecture:** Keep package/plugin ID `sol-advisor` and use `Advisor` as the display name. Reuse each host's native primary/subagent mechanism; add only small POSIX shell render/doctor/inspection scripts and host-native manifests/hooks. Expose configuration through an installed `advisor` skill that invokes the packaged helper by plugin-relative path; plugin installation does not export binaries to `PATH`. Store no credentials, perform no model-name translation, and never create a cross-host agent daemon or adapter framework.

**Tech Stack:** POSIX shell, jq, TOML/JSON/Markdown, Codex hooks/custom agents/rollouts, ZCode plugin config/hooks/runtime attestation, Grok/Cursor/Claude compatibility manifests, ODW 0.3.x policy/traces.

## Initial Support Matrix

| Host | Native lane | ODW lane | Initial label |
|---|---|---|---|
| Codex CLI / ChatGPT Codex app | exact custom grunt + rollout evidence | Codex executor + rollout evidence | strict after live CLI/app smoke |
| ZCode | `main`/`lite` + patched hook attestation | ZCode executor + ODW attestation | strict after merged fork/live smoke |
| Grok Build 1.0.5 | hook runner is fail-open on handler failure | runtime effort cannot repair the native guard | experimental; delegation disabled |
| Cursor | resolved effort not authoritative | resolved effort not authoritative | experimental; delegation disabled |
| Claude Code | resolved model available, resolved effort not authoritative | resolved effort not authoritative | experimental; delegation disabled |
| Grok Bot | excluded | excluded | excluded |

The implementation must not turn Cursor, Claude, or Grok configuration intent into runtime proof. Cursor and Claude need resolved-effort evidence. Grok additionally needs a host version whose hook runner fails closed on missing scripts, crashes, timeouts, and malformed output. Until those gates pass, Advisor packages guidance/doctor surfaces but no strict delegation for those hosts.

## Shared Profile Schema

Codex uses:

```json
{
  "schemaVersion": 1,
  "host": "codex",
  "advisor": {
    "model": "gpt-5.6-sol",
    "effort": "ultra"
  },
  "grunt": {
    "model": "gpt-5.6-luna",
    "effort": "high"
  }
}
```

Default directory:

```text
ADVISOR_CONFIG_HOME when explicitly set
otherwise XDG_CONFIG_HOME/advisor when XDG_CONFIG_HOME is set
otherwise HOME/.config/advisor
```

The filename is `codex.json`. ZCode's source of truth is the enabled plugin's `userConfig` values; the maintained runtime overlays those values in memory at session creation and never rewrites host-owned `model.*` fields. Do not maintain a duplicate profile.

Allowed tuple tokens:

```text
model:  ^[A-Za-z0-9][A-Za-z0-9._:+/-]{0,255}$
effort: ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$
```

Each Codex root session snapshots both configured tuples and a fixed-key SHA-256 fingerprint at `SessionStart` under the Advisor config directory, keyed by validated runtime/session ID. The mode-`600` snapshot is the expected policy for that running session; guards never reread mutable live configuration. A changed profile affects only a new session. ZCode reuses its runtime-owned persisted main/lite route snapshot and attested fingerprint instead of writing a duplicate Advisor file.

Hash exactly this compact fixed-key object with `shasum -a 256`:

```json
{"advisorModel":"...","advisorEffort":"...","gruntModel":"...","gruntEffort":"..."}
```

The snapshot contains only `schemaVersion`, `host`, validated `runtimeId`, that four-field policy, `policyFingerprint`, and `createdAt`. Reject unknown fields and never store prompts, transcripts, credentials, or arbitrary environment data.

---

### Task 1: Add the Minimal `advisor` Configure/Doctor Command

**Files:**

- Create: `plugins/sol-advisor/bin/advisor`
- Create: `plugins/sol-advisor/skills/advisor/SKILL.md`
- Create: `plugins/sol-advisor/scripts/verify-config.sh`
- Modify: `plugins/sol-advisor/scripts/verify.sh`

**CLI contract:**

```text
$advisor configure --host codex \
  --advisor-model MODEL --advisor-effort EFFORT \
  --grunt-model MODEL --grunt-effort EFFORT

$advisor apply --host codex
$advisor doctor --host codex|zcode|grok|cursor|claude [--json]
$advisor remove --host codex
```

`$advisor` above is the installed Codex skill invocation; document the equivalent skill invocation syntax on other hosts. The skill resolves and executes `../../bin/advisor` from its own installed directory. Never claim that plugin installation adds a bare `advisor` executable to `PATH`.

- [ ] **Step 1: Write failing profile tests**

In `verify-config.sh` use a disposable `ADVISOR_CONFIG_HOME` and assert:

- a complete Codex profile writes a mode `600` file through same-directory temporary rename,
- incomplete, duplicate, unknown, empty, unsafe-token, extra-positional, and unknown-host arguments fail without a file,
- an existing symlink/nonregular/unreadable profile fails,
- a valid existing profile is replaced only by explicit `configure`,
- unrelated files under the config directory are unchanged,
- Codex with no profile reports the built-in Sol/Ultra + Luna/High default,
- an available local model catalog accepts supported model/effort tuples and rejects unsupported ones; when no authoritative catalog is locally available, configure records the syntactically valid tuple but reports capability as unverified for `doctor` to block before activation,
- `doctor --json` is one allowlisted JSON object and never mutates files,
- Cursor and Claude doctor return nonzero with machine code `runtime_effort_attestation_unavailable`,
- Grok doctor returns nonzero with machine code `hook_failure_is_fail_open`,
- Grok Bot is rejected as an unknown/excluded host.
- `remove` refuses symlinks/nonregular or malformed ownership records, removes an exact rendered Codex role/profile/session snapshots, preserves unrelated files, and is idempotent after successful cleanup.

Run:

```sh
sh plugins/sol-advisor/scripts/verify-config.sh
```

Expected: failure because `bin/advisor` does not exist.

- [ ] **Step 2: Implement one POSIX shell command**

Reuse `jq`, `mktemp`, `chmod`, and `mv`. Keep argument parsing, profile validation, atomic write, and doctor dispatch in one file. Do not add a shell library, package manager, schema framework, or daemon.

`configure` prints the exact path written and “run `$advisor apply --host codex`, then start a new session.” `apply` reuses the existing exact-digest role installer. `doctor` reports independently:

- host CLI/version present,
- profile valid,
- advisor tuple available/observable,
- grunt tuple available/observable,
- generated/installed files current,
- hook status/trust where queryable,
- ODW plugin compatible,
- native lane status,
- ODW lane status.

No check may infer runtime success from configuration alone.

The installed skill is the public command surface. Add a disposable-marketplace smoke that installs the plugin, invokes `$advisor doctor --host codex` through Codex, proves the packaged helper ran, and verifies `command -v advisor` is not required. Do not install a symlink or mutate the user's shell startup files.

`remove` is an explicit pre-uninstall action for Codex. It deletes only the exact current Codex role, valid Advisor profile, and validated session snapshots. ZCode needs no rollback command: uninstalling the plugin owns its `userConfig` and hooks, while host-owned session history remains ordinary history and Advisor never rewrites host model settings.

- [ ] **Step 3: Wire the focused verifier into the repository verifier**

At the end of `verify.sh` call:

```sh
sh "$script_dir/verify-config.sh"
```

- [ ] **Step 4: Run checks and commit**

```sh
sh -n plugins/sol-advisor/bin/advisor
sh -n plugins/sol-advisor/scripts/verify-config.sh
sh plugins/sol-advisor/scripts/verify-config.sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git add plugins/sol-advisor/bin/advisor plugins/sol-advisor/skills/advisor plugins/sol-advisor/scripts/verify-config.sh plugins/sol-advisor/scripts/verify.sh
git commit -m "feat: add Advisor configuration and doctor"
```

---

### Task 2: Generalize the Strict Codex Adapter

**Files:**

- Replace: `plugins/sol-advisor/agents/sol-advisor-luna-subagent.toml`
- Create: `plugins/sol-advisor/templates/codex-advisor-grunt.toml.in`
- Modify: `plugins/sol-advisor/scripts/install-agents.sh`
- Rename/modify: `plugins/sol-advisor/scripts/inspect-agent-runtime.sh` to `plugins/sol-advisor/scripts/inspect-codex-runtime.sh`
- Rename/modify: `plugins/sol-advisor/hooks/enforce-luna-subagent.sh` to `plugins/sol-advisor/hooks/enforce-codex.sh`
- Modify: `plugins/sol-advisor/hooks/session-context.sh`
- Modify: `plugins/sol-advisor/hooks/hooks.json`
- Modify: `plugins/sol-advisor/bin/advisor`
- Modify: `plugins/sol-advisor/scripts/verify.sh`

**Installed role:**

```toml
name = "advisor_grunt"
model = "<configured grunt model>"
model_reasoning_effort = "<configured grunt effort>"
```

- [ ] **Step 1: Add failing migration/render tests**

Extend `verify.sh` to prove:

- no profile renders the default `gpt-5.6-luna` / `high` role,
- a custom profile renders its exact grunt tuple,
- model/effort values cannot inject TOML,
- install uses a private staged file and never overwrites a modified `advisor-grunt.toml`,
- exact historical `sol-advisor-luna-subagent.toml` and older Luna/Terra/Sol files are retired,
- modified historical files are reported as conflicts and no destination changes,
- check mode verifies the rendered current file against the active profile.
- a profile change after `SessionStart` does not alter the running session's expected advisor/grunt tuples; a new session snapshots the new profile.
- missing, malformed, duplicate-ID, symlinked, or nonregular session-policy snapshots fail closed.

Run:

```sh
sh plugins/sol-advisor/scripts/verify.sh
```

Expected: the new generic-role assertions fail.

- [ ] **Step 2: Render the one generic role**

Change installer usage to:

```text
install-agents.sh [--target-dir PATH] [--profile PATH] [--check]
```

When `--profile` is omitted, use the default Codex profile path; if absent, use the built-in default tuple. Render only `templates/codex-advisor-grunt.toml.in` to a disposable file, then reuse the current preflight/install/retire algorithm.

Keep the exact known historical digests. Add the current v0.8.x `sol-advisor-luna-subagent.toml` digest to the retirement allowlist. Never remove a file whose bytes are not known.

- [ ] **Step 3: Write failing runtime-inspector tests**

The new interface is:

```text
inspect-codex-runtime.sh --mode native [--sessions-dir DIR] --policy SNAPSHOT --role advisor|grunt [--result FILE] THREAD_ID
inspect-codex-runtime.sh --mode odw [--sessions-dir DIR] --route POLICY_FILE --result FILE THREAD_ID
```

Test:

- primary exact match,
- grunt exact match with `agent_role=advisor_grunt`,
- wrong/missing/duplicate/conflicting model or effort,
- wrong parent/role,
- identical advisor/grunt model-and-effort tuples with role still distinguished by authoritative `agent_role` and parent metadata,
- completed child tool result joined to the same runtime ID,
- failed, timed-out, cancelled, incomplete, or ID-mismatched child result,
- duplicate rollout filenames,
- symlink/nonregular paths,
- output allowlist only.

- [ ] **Step 4: Generalize the inspector**

Reuse the current rollout filename join and `session_meta`/`turn_context` parsing. Select expected tuple from `profile.advisor` or `profile.grunt`; for a missing default Codex profile, use the built-in profile.

Emit only:

```json
{
  "runtime_id": "...",
  "parent_runtime_id": "...",
  "role": "advisor_grunt",
  "model": "...",
  "effort": "...",
  "cwd": "...",
  "state": "running|completed|failed|cancelled|timed_out"
}
```

For `--role grunt`, success requires the supplied tool result and rollout evidence to name the same child runtime ID, the expected parent, and `state=completed`. Primary inspection accepts only the live/running primary state. The inspector reads expected tuples only from the immutable session-policy snapshot, never from the current profile.

ODW mode is intentionally not native-grunt mode. It reads the canonical three-field ODW policy from `--route`, requires a standalone completed Codex execution with no `advisor_grunt` role or native parent, joins `--result` to the same runtime ID, and compares actual model/effort to the ODW policy. Reject missing/extra route fields, native-child metadata, wrong IDs, or non-completed state.

- [ ] **Step 5: Enforce the primary and the one supported child**

Replace the spawn-only hook with one primary `PreToolUse` hook whose matcher is `.*`. At root `SessionStart`, atomically snapshot both configured tuples under the root session ID. `enforce-codex.sh` reads that snapshot, calls `inspect-codex-runtime.sh --mode native --role advisor`, and denies every supported primary tool when the primary model/effort is wrong or unavailable. Omitting or supplying an unknown mode is an error covered by the inspector tests.

When the tool is a supported spawn call, the same script additionally allows only:

```text
agent_type: advisor_grunt
fork_turns: none
no model override
no reasoning_effort override
```

The role file pins the exact configured tuple. After completion, the primary runs the inspector on the child's runtime ID before accepting output.

Codex subagent `PreToolUse` payloads expose the parent `session_id`, not the child `agent_id`; do not claim child-tool runtime enforcement from that payload. Prelaunch strictness comes from the primary spawn guard plus the immutable generated role. Register `SubagentStart` only to inject bounded-grunt context using its `agent_id`/`agent_type`; it cannot block. Post-run acceptance joins the spawn result's child ID to the child rollout and rejects wrong role/parent/tuple or any non-completed state. Add a captured CLI/app hook-payload fixture proving these exact fields before advertising the lane.

- [ ] **Step 6: Make startup context role-generic**

`session-context.sh` emits the Advisor orchestration skill at root `SessionStart`. A `SubagentStart` entry emits bounded-worker context only when its payload names `agent_type=advisor_grunt`; otherwise it emits no role claim. Never infer role from model, and never use the parent `session_id` as child identity.

Add hook-state probes: untrusted/disabled Codex hooks make `$advisor doctor` nonzero and the host unsupported; a trusted hook that crashes, times out, or emits malformed JSON must exercise Codex's documented fail-closed behavior or leave the lane disabled. Installation/context alone is not proof that the hook ran.

- [ ] **Step 7: Run checks and commit**

```sh
sh -n plugins/sol-advisor/scripts/install-agents.sh
sh -n plugins/sol-advisor/scripts/inspect-codex-runtime.sh
sh -n plugins/sol-advisor/hooks/enforce-codex.sh
jq empty plugins/sol-advisor/hooks/hooks.json
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git add plugins/sol-advisor
git commit -m "feat: generalize strict Codex Advisor routing"
```

---

### Task 3: Add the Strict ZCode Adapter

**Files:**

- Create: `plugins/sol-advisor/.zcode-plugin/plugin.json`
- Create: `plugins/sol-advisor/hosts/zcode/hooks/hooks.json`
- Create: `plugins/sol-advisor/hosts/zcode/hooks/enforce.sh`
- Create: `plugins/sol-advisor/scripts/inspect-zcode-runtime.sh`
- Create/modify: root `marketplace.json`
- Test: `plugins/sol-advisor/scripts/verify-host-adapters.sh`

**ZCode plugin settings:**

```json
{
  "userConfig": {
    "advisor_model": {"type":"string","title":"Advisor model","required":true},
    "advisor_effort": {"type":"string","title":"Advisor effort","required":true},
    "grunt_model": {"type":"string","title":"Grunt model","required":true},
    "grunt_effort": {"type":"string","title":"Grunt effort","required":true}
  }
}
```

Set the ZCode manifest's hooks entry to `./hosts/zcode/hooks/hooks.json`; keep the host implementation in that one manifest-owned directory.

- [ ] **Step 1: Add failing manifest/settings tests**

Use a disposable ZCode config and assert:

- the four settings are required non-sensitive strings,
- the enabled Advisor plugin is found by its exact package ID and incomplete/ambiguous/unsafe settings keep strict mode disabled,
- runtime session creation reads only that enabled plugin's configured options and maps them in memory to `main`/`mainThoughtLevel` and `lite`/`liteThoughtLevel`,
- the host config's byte hash and unrelated plugins/hooks/provider fields never change,
- plugin-provided hooks are discovered and run even while the user-level default remains `hooks.enabled:false`; if the current host does not provide this lifecycle, strict mode remains disabled rather than rewriting the global hook setting.

Run:

```sh
sh plugins/sol-advisor/scripts/verify-host-adapters.sh
```

Expected: failure because the ZCode adapter does not exist.

- [ ] **Step 2: Use settings without mutating host model fields**

ZCode's Settings → Plugin Management UI stores the desired tuple. The merged ZCode runtime adapter reads that exact enabled-plugin record once when a new primary session is created, snapshots both tuples into the session's persisted route selection, and selects its `main`/`lite` roles from that snapshot. Changing plugin settings affects only a subsequent `/new` session and its children.

Do not introduce a ZCode-specific background service, copy values into host-owned `model.*`, mutate provider credentials, or change user-level `hooks.enabled`.

- [ ] **Step 3: Add failing attestation inspector tests**

Interface:

```text
inspect-zcode-runtime.sh --mode native --role advisor|grunt [--config FILE]
inspect-zcode-runtime.sh --mode odw --route POLICY_FILE --result FILE
```

The hook event arrives on stdin and must contain exactly one merged-fork `runtimeAttestation`. Test exact primary/grunt matches plus missing, duplicate, malformed, wrong route, wrong runtime version, wrong model, wrong effort, wrong/missing four-field role policy, fingerprint, policy source, `main|lite` role, parent, fallback, and incomplete child cases. Recompute the fingerprint from the attested policy and select the expected tuple by authoritative role. Include identical advisor/grunt tuples to prove role comes from runtime-owned role/parent fields rather than the model name.

ODW mode requires `route=odw`, `role=main`, `parentSessionId=null`, `policySource=null`, `rolePolicy=null`, `rolePolicyFingerprint=null`, the runtime ID named by the successful `zcode_result`, and exact model/effort from `--route`. It does not apply native `lite` or parent-child rules. Add valid and cross-mode rejection fixtures so neither native evidence nor ODW evidence is accepted through the wrong contract.

- [ ] **Step 4: Implement hook enforcement**

One `enforce.sh` handles the registered events. On only the first `SessionStart` of a brand-new root (`role=main`, no parent, `policySource=new`), it requires the attested four-field policy to equal the current complete plugin settings. A restored root must use `policySource=persisted`; a child must use `policySource=parent`. Those paths never reread mutable settings. Every event requires a complete policy, recomputes its fingerprint, and compares the attested model/effort to the role-selected tuple. Add one A -> settings B -> resume A -> spawn A child -> new B root fixture.

The child guard allows only ZCode's native Agent/subagent route with no explicit alternate model/effort. The runtime must use the parent session's persisted `lite` tuple for every child, including background/resumed Agent paths. Child completion joins authoritative `role=lite`, `parentSessionId`, runtime ID, final state, model, and effort to the tool result; any mismatch or failed/timed-out/cancelled/incomplete state is unusable.

Hook denial exits with ZCode's documented blocking status and a concise correction. Never treat agent frontmatter as runtime proof; ZCode records plugin agents but does not execute them, so do not ship a fake ZCode agent definition.

Add lifecycle failure probes for a missing/crashing/timed-out/malformed plugin hook and a disabled plugin. Strict support requires the current ZCode version to stop or mark the session unsupported in each case. Preserve the shipped user-hook default; plugin hook discovery, not global mutation, must supply the enforcement path.

- [ ] **Step 5: Run checks and commit**

```sh
jq empty plugins/sol-advisor/.zcode-plugin/plugin.json
jq empty plugins/sol-advisor/hosts/zcode/hooks/hooks.json
sh -n plugins/sol-advisor/hosts/zcode/hooks/enforce.sh
sh -n plugins/sol-advisor/scripts/inspect-zcode-runtime.sh
sh plugins/sol-advisor/scripts/verify-host-adapters.sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git add marketplace.json plugins/sol-advisor
git commit -m "feat: add strict ZCode Advisor routing"
```

---

### Task 4: Package Truthful Grok Build Compatibility

**Files:**

- Create: `plugins/sol-advisor/.grok-plugin/plugin.json`
- Create/modify: root `.grok-plugin/marketplace.json`
- Modify: `plugins/sol-advisor/bin/advisor`
- Test: `plugins/sol-advisor/scripts/verify-host-adapters.sh`

Grok Build 1.0.5 can block when a hook successfully emits an explicit deny, but missing scripts, crashes, timeouts, and malformed output are fail-open. That cannot meet the approved identical-strict policy. Package the Advisor skill/docs and a truthful doctor result only; do not install a role or guard that looks strict.

- [ ] **Step 1: Add failing capability-status tests**

Assert:

- the manifest validates and exposes only Advisor skill/docs,
- no strict Grok agent/role or Advisor hook is registered,
- `doctor --host grok --json` returns `strict:false` and `hook_failure_is_fail_open`,
- attempts to configure or enable strict Grok delegation fail without writing files,
- docs never label the current Grok version strict.

- [ ] **Step 2: Record the exact promotion gate**

Add a test harness for a future Grok version using its documented `.grok/roles/<role>.toml` discovery and `spawn_subagent` input (`toolInput.subagent_type`). Promotion requires all of:

1. missing handler blocks,
2. crashing handler blocks,
3. timed-out handler blocks,
4. malformed output blocks,
5. explicit deny blocks the exact wrong `subagent_type`/model/effort call,
6. successful child history exposes parent ID, child ID, final state, resolved model, and resolved effort.

Do not add the role, hook, renderer, inspector, or configuration surface until a current installed host passes this gate.

- [ ] **Step 3: Run checks and commit**

```sh
jq empty plugins/sol-advisor/.grok-plugin/plugin.json
sh plugins/sol-advisor/scripts/verify-host-adapters.sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git add .grok-plugin plugins/sol-advisor
git commit -m "feat: add truthful Grok Build compatibility"
```

---

### Task 5: Package Truthful Cursor and Claude Surfaces

**Files:**

- Create: `plugins/sol-advisor/.cursor-plugin/plugin.json`
- Create: `plugins/sol-advisor/.claude-plugin/plugin.json`
- Create/modify: root `.cursor-plugin/marketplace.json`
- Create/modify: root `.claude-plugin/marketplace.json`
- Modify: `plugins/sol-advisor/bin/advisor`
- Test: `plugins/sol-advisor/scripts/verify-host-adapters.sh`

These are content-only host manifests: expose the existing Advisor skill, CLI, and status documentation, but register no child agent and no enforcement hook until the host supplies authoritative resolved-effort evidence.

- [ ] **Step 1: Add failing capability-status tests**

Assert:

- both manifests validate and expose the Advisor skill/docs,
- neither manifest registers a strict child agent or ODW auto-route,
- `doctor --host cursor --json` returns `strict:false` and `runtime_effort_attestation_unavailable`,
- `doctor --host claude --json` returns the same code,
- attempts to configure/enable strict delegation on either host fail without writing files,
- docs do not label either host strict/supported.

- [ ] **Step 2: Add content-only compatibility manifests**

Package the orchestration guidance and doctor command only. Do not ship a Cursor/Claude grunt whose frontmatter appears strict but whose actual effort cannot be proved.

The manifests must say “experimental detection; strict delegation disabled.” Claude's experimental Advisor tool is not enabled or referenced as a supported route.

- [ ] **Step 3: Define the exact promotion gate**

Document that either host becomes strict only after a current-version live fixture exposes:

1. primary resolved model,
2. primary resolved effort,
3. child runtime ID,
4. child resolved model,
5. child resolved effort,
6. a blocking or accepted-result rejection path.

No source-only or configured-value test satisfies this gate.

- [ ] **Step 4: Run checks and commit**

```sh
jq empty plugins/sol-advisor/.cursor-plugin/plugin.json
jq empty plugins/sol-advisor/.claude-plugin/plugin.json
sh plugins/sol-advisor/scripts/verify-host-adapters.sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git add .cursor-plugin .claude-plugin plugins/sol-advisor
git commit -m "feat: add truthful Cursor and Claude compatibility"
```

---

### Task 6: Replace the Codex-Only ODW Wrapper with Generic Policy Acceptance

**Files:**

- Modify: `plugins/sol-advisor/scripts/inspect-odw-run.sh`
- Modify: `plugins/sol-advisor/skills/orchestration/references/odw.md`
- Modify: `plugins/sol-advisor/skills/orchestration/SKILL.md`
- Modify: `plugins/sol-advisor/skills/advisor/SKILL.md`
- Modify: `plugins/sol-advisor/scripts/verify.sh`
- Modify: `plugins/sol-advisor/scripts/verify-host-adapters.sh`

**Inspector interface:**

```text
inspect-odw-run.sh --host codex|zcode RUN_DIRECTORY
```

- [ ] **Step 1: Add failing ODW 0.3.x fixtures**

Create two-node fixtures for Codex and ZCode. Assert:

- normalized run policy contains the exact expected strict-host executor and grunt tuple selected when the run began,
- recomputed SHA-256 fingerprint equals run and every trace,
- every model trace has one distinct runtime ID,
- the matching host inspector proves the actual tuple,
- deterministic nodes need no model attestation,
- wrong/missing/duplicate fingerprint, runtime ID, model, effort, executor, or host evidence rejects the run,
- cached/resumed/failed/cancelled/skipped/partial/mixed-executor nodes reject,
- stale evidence outside the selected run rejects,
- Cursor, Claude, and Grok host values reject before an Advisor workflow launches.

- [ ] **Step 2: Generalize the inspector**

Keep the existing canonical-path/symlink/malformed-artifact defenses. Write the already-validated canonical three-field run policy to a mode-`600` `mktemp` file, register cleanup with `trap`, and dispatch in `--mode odw` only to:

- `inspect-codex-runtime.sh`,
- `inspect-zcode-runtime.sh`.

Pass the matching executor result artifact and runtime ID from each trace. Codex ODW evidence must be standalone/no-native-parent; ZCode ODW evidence must be `route=odw,role=main,parentSessionId=null`. Never call either host's native-grunt inspection path for an ODW node.

Recompute the policy fingerprint locally using:

```sh
printf '%s' "$canonical_policy" | shasum -a 256
```

The canonical policy uses fixed key order. Do not trust a recorded fingerprint without recomputation.

- [ ] **Step 3: Update the authoring contract**

The Advisor skill loads the active strict host's grunt tuple once and supplies:

```js
routingPolicy: {
  executor: "<active strict host>",
  model: "<configured grunt model>",
  reasoningEffort: "<configured grunt effort>"
}
```

Node `agent()` calls omit route fields unless the same values are useful for readability. Conflicts are forbidden. The primary runs the inspector before using any result and owns final review.

The persisted ODW policy, not mutable current configuration, is the expected tuple during result acceptance. Require the exact merged ODW plugin compatible version; a missing/older/newer unverified version disables only the ODW lane.

- [ ] **Step 4: Run checks and commit**

```sh
sh -n plugins/sol-advisor/scripts/inspect-odw-run.sh
sh plugins/sol-advisor/scripts/verify-host-adapters.sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git add plugins/sol-advisor/scripts plugins/sol-advisor/skills
git commit -m "feat: enforce Advisor policy on ODW runs"
```

---

### Task 7: Rename the Product Surface and Publish Host Catalogs

**Files:**

- Modify: `README.md`
- Modify: `plugins/sol-advisor/.codex-plugin/plugin.json`
- Modify: `.agents/plugins/marketplace.json`
- Modify: every new host manifest/catalog
- Modify: `plugins/sol-advisor/skills/orchestration/SKILL.md`
- Modify: `plugins/sol-advisor/skills/orchestration/agents/openai.yaml`
- Modify: `plugins/sol-advisor/skills/orchestration/references/role-contracts.md`
- Modify: `plugins/sol-advisor/skills/orchestration/references/operations.md`
- Modify: `plugins/sol-advisor/skills/orchestration/references/odw.md`
- Test: `plugins/sol-advisor/scripts/verify.sh`

- [ ] **Step 1: Add failing package consistency checks**

Verify:

- package IDs remain `sol-advisor`,
- every display name is `Advisor`,
- every manifest version is `0.9.0` unless a newer release already exists,
- Codex default tuple appears exactly once as a default, not a universal model rule,
- Terra has no active role, route, prose, or manifest reference except migration tests/digests,
- Grok Bot is explicitly excluded,
- support matrix labels match doctor output,
- ODW compatibility matches the merged candidate manifest version and exact merged SHA before release, then the published artifact's version/SHA after release,
- all catalog source paths resolve inside the repository.

- [ ] **Step 2: Rewrite the user flow**

README quick start:

1. install Advisor for the chosen host,
2. invoke the installed Advisor skill (`$advisor` in Codex; the documented host-equivalent syntax elsewhere),
3. configure the exact tuple and apply the generated Codex role (the Codex default may be accepted),
4. review/trust host hooks,
5. run `$advisor doctor --host HOST` (or the documented equivalent skill syntax),
6. start a fresh session,
7. vibe code normally.

Write Step 5 using the host's Advisor skill invocation, not a bare PATH command. Explain that ordinary work stays primary, bounded delegation uses the grunt automatically when beneficial, ODW is selected only for scale/repeatability, and the primary always performs final review.

- [ ] **Step 3: Update role and operations contracts**

Use only `advisor` and `grunt` vocabulary. Packets still require objective, ownership, interfaces, constraints, verification, and structured return. Remove hard-coded Luna language from the generic contract while keeping the Codex default example.

- [ ] **Step 4: Bump and validate all manifests**

Set the generalized release to `0.9.0` across owned host manifests/catalog entries. Do not rename the repository, GitHub slug, source directory, or plugin coordinate.

- [ ] **Step 5: Run full source verification**

```sh
sh plugins/sol-advisor/scripts/verify-config.sh
sh plugins/sol-advisor/scripts/verify-host-adapters.sh
sh plugins/sol-advisor/scripts/verify.sh
find . -name '*.json' -not -path './.git/*' -exec jq empty {} \;
git diff --check
```

- [ ] **Step 6: Commit**

```sh
git add README.md .agents .cursor-plugin .claude-plugin .grok-plugin marketplace.json plugins/sol-advisor
git commit -m "feat: generalize Sol Advisor across coding hosts"
```

---

### Task 8: Review, PR, Merge, and Fresh-Origin Verification

- [ ] **Step 1: Perform a primary-task code review**

Inspect every changed file and run intentional denial probes for:

- wrong Codex primary effort,
- wrong Codex grunt model,
- failed, timed-out, and cancelled Codex child results,
- changed Codex profile during a running session followed by a new-session comparison,
- incomplete or invalid ZCode plugin settings,
- wrong ZCode runtime attestation,
- wrong ZCode role/parent with identical advisor/grunt tuples,
- changed ZCode settings during a running session followed by a new-session comparison,
- inactive/crashing/timed-out/malformed strict-host hooks,
- Grok strict-delegation request on the fail-open host,
- ODW node model conflict,
- Cursor strict-delegation request,
- Claude strict-delegation request.

Each probe uses the exact prohibited call/input and stops after denial/rejection.

- [ ] **Step 2: Run the full suite from a clean worktree**

```sh
sh plugins/sol-advisor/scripts/verify-config.sh
sh plugins/sol-advisor/scripts/verify-host-adapters.sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git status --short
```

Expected: checks pass and status contains only intentional plan/source changes before commit, then is clean after commit.

Install the staged plugin through a disposable marketplace and invoke the packaged Advisor skill once. Verify that no shell `PATH` mutation is needed and that `remove` cleans only Advisor-owned files before uninstall.

- [ ] **Step 3: Open the PR**

```sh
git push -u origin codex/advisor-cross-host-routing
gh pr create --repo atebites-hub/sol-advisor --base main --head codex/advisor-cross-host-routing --title "feat: generalize Advisor routing across coding hosts" --body-file PR_BODY.md
```

The PR body must list dependency versions/SHAs, strict/experimental/excluded matrix, migration behavior, source test evidence, and outstanding live-host gates.

- [ ] **Step 4: Wait for checks/review and merge**

Resolve review feedback with focused tests, rerun the full suite, and merge without force-pushing shared/default branches.

- [ ] **Step 5: Reverify merged origin**

Create a fresh worktree from the resulting `origin/main` and rerun Step 2. Then proceed to the umbrella plan's clean-install/live acceptance. Do not call the plugin complete before those live proofs pass.
