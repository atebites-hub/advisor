# Advisor ODW Plugin Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the merged ODW routing policy through the installable Open Dynamic Workflows plugin, pin the merged ZCode/ODW dependencies, and provide valid MCP packaging for Codex/ChatGPT, Cursor, Claude Code, Grok Build, and ZCode.

**Architecture:** Keep one zero-dependency MCP server and one workflow tool. Forward `routingPolicy` directly to ODW core, let core perform validation/enforcement, and preserve host-derived default executors for unpolicy workflows. Rebuild the two tracked bundles and update only the host manifests/catalogs already owned by this repository.

**Tech Stack:** TypeScript, Node.js, esbuild, MCP stdio, Git submodules, Codex/Cursor/Claude/Grok/ZCode plugin manifests, existing smoke harness.

## Prerequisites

- `atebites-hub/zcode-cli` exact-route/attestation PR is merged to `main`.
- `atebites-hub/open-dynamic-workflows` host-executor promotion and routing-policy PRs are merged to `main`.
- Record both merged SHAs before changing submodule pins.
- Never run submodule update in the existing dirty `/Users/jaskarn/github/open-dynamic-workflows-plugin` checkout.

---

### Task 1: Create a Clean Worktree and Pin Merged Dependencies

**Files:**

- Modify: `.gitmodules`
- Modify gitlink: `open-dynamic-workflows`
- Modify gitlink: `zcode-cli`

- [ ] **Step 1: Create an isolated worktree**

Use the worktree skill to create `codex/advisor-routing-policy` from current `origin/main`. Initialize submodules only inside that worktree.

- [ ] **Step 2: Fetch and verify dependency heads**

```sh
git -C open-dynamic-workflows fetch origin main
git -C zcode-cli fetch origin main
git -C open-dynamic-workflows rev-parse origin/main
git -C zcode-cli rev-parse origin/main
git -C open-dynamic-workflows log -1 --oneline origin/main
git -C zcode-cli log -1 --oneline origin/main
```

Expected: each SHA matches the merged dependency recorded by the umbrella plan.

- [ ] **Step 3: Move ODW tracking to its default branch**

Change:

```ini
[submodule "open-dynamic-workflows"]
	path = open-dynamic-workflows
	url = https://github.com/atebites-hub/open-dynamic-workflows.git
	branch = main
```

Keep the ZCode submodule URL unchanged; no branch field is required for a commit pin.

- [ ] **Step 4: Check out exact merged commits and stage gitlinks**

```sh
git -C open-dynamic-workflows checkout --detach origin/main
git -C zcode-cli checkout --detach origin/main
git add .gitmodules open-dynamic-workflows zcode-cli
git diff --cached --submodule=log
```

Expected: only `.gitmodules` and the two intended gitlinks are staged.

- [ ] **Step 5: Run dependency source checks**

```sh
npm --prefix open-dynamic-workflows ci
npm --prefix open-dynamic-workflows run typecheck
npm --prefix open-dynamic-workflows run smoke
npm --prefix open-dynamic-workflows run build
bun --cwd zcode-cli install --frozen-lockfile
bun --cwd zcode-cli test test/launcher.test.ts test/sync-runtime.test.ts
bun --cwd zcode-cli run typecheck
```

- [ ] **Step 6: Commit pins**

```sh
git commit -m "chore: pin merged Advisor routing dependencies"
```

---

### Task 2: Expose `routingPolicy` Through the MCP Tool

**Files:**

- Modify: `src/mcp/server.ts`
- Modify: `scripts/smoke.mjs`

**MCP input schema:**

```json
{
  "routingPolicy": {
    "type": "object",
    "additionalProperties": false,
    "required": ["executor", "model", "reasoningEffort"],
    "properties": {
      "executor": { "type": "string", "minLength": 1 },
      "model": { "type": "string", "minLength": 1 },
      "reasoningEffort": { "type": "string", "minLength": 1 }
    }
  }
}
```

- [ ] **Step 1: Write failing bundle smoke tests**

Extend `scripts/smoke.mjs` to assert:

1. `tools/list` exposes the exact schema above.
2. A valid two-node policy run forwards one policy and returns its fingerprint.
3. A conflicting node executor fails before fake process launch.
4. A conflicting node model fails before fake process launch.
5. A conflicting node effort fails before fake process launch.
6. `routingPolicy` plus `resumeFromRunId` fails.
7. An unpolicy workflow still uses `defaultExecutorForHost()`.
8. Direct malformed `tools/call` values—nonobject, extra key, whitespace-only field, and unknown executor—fail in ODW core before workflow/journal/process creation.

Run:

```sh
npm run build
npm run smoke
```

Expected: new smoke assertions fail before source changes.

- [ ] **Step 2: Add the field without duplicate policy logic**

