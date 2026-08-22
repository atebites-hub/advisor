# Advisor ZCode Runtime Attestation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the maintained ZCode fork current with upstream while preserving its ODW protocol, then add exact model/effort routing and runtime-generated evidence for both native hooks and ODW headless runs.

**Architecture:** Keep ZCode's existing `main` and `lite` roles as the native advisor/grunt selection surface. Extend that existing model configuration with exact thought-level values, make launcher flags create a private per-process settings copy, and patch the vendored runtime at the same model/effort state used by the TUI. The runtime—not the launcher arguments—emits one normalized attestation into hook payloads and the existing ODW footer.

**Tech Stack:** TypeScript, Bun, Node.js standard library, ZCode launcher, vendored-runtime patcher, JSON configuration, ZCode hooks, existing ODW protocol.

## Required Contract

Public headless flags:

```text
--model <provider/model>
--reasoning-effort <runtime-exact-thought-level>
```

Generic ZCode configuration keys:

```json
{
  "model": {
    "main": "provider/advisor-model",
    "lite": "provider/grunt-model",
    "mainThoughtLevel": "advisor-effort",
    "liteThoughtLevel": "grunt-effort"
  }
}
```

Runtime evidence:

```ts
export interface ZcodeRuntimeAttestation {
  type: "zcode_runtime_attestation";
  schemaVersion: 1;
  executor: "zcode";
  route: "native" | "odw";
  runtimeId: string;
  runtimeVersion: string;
  sessionId: string;
  role: "main" | "lite";
  parentSessionId: string | null;
  policySource: "new" | "persisted" | "parent" | null;
  rolePolicy: {
    advisorModel: string;
    advisorEffort: string;
    gruntModel: string;
    gruntEffort: string;
  } | null;
  rolePolicyFingerprint: string | null;
  model: string;
  reasoningEffort: string;
}
```

Rules:

- `model` and `reasoningEffort` come from the resolved live runtime/session state after model selection, never from requested flags.
- `role` and `parentSessionId` come from runtime-owned primary/subagent lifecycle state. A primary is `main` with `parentSessionId:null`; a native child is `lite` with its authoritative parent ID. Role is never inferred from model because both roles may use the same tuple.
- `rolePolicy` is the immutable persisted four-field snapshot for an Advisor native session and is inherited unchanged by its children. `policySource` is `new` only for the first start of a new root, `persisted` for a restored root, and `parent` for a child. Both fields are `null` for ordinary and ODW headless sessions.
- `rolePolicyFingerprint` is lowercase SHA-256 of `rolePolicy`. Every native consumer recomputes it and compares the attested model/effort to the tuple selected by `role`; the fingerprint is correlation, not a substitute for the policy preimage. It is `null` when `rolePolicy` is `null`.
- Native `SessionStart` and model/tool hook payloads contain `runtimeAttestation` so Advisor-owned hooks can verify primary and children.
- `ZCODE_ODW_PROTOCOL=1` emits exactly one attestation footer and folds it into `zcode_result.runtimeAttestation`.
- Missing, duplicate, malformed, empty, or requested/observed-mismatched attestation makes a strict call fail.
- No prompt command such as `/effort` is injected.
- Existing user config is never mutated for a one-process override.
- When the enabled `sol-advisor` plugin supplies a complete `userConfig`, a new native session snapshots both tuples in runtime-owned session state. Running/resumed sessions and their children keep that snapshot when plugin settings change.

Hash this exact compact object with Node's standard `createHash("sha256")`:

```json
{"advisorModel":"...","advisorEffort":"...","gruntModel":"...","gruntEffort":"..."}
```

---

### Task 1: Rebase the Fork Behavior onto Current Upstream

**Files:**

- Modify: `src/launcher.ts`
- Modify: `scripts/sync-runtime.ts`
- Modify: `test/launcher.test.ts`
- Modify: `test/sync-runtime.test.ts`
- Modify as required by upstream release: `package.json`, `bun.lock`, `vendor/extraction.json`, `vendor/zcode.cjs`

