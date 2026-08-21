# Advisor ODW Routing Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one optional immutable run-level executor/model/effort policy to Open Dynamic Workflows so every model node in a governed run receives the same route, conflicts fail before launch, nested workflows inherit it, and traces carry stable correlation evidence.

**Architecture:** Normalize and freeze the policy once at `runWorkflow()` entry, hash a fixed-key JSON encoding with Node's standard crypto library, and pass the resulting object/fingerprint through the existing run context. Resolve each model node against that policy before cache lookup or executor invocation. Preserve existing behavior and trace shape when no policy is supplied.

**Tech Stack:** TypeScript, Node.js standard library, ODW runtime/executor interfaces, JSONL events and traces, existing `tsx --test` smoke suite.

## Prerequisite

This plan starts only after `origin/feat/zcode-executor` has been promoted and merged into `origin/main` as described in `2026-08-21-advisor-cross-host-routing.md`. Create `codex/advisor-routing-policy` from the resulting current `origin/main`, not from the historical feature or hardening branches.

## Public Contract

```ts
export interface RoutingPolicy {
  readonly executor: string;
  readonly model: string;
  readonly reasoningEffort: string;
}
```

`RunOptions` gains:

```ts
routingPolicy?: RoutingPolicy;
```

`AgentOptions.executor` becomes optional so `agent(prompt)` can inherit either the run policy or the existing run default. A model node still fails before launch when neither source supplies an executor.

`RunContext` carries:

```ts
routingPolicy?: Readonly<RoutingPolicy>;
routingPolicyFingerprint?: string;
```

Policy trace evidence:

```ts
routing?: {
  policyFingerprint: string;
  executor: string;
  model: string;
  reasoningEffort: string;
  runtimeId: string | null;
};
```

The fingerprint is lowercase SHA-256 hex of:

```json
{"executor":"...","model":"...","reasoningEffort":"..."}
```

It is correlation evidence, not a signature and not proof that a host honored requested values. Advisor joins it to host runtime attestation before accepting results.

---

### Task 1: Add Policy Normalization and Fingerprinting

**Files:**

- Create: `src/runtime/routing.ts`
- Create: `src/runtime/routing.test.ts`
- Modify: `src/types.ts`

- [ ] **Step 1: Write failing unit tests**

Add tests named:

- `routing policy normalizes fixed keys and freezes the result`
- `routing policy fingerprint is deterministic across input key order`
- `routing policy fingerprints different executor model or effort values differently`
- `routing policy rejects non-object input`
- `routing policy rejects unknown fields`
- `routing policy rejects empty or whitespace-only fields`
- `routing policy rejects an unregistered executor`

Run:

```sh
npx tsx --test src/runtime/routing.test.ts
```

Expected: test loading fails because `routing.ts` and the types do not exist.

- [ ] **Step 2: Add the minimal types and helpers**

Implement:

```ts
export function normalizeRoutingPolicy(
  policy: unknown,
  executors: Record<string, Executor>,
): Readonly<RoutingPolicy>;

export function fingerprintRoutingPolicy(
  policy: Readonly<RoutingPolicy>,
): string;

export function resolveAgentRoute(
  policy: Readonly<RoutingPolicy> | undefined,
  options: Partial<Pick<AgentOptions, "executor" | "model" | "reasoningEffort">>,
): Readonly<RoutingPolicy> | Partial<Pick<AgentOptions, "executor" | "model" | "reasoningEffort">>;
```

Implementation constraints:

- Require an object with exactly `executor`, `model`, and `reasoningEffort`.
- Trim values once; do not lowercase or translate them.
- Validate executor membership against the existing executor registry.
- Normalize to fixed insertion order and `Object.freeze()` the object.
- Hash `JSON.stringify(normalized)` using `createHash("sha256")`.
- When a policy exists, each omitted node field is filled, each equal field is accepted, and each unequal field throws a field-specific conflict.
- Do not create a schema library or generic policy engine.
- Add a compile/runtime public-API test showing `agent(prompt)` is valid under a policy and still requires a policy or existing default executor at runtime.

- [ ] **Step 3: Run focused checks**

```sh
npx tsx --test src/runtime/routing.test.ts
npm run typecheck
git diff --check
```

- [ ] **Step 4: Commit**

```sh
git add src/types.ts src/runtime/routing.ts src/runtime/routing.test.ts
git commit -m "feat: define immutable ODW routing policy"
```

---

### Task 2: Bind One Policy to the Entire Run

**Files:**

- Modify: `src/runtime/run.ts`
- Modify: `src/types.ts`
- Test: `src/smoke.test.ts`

- [ ] **Step 1: Add failing run-lifecycle tests**

Use fake executors with invocation counters. Add tests named:

- `routing policy validates before workflow execution`
- `run_start records normalized routing policy and fingerprint`
- `workflow result records normalized routing policy and fingerprint`
- `nested workflow inherits parent routing policy`
- `nested workflow rejects a conflicting agent route before launch`
- `run without policy preserves current lifecycle fields`

The invalid-policy test must assert workflow code and executor count both remain zero.
It must also assert no `.odw` run directory or journal was created.

Run:

```sh
npx tsx --test src/smoke.test.ts
```

Expected: new assertions fail.

- [ ] **Step 2: Normalize once at `runWorkflow()` entry**

Before journal creation or workflow execution, move the existing executor-registry extraction/nonempty validation ahead of `openJournal()`, reject `routingPolicy` plus `resumeFromRunId`, then normalize:

```ts
const routingPolicy = options.routingPolicy !== undefined
  ? normalizeRoutingPolicy(options.routingPolicy, executors)
  : undefined;
const routingPolicyFingerprint = routingPolicy
  ? fingerprintRoutingPolicy(routingPolicy)
  : undefined;
```

Store the same frozen object and fingerprint on every `RunContext`. Pass them unchanged through `runInternal(..., depth + 1)`.

The existing nested `workflow(ref, args)` API does not accept a second policy. Its child context inherits the parent's frozen policy, and any conflicting route declared by an agent inside the nested workflow fails before executor launch.

Add optional policy/fingerprint fields to the `run_start` event and `WorkflowResult`. Omit them entirely for unpolicy runs.

- [ ] **Step 3: Run focused checks and commit**

```sh
npx tsx --test src/smoke.test.ts
npm run typecheck
git diff --check
git add src/runtime/run.ts src/types.ts src/smoke.test.ts
git commit -m "feat: bind routing policy to ODW runs"
```

---

### Task 3: Resolve Model Nodes Before Cache or Launch

**Files:**

- Modify: `src/runtime/hooks.ts`
- Modify: `src/types.ts`
- Test: `src/smoke.test.ts`

- [ ] **Step 1: Add failing route-resolution tests**

Add tests named:

- `policy fills omitted node executor model and effort`
- `matching node route values are accepted`
- `conflicting executor is rejected before cache and launch`
- `conflicting model is rejected before cache and launch`
- `conflicting reasoning effort is rejected before cache and launch`
- `deterministic non-model steps do not require route fields`
- `unpolicy node keeps per-node routing behavior`
- `policy resolves omitted node fields before differing host executor and model defaults`

For every conflict, assert:

- executor invocation count is zero,
- no `agent_start` event is written,
- no cached result is returned.

- [ ] **Step 2: Resolve at the top of `agent()`**

Call `resolveAgentRoute()` on the raw node options before host/run defaults are injected and before:

1. cache lookup,
2. semaphore acquisition,
3. `agent_start`,
4. executor registry lookup,
5. retry loop.

Use the resolved executor for registry lookup and pass resolved `model` and `reasoningEffort` to the existing executor `prepare/exec` path.

When policy exists, skip `ctx.defaultExecutor` and `ctx.defaultModel`; the policy supplies omitted route fields. Explicit raw node fields must equal the policy. When policy is absent, preserve the existing default injection and per-node behavior byte-for-byte.

Keep retries, schema parsing, isolation, labels, phases, and agent types unchanged.

- [ ] **Step 3: Reject policy cache and resume**

At `runWorkflow()` entry reject `routingPolicy` combined with `resumeFromRunId` using a stable error before journal creation. The current cache is reachable only through resume, so this entry guard is the complete first-release cache rule; do not add an unreachable second cache branch inside `agent()`.

This release does not add cache-lineage metadata or migration logic.

- [ ] **Step 4: Run focused checks and commit**

```sh
npx tsx --test src/runtime/routing.test.ts
npx tsx --test src/smoke.test.ts
npm run typecheck
git diff --check
git add src/runtime/hooks.ts src/runtime/run.ts src/types.ts src/smoke.test.ts
git commit -m "feat: enforce ODW routes before model launch"
```

---

### Task 4: Persist Route Correlation in Executor Traces

**Files:**

- Modify: `src/executor/subprocess.ts`
- Modify: `src/types.ts`
- Test: `src/executor/subprocess.test.ts`

- [ ] **Step 1: Add failing trace tests**

Add tests named:

- `policy subprocess trace records effective route fingerprint and runtime id`
- `policy subprocess trace records null runtime id when executor returns none`
- `unpolicy subprocess trace omits routing block`
- `failed policy subprocess still records requested route and observed runtime id when available`

Use the existing `node -e` subprocess fixture. Assert the route object values and ensure prompt/output content is not copied into the routing object.

- [ ] **Step 2: Thread route metadata through `ExecOptions`**

Ensure `ExecOptions` contains optional:

```ts
routingPolicyFingerprint?: string;
effectiveRoute?: Readonly<RoutingPolicy>;
```