In `runWorkflowTool()` add:

```ts
routingPolicy?: unknown;
```

Destructure it and pass:

```ts
...(routingPolicy !== undefined
  ? { routingPolicy: routingPolicy as RoutingPolicy }
  : {}),
```

to `runWorkflow()`. The MCP JSON schema advertises the contract but this zero-dependency server does not perform schema validation itself. Cross the static TypeScript boundary with one explicit `RoutingPolicy` type assertion and let `normalizeRoutingPolicy(unknown, ...)` in ODW core validate the raw runtime value. Do not copy policy checks into `server.ts`.

- [ ] **Step 3: Return allowlisted policy metadata**

Add the following to the result summary only when present:

```ts
routingPolicy: result.routingPolicy,
routingPolicyFingerprint: result.routingPolicyFingerprint,
```

Do not return prompts, environment, raw traces, stderr, or session transcripts.

- [ ] **Step 4: Update the tool description**

Document:

- policy fields are exact and immutable,
- omitted node route fields inherit policy,
- conflicts fail before launch,
- nested workflows inherit policy,
- policy runs cannot resume/use cache,
- the fingerprint is route correlation and still requires host runtime evidence.

- [ ] **Step 5: Run focused checks and commit**

```sh
npm run build
npm run typecheck
npm run smoke
git diff --check
git add src/mcp/server.ts scripts/smoke.mjs dist/mcp/server.js plugins/open-dynamic-workflows/dist/mcp/server.js
git commit -m "feat: expose immutable ODW routing policy"
```

---

### Task 3: Package All Five Host MCP Surfaces

**Files:**

- Modify: `.claude-plugin/plugin.json`
- Modify: `.codex-mcp.json`
- Verify: `.mcp.json`
- Verify: `mcp.json`
- Verify: `.grok-plugin/mcp.json`
- Verify nested host copies under `plugins/open-dynamic-workflows/`
- Modify: `src/mcp/host.test.ts`
- Modify: `scripts/smoke.mjs`

- [ ] **Step 1: Add failing host startup tests**

For each host environment, start the built server, complete MCP `initialize` and `tools/list`, then run one unpolicy model node against fake host binaries/counters and assert which executor launched:

| Host | Environment | Expected executor |
|---|---|---|
| Codex/ChatGPT | `ODW_HOST=codex` | `codex` |
| Cursor | `ODW_HOST=cursor` | `cursor` |
| Claude Code | `ODW_HOST=claude` | `claude` |
| Grok Build | `ODW_HOST=grok` | `grok` |
| ZCode | `ODW_HOST=zcode` | `zcode` |

Also prove an invalid explicit `ODW_HOST` makes an omitted-executor workflow fail before process launch, and that Grok wins over its Claude compatibility environment.

- [ ] **Step 2: Add Claude's inline MCP server**

Because root `.mcp.json` is ZCode's host-specific surface, add this to `.claude-plugin/plugin.json`:

```json
{
  "mcpServers": {
    "open-dynamic-workflows": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/dist/mcp/server.js"],
      "env": {
        "ODW_HOST": "claude"
      }
    }
  }
}
```

Use the repository's actual JSON merge, not a second manifest. Keep only metadata plus the inline MCP entry in `.claude-plugin/`; skills/commands remain at plugin root.

- [ ] **Step 3: Verify existing host configs remain host-native**

- Codex uses `.codex-mcp.json` with `ODW_REQUIRE_CWD=1` and `ODW_HOST=codex`.
- Cursor uses `mcp.json` and its nested copy with `ODW_HOST=cursor`.
- Grok uses root/nested `.grok-plugin/mcp.json` with `ODW_HOST=grok`.
- ZCode keeps root `.mcp.json` with `ZCODE_PLUGIN_ROOT` and `ODW_HOST=zcode`.

Do not invent a universal environment-variable expression or wrapper process.

- [ ] **Step 4: Run host tests and commit**

```sh
npm run build
npm run test:host
npm run smoke
git diff --check
git add .claude-plugin/plugin.json .codex-mcp.json .mcp.json mcp.json .grok-plugin plugins/open-dynamic-workflows src/mcp/host.test.ts scripts/smoke.mjs
git commit -m "feat: package ODW for five coding hosts"
```

Only tracked files with actual changes should be staged.

---

### Task 4: Synchronize Generated Packages, Manifests, and CI

**Files:**

- Modify: `scripts/build.mjs`
- Modify: `.github/workflows/ci.yml`
- Modify: `package.json`
- Modify: `package-lock.json`
- Modify: every root/nested plugin manifest and owned marketplace catalog
- Regenerate: `dist/mcp/server.js`
- Regenerate: `plugins/open-dynamic-workflows/dist/mcp/server.js`