- [ ] **Step 1: Create an isolated branch from current upstream**

Use the worktree skill to create branch `codex/advisor-routing` from fetched `kingsword09/main`. Record:

```sh
git rev-parse kingsword09/main
git log --reverse --format='%H %s' kingsword09/main..origin/main
git diff --name-status kingsword09/main..origin/main
```

Expected: the maintained fork changes are attributable and the four fork-owned source/test files are identified before rebasing.

- [ ] **Step 2: Run upstream's clean baseline**

```sh
bun install --frozen-lockfile
bun run sync:locked
bun test
bun run typecheck
bun run build
bun run check
git diff --check
```

Expected: upstream is green. If a current upstream command name differs, use the script present in its fetched `package.json` and record that exact change in the PR; do not skip the underlying test/typecheck/build check.

`vendor/` is intentionally ignored and must be synchronized before runtime-backed tests. An exact-version local App may be used through `sync:local` for an early macOS check, but CI and fresh-origin acceptance use the committed lock through `sync:locked` or `release:build`.

- [ ] **Step 3: Reapply the fork's existing behavior commit-by-commit**

Preserve:

- `ZCODE_ODW_PROTOCOL` structured execution,
- `prepareModelOverride()` temporary config-home isolation,
- `patchRuntimeUsageFooter()` telemetry,
- protocol signal forwarding and stdio behavior,
- the fork's current runtime hardening patches.

Also retain upstream's first-run/model-access behavior, current patch order/anchors, HTTP no-content handling, goal-failure pause, and context-cache changes.

Do not use file-level `--ours` or `--theirs`. After resolving each source conflict, run:

```sh
bun test test/launcher.test.ts test/sync-runtime.test.ts
bun run typecheck
```

- [ ] **Step 4: Commit the green upstream merge**

```sh
git add src/launcher.ts scripts/sync-runtime.ts test/launcher.test.ts test/sync-runtime.test.ts package.json bun.lock
git commit -m "chore: merge current ZCode upstream"
```

The exact staged file set may omit upstream-unchanged files, but must not include unrelated generated or user files.

---

### Task 2: Add Exact Model and Effort Overrides

**Files:**

- Modify: `src/launcher.ts`
- Test: `test/launcher.test.ts`
- Test: `test/launcher-runtime.test.ts`

**Internal interface:**

```ts
type RuntimeRoute = {
  model: string;
  reasoningEffort: string;
  route: "native" | "odw";
};

type RuntimeOverrides = {
  args: string[];
  env: NodeJS.ProcessEnv;
  cleanup: () => Promise<void>;
  requestedRoute?: RuntimeRoute;
};

export async function prepareRuntimeOverrides(
  args: string[],
  env?: NodeJS.ProcessEnv,
): Promise<RuntimeOverrides>;
```

- [ ] **Step 1: Write failing launcher tests**

Add tests that prove:

1. `--model` and `--reasoning-effort` each accept split and `--name=value` forms.
2. Duplicate flags, missing values, whitespace-only values, and unsafe effort tokens fail before spawn.
3. A complete override writes `model.main` and `model.mainThoughtLevel` to a mode-`600` temporary config.
4. The original settings file's byte hash is unchanged.
5. Both flags and the caller's `--settings` are removed from runtime argv.
6. Cleanup removes the private temp directory on success, spawn error, stream error, signal, and nonzero runtime exit.
7. `ZCODE_ODW_PROTOCOL=1` sets route `odw`; normal invocation sets `native`.
8. A partial strict route (model without effort or effort without model) fails.
9. Reading Advisor plugin settings never rewrites the user's config or provider credentials.
10. The current bundled runtime's plugin install/list smoke path remains green.

Run:

```sh
bun test test/launcher.test.ts test/launcher-runtime.test.ts
```

Expected: new tests fail because effort parsing and `prepareRuntimeOverrides()` do not exist.

- [ ] **Step 2: Implement the minimal override**