After `spec.reduce()`, write `core.sessionId ?? null` as `routing.runtimeId`. Emit `routing` only when both optional fields are present. Keep the preexisting trace format byte-compatible for unpolicy runs.

- [ ] **Step 3: Run focused checks and commit**

```sh
npx tsx --test src/executor/subprocess.test.ts
npm run typecheck
git diff --check
git add src/executor/subprocess.ts src/executor/subprocess.test.ts src/types.ts
git commit -m "feat: trace effective ODW routing"
```

---

### Task 5: Pass Explicit Effort Through Built-In Executors

**Files:**

- Modify: `src/executor/codex/codex.ts`
- Create or modify: `src/executor/codex/codex.test.ts`
- Modify: `src/executor/zcode/zcode.ts`
- Modify: `src/executor/zcode/zcode-envelope.ts`
- Create or modify: `src/executor/zcode/zcode.test.ts`
- Create or modify: `src/executor/zcode/zcode-envelope.test.ts`
- Modify only where already supported: Cursor, Claude, Grok, and ZCode executor argument builders
- Test: each touched executor's existing focused test

- [ ] **Step 1: Add failing argument-builder tests**

For Codex, assert:

```ts
["-c", 'model_reasoning_effort="high"']
```

is present when `reasoningEffort: "high"` is supplied and absent when omitted.

For ZCode, assert:

```ts
["--reasoning-effort", "high"]
```

is present alongside `--model`.

For a policy-governed ZCode run, assert the parser accepts exactly one valid `zcode_result.runtimeAttestation` whose observed model/effort match the effective route and whose runtime ID matches the executor outcome. Missing, duplicate, malformed, fallback, mismatched, or role/parent-invalid attestations must fail the run. Preserve current envelope behavior when no routing policy is active.

For each other built-in executor, add a test only when that host's current CLI exposes an exact effort flag/config. If it does not, preserve the field in trace metadata but mark the executor as not runtime-attestable in the downstream plugin; do not fake an effort argument.

- [ ] **Step 2: Implement native argument mapping**

Codex:

```ts
if (opts.reasoningEffort) {
  args.push("-c", "model_reasoning_effort=" + JSON.stringify(opts.reasoningEffort));
}
```

ZCode:

```ts
if (opts.reasoningEffort) {
  args.push("--reasoning-effort", opts.reasoningEffort);
}
```

Reuse the existing ZCode envelope parser. Extend its parsed outcome just enough to retain the runtime-generated attestation; do not add a generic attestation framework. Validate the policy run's requested-versus-observed route before reporting executor success. The raw event remains in the trace so Advisor can independently recheck it.

Use existing argument builders for other hosts. Do not add a cross-host translation table.

- [ ] **Step 3: Run executor and full checks**

```sh
npx tsx --test src/executor/codex/codex.test.ts
npx tsx --test src/executor/zcode/zcode.test.ts
npm run typecheck
npm run smoke
npm run build
git diff --check
```

Use the exact existing ZCode test path after promotion if its filename differs.

- [ ] **Step 4: Commit**

```sh
git add src/executor src/types.ts
git commit -m "feat: pass exact effort to ODW executors"
```

---

### Task 6: Document, Verify, and Merge

**Files:**

- Modify: `README.md`
- Modify: `README.en.md`
- Modify: the source skill files that document `runWorkflow()`
- Modify: `package.json` and `package-lock.json` together

- [ ] **Step 1: Document the public policy**

Document:

- exact interface and one example,
- conflict timing,
- nested inheritance,
- cache/resume rejection,
- trace/fingerprint semantics,
- unchanged unpolicy behavior,
- requested route is not authoritative host attestation.

- [ ] **Step 2: Bump the package version**

Use `0.1.0` for this first public routing API unless current merged `origin/main` already has a newer version. Update `package.json` and both version fields in `package-lock.json` together; do not commit ignored `dist/` output.

- [ ] **Step 3: Run the complete suite**

```sh
npm install
npx tsx --test src/runtime/routing.test.ts
npx tsx --test src/smoke.test.ts
npx tsx --test src/executor/subprocess.test.ts
npx tsx --test src/executor/codex/codex.test.ts
npx tsx --test src/executor/zcode/zcode-envelope.test.ts
npm run typecheck
npm run smoke
npm run build
git diff --check
```

- [ ] **Step 4: Commit docs/version**

```sh
git add README.md README.en.md package.json package-lock.json skills
git commit -m "docs: publish ODW routing policy"
```

- [ ] **Step 5: Open and merge the PR**

```sh
git push -u origin codex/advisor-routing-policy
gh pr create --repo atebites-hub/open-dynamic-workflows --base main --head codex/advisor-routing-policy --title "feat: enforce immutable workflow routing" --body-file PR_BODY.md
```

Wait for CI and review, merge, fetch the resulting `origin/main`, and rerun the complete suite from a fresh worktree. Record the merged SHA for the ODW plugin pin.