- [ ] **Step 1: Add a failing generated-artifact check**

Update CI so a clean build must leave both tracked bundles unchanged:

```sh
git diff --exit-code -- dist/mcp/server.js plugins/open-dynamic-workflows
```

Extend `scripts/build.mjs` only enough to keep the nested package's `dist`, `skills`, `commands`, Cursor files, and Grok files synchronized. Keep root-only Codex, Claude, and ZCode surfaces root-owned.

- [ ] **Step 2: Bump one coherent release version**

Use `0.3.0` for this public API/host packaging release unless a newer merged release already occupies it. Update:

- root `package.json` and `package-lock.json`,
- `SERVER_INFO.version`,
- root Codex/Cursor/Claude/Grok/ZCode manifests,
- nested Cursor/Grok manifests,
- all repository-owned marketplace entries.

- [ ] **Step 3: Rebuild and prove determinism**

```sh
npm ci --ignore-scripts
npm run build
cmp dist/mcp/server.js plugins/open-dynamic-workflows/dist/mcp/server.js
npm run typecheck
npm run test:host
npm run smoke
git diff --check
```

- [ ] **Step 4: Commit**

```sh
git add package.json package-lock.json src/mcp/server.ts scripts/build.mjs .github/workflows/ci.yml dist plugins .agents .codex-plugin .cursor-plugin .claude-plugin .grok-plugin .zcode-plugin marketplace.json
git commit -m "chore: prepare ODW 0.3.0 plugin bundle"
```

Inspect `git diff --cached --stat` before committing; omit paths that did not change.

---

### Task 5: Update User and Authoring Documentation

**Files:**

- Modify: `README.md`
- Modify: `README_CN.md`
- Modify: `skills/open-dynamic-workflows/SKILL.md`
- Modify: `commands/workflows.md`
- Regenerate nested skill/command copies with `npm run build`

- [ ] **Step 1: Document exact behavior**

Cover:

- five host install surfaces,
- `routingPolicy` example,
- host default versus explicit policy executor,
- no model/effort fallback,
- conflict and nested inheritance rules,
- cache/resume rejection,
- policy fingerprint and trace locations,
- actual runtime attestation remains a host/Advisor acceptance concern,
- Grok Bot is not an ODW plugin host.

- [ ] **Step 2: Build and test generated copies**

```sh
npm run build
npm run typecheck
npm run test:host
npm run smoke
cmp dist/mcp/server.js plugins/open-dynamic-workflows/dist/mcp/server.js
git diff --check
```

- [ ] **Step 3: Commit**

```sh
git add README.md README_CN.md skills commands plugins/open-dynamic-workflows
git commit -m "docs: explain governed ODW routing"
```

---

### Task 6: Full Verification, PR, Merge, and Clean Install

- [ ] **Step 1: Run all source checks**

```sh
npm ci --ignore-scripts
npm run build
npm run typecheck
npm run test:host
npm run smoke
npm --prefix open-dynamic-workflows run typecheck
npm --prefix open-dynamic-workflows run smoke
git diff --check
git diff --exit-code -- dist/mcp/server.js plugins/open-dynamic-workflows
```

- [ ] **Step 2: Open and merge the PR**

```sh
git push -u origin codex/advisor-routing-policy
gh pr create --repo atebites-hub/open-dynamic-workflows-plugin --base main --head codex/advisor-routing-policy --title "feat: ship immutable routing across ODW hosts" --body-file PR_BODY.md
```

The PR body must include both dependency SHAs, generated-bundle proof, manifest/version matrix, and host startup tests. Wait for checks/review, merge, and fetch the resulting `origin/main`.

- [ ] **Step 3: Reverify from merged origin**

Create a fresh `origin/main` worktree, initialize submodules at recorded pins, and rerun Step 1.

- [ ] **Step 4: Run disposable-profile install/removal smokes**

For each installed CLI available on the test machine:

- Codex: add marketplace, install plugin, inspect `codex plugin list --json`, start MCP, uninstall plugin, remove marketplace.
- Cursor: install as a local/private plugin, start MCP, remove the local plugin.
- Claude: validate the manifest, add marketplace, install, inspect `claude plugin list` and `/mcp`, uninstall and remove marketplace.
- Grok: add marketplace, install with hook/plugin trust, inspect, run MCP, uninstall and remove marketplace.
- ZCode: add marketplace, install, inspect/describe, run MCP, uninstall and remove marketplace.

Do not call an unavailable CLI “passed.” Record it as not executed and keep that host unadvertised until its live smoke is run.

- [ ] **Step 5: Record merged origin version/SHA**

Supply the exact ODW plugin version and merged SHA to Advisor's compatibility matrix. No separate marketplace-index PR is required unless a real external catalog submission is discovered during the clean-install smoke.