Reuse `parseOption()`, `userConfigPath()`, `mkdtemp()`, and the current cleanup pattern. Validate:

```ts
const modelPattern = /^[A-Za-z0-9][A-Za-z0-9._:+/-]{0,255}$/u;
const effortPattern = /^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/u;
```

Set only:

```ts
modelConfig.main = model;
modelConfig.mainThoughtLevel = reasoningEffort;
```

Keep `prepareModelOverride()` as a compatibility wrapper that calls `prepareRuntimeOverrides()` and returns the existing shape. Do not add a routing class, registry, or dependency.

- [ ] **Step 3: Run focused checks and commit**

```sh
bun test test/launcher.test.ts test/launcher-runtime.test.ts
bun run typecheck
git diff --check
git add src/launcher.ts test/launcher.test.ts test/launcher-runtime.test.ts
git commit -m "feat: add exact runtime route overrides"
```

---

### Task 3: Apply Thought Level Through the Runtime's Native State

**Files:**

- Modify: `scripts/sync-runtime.ts`
- Modify: `scripts/check-runtime.ts`
- Modify: `config.example.json`
- Modify: `docs/CONFIGURATION.md`
- Test: `test/sync-runtime.test.ts`
- Test: `test/launcher-runtime.test.ts`
- Generate locally for verification (ignored): `vendor/zcode.cjs`

- [ ] **Step 1: Add failing runtime-patch fixtures**

Use the existing minified fixtures around `thoughtLevel` and the `/effort` picker. Add tests named:

- `runtime route patch reads mainThoughtLevel for a primary session`
- `runtime route patch reads liteThoughtLevel for a subagent`
- `runtime route patch applies the requested headless effort`
- `new Advisor session snapshots main and lite tuples from plugin settings`
- `running Advisor session ignores later plugin setting changes`
- `restored Advisor session reloads its persisted route snapshot`
- `native Agent child inherits the parent's persisted lite tuple`
- `background resumed Agent child inherits the same lite tuple`
- `runtime route patch rejects an unsupported thought level before provider invocation`
- `runtime route patch is idempotent`
- `runtime route patch rejects incompatible anchors`

Assertions must observe the runtime model reference's final `thoughtLevel`, not only an environment or config string.

Run:

```sh
bun test test/sync-runtime.test.ts
```

Expected: the new tests fail.

- [ ] **Step 2: Add one strict runtime patch**

Add:

```ts
export function patchRuntimeRouteSelection(runtimeSource: string): string;
```

Patch the same state transition currently used by the TUI `/effort` action:

- new Advisor primary session: enabled plugin `advisor_model` + `advisor_effort`, persisted as role `main`,
- its native subagent/lightweight sessions: the parent snapshot's `grunt_model` + `grunt_effort`, persisted as role `lite`,
- ordinary non-Advisor sessions: existing `model.main`/`mainThoughtLevel` and `model.lite`/`liteThoughtLevel` behavior remains unchanged,
- launcher headless override: the temporary `main` pair,
- restored session: its recorded resolved pair; conflicting new config does not rewrite history.

Reuse the existing runtime persistence path that writes `saveSessionEntry()` ID `<sessionId>:runtime-model-selection` with provider/model and `thoughtLevel`, plus the existing restore path that reads that entry before `setModel()`/`setThoughtLevel()`. Extend that record minimally with the Advisor four-field main/lite snapshot and role. Emit `policySource=new` only on the creation path that first writes this record, `persisted` on the restore path, and `parent` when the Agent lifecycle copies the parent snapshot. Use the existing Agent lifecycle's `childSessionId`, `parentSessionId`, `agentId`, and `agentType` fields; do not create a second session store.

Add one save → change plugin settings → restore round trip against the real session-store fixture, plus one foreground and one background/resumed native Agent integration fixture. These must observe the child's final runtime model reference and `thoughtLevel`, not only patch strings.

Use strict unique anchors and a marker comment/string checked by `scripts/check-runtime.ts`. If the selected model's catalog does not expose the requested thought level, stop before a provider request with a stable error code/message.

Only after the runtime recognizes both keys, add `mainThoughtLevel` and `liteThoughtLevel` to `config.example.json` beside `main` and `lite`. In `docs/CONFIGURATION.md` document:

- `main`/`mainThoughtLevel` are the primary role,
- `lite`/`liteThoughtLevel` are native subagent/lightweight work,
- exact values must be supported by the selected model,
- restored sessions retain their recorded tuple and require `/new` after configuration changes,
- the enabled Advisor plugin's exact settings are an optional native role overlay for new sessions only; malformed, incomplete, disabled, or ambiguous plugin records do not alter ordinary ZCode behavior.

- [ ] **Step 3: Regenerate and verify the vendored runtime**

Run only in this isolated worktree:

```sh
bun run sync:locked
bun test test/sync-runtime.test.ts test/launcher-runtime.test.ts
bun run check
git diff --check
```

- [ ] **Step 4: Commit**

```sh
git add scripts/sync-runtime.ts scripts/check-runtime.ts test/sync-runtime.test.ts test/launcher-runtime.test.ts config.example.json docs/CONFIGURATION.md
git commit -m "feat: apply exact runtime reasoning effort"
```

---

### Task 4: Emit Runtime-Generated Attestation

**Files:**

- Modify: `src/launcher.ts`
- Modify: `scripts/sync-runtime.ts`
- Modify: `scripts/check-runtime.ts`
- Test: `test/launcher.test.ts`
- Test: `test/sync-runtime.test.ts`
- Generate locally for verification (ignored): `vendor/zcode.cjs`

- [ ] **Step 1: Add failing attestation tests**

In `test/sync-runtime.test.ts` prove the patched runtime creates the attestation from:

- runtime distribution/version metadata,
- actual session ID,
- actual resolved provider/model reference,
- actual final `thoughtLevel`,
- actual native versus ODW route.

Prove the attestation is present on native `SessionStart`, `PreToolUse`, `PostToolUse`, and child-session hook payloads. Prove ODW writes exactly one trailing JSON footer even on a handled provider failure.

For native events, prove a primary emits `role=main,parentSessionId=null` and every Agent child emits `role=lite` with the actual parent session ID. Repeat with identical advisor/grunt tuples to prove the role fields remain authoritative.
Prove every Advisor-native event carries the complete immutable `rolePolicy`, a recomputable matching fingerprint, and the correct `policySource`. The selected policy tuple must equal the attested model/effort. Add one combined fixture: start policy A, change settings to B, restore the A root, spawn its A child, then create a new B root. Reject wrong/missing policy fields, fingerprints, sources, or selected tuples. ODW events require `policySource:null`, `rolePolicy:null`, and `rolePolicyFingerprint:null`.

In `test/launcher.test.ts` prove `extractRuntimeAttestation()`:

- accepts exactly one valid footer,
- strips it from displayed stderr,
- rejects missing, duplicate, malformed, wrong schema, empty fields, wrong executor, and requested/observed mismatch,
- preserves unrelated stderr without printing it as evidence,
- places the valid object at `zcode_result.runtimeAttestation`.

Run:

```sh
bun test test/launcher.test.ts test/sync-runtime.test.ts
```

Expected: new tests fail.

- [ ] **Step 2: Patch the native hook payload builder**

Add:

```ts
export function patchRuntimeAttestation(runtimeSource: string): string;
```

At the central hook-event construction point, add one `runtimeAttestation` object generated from resolved runtime state. Reuse the same helper for primary and child sessions, including foreground, background, resumed, and restarted Agent paths. Include the persisted four-field policy preimage and its source on every Advisor-native event so consumers can recompute the fingerprint and select the expected tuple without consulting mutable settings. Do not write a separate Advisor database or sidecar for native execution.

The native attestation route is `native`. Its `runtimeId` is the runtime instance/trace identifier already owned by the runtime; if the current upstream exposes only one stable session identifier, use that value for both `runtimeId` and `sessionId` and document the equality. Never generate a random ID in the launcher.

- [ ] **Step 3: Extend the ODW footer and launcher parser**

The patched runtime emits:

```json
{"type":"zcode_runtime_attestation","schemaVersion":1,"executor":"zcode","route":"odw","runtimeId":"...","runtimeVersion":"...","sessionId":"...","role":"main","parentSessionId":null,"policySource":null,"rolePolicy":null,"rolePolicyFingerprint":null,"model":"provider/model","reasoningEffort":"high"}
```

Extend `ODWResultEnvelope` with:

```ts
runtimeAttestation: ZcodeRuntimeAttestation;
```

Unlike optional usage telemetry, strict route attestation is required whenever both route flags were supplied. A missing or mismatched attestation returns nonzero and no successful `zcode_result` envelope.

- [ ] **Step 4: Regenerate, run focused checks, and commit**

```sh
bun run sync:locked
bun test test/launcher.test.ts test/sync-runtime.test.ts
bun run typecheck
bun run check
git diff --check
git add src/launcher.ts scripts/sync-runtime.ts scripts/check-runtime.ts test/launcher.test.ts test/sync-runtime.test.ts
git commit -m "feat: attest resolved ZCode runtime routes"
```

---

### Task 5: Preserve Hook Defaults and Document Strict Consumers

**Files:**

- Modify: `docs/CONFIGURATION.md`
- Modify: `README.md`
- Test: `test/launcher.test.ts` or the repository's config tests

- [ ] **Step 1: Add a preservation test**

Prove ZCode's shipped default remains:

```json
{"hooks":{"enabled":false}}
```

and that reading/using the new model keys does not enable hooks or overwrite unrelated handlers.

Also prove an enabled plugin's own contributed hooks are discovered and executed independently of that user-level default. Inject missing-script, crash, timeout, and malformed-output failures. If the current plugin hook lifecycle does not stop or mark the strict session unsupported for every failure, do not advertise ZCode as strict and do not change the global default to compensate.

- [ ] **Step 2: Document the contract**

Document that a strict consumer such as Advisor must:

1. obtain explicit user approval before installing/enabling the plugin,
2. contribute only its plugin-owned named handlers and leave global user hooks unchanged,
3. preserve unrelated config,
4. refuse handler/path collisions,
5. start a new session,
6. verify the hook lifecycle before declaring strict support,
7. verify the runtime attestation on every accepted primary/child execution.

- [ ] **Step 3: Run the complete repository suite**

```sh
bun test
bun run typecheck
bun run build
bun run check
git diff --check
```

- [ ] **Step 4: Commit**

```sh
git add README.md docs/CONFIGURATION.md test
git commit -m "docs: define strict ZCode routing consumers"
```

---

### Task 6: PR, Merge, and Fresh-Origin Verification

- [ ] **Step 1: Prepare the PR body**

Include:

- exact `kingsword09/main` base SHA,
- fork commits/behaviors preserved,
- final head SHA,
- config and flag contract,
- sample allowlisted attestation,
- intentional mismatch failure,
- every test command/result,
- no claim that the GitHub fork badge was restored.

- [ ] **Step 2: Open the PR**

```sh
git push -u origin codex/advisor-routing
gh pr create --repo atebites-hub/zcode-cli --base main --head codex/advisor-routing --title "feat: add attestable Advisor routing" --body-file PR_BODY.md
```

- [ ] **Step 3: Wait for checks and merge**

Use `gh pr checks --watch`, inspect any review threads, rerun affected tests after fixes, then merge without force-push.

- [ ] **Step 4: Verify the merged origin**

From a fresh worktree at the resulting `origin/main`:

```sh
bun install --frozen-lockfile
bun run sync:locked
bun test test/launcher.test.ts test/sync-runtime.test.ts
bun run typecheck
bun run build
bun run check
git diff --check
```

Record the merged SHA for the ODW plugin submodule pin.
