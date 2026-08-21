# Advisor Cross-Host Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one configurable Advisor policy across Codex/ChatGPT, Grok Build, ZCode, Cursor, and Claude Code, with exact advisor/grunt model-and-effort tuples, native delegation, immutable ODW routing, and evidence-based acceptance. Grok Bot remains excluded.

**Architecture:** Keep the existing `sol-advisor` package identifier for compatibility and rename only the user-facing product to Advisor. Use native host agents and hooks for ordinary delegation, use one optional immutable routing policy in ODW for large/repeatable work, and make the primary advisor reject every delegated result whose resolved model and effort cannot be proven. Land and merge the dependency repositories in order; never build a parallel orchestration runtime.

**Tech Stack:** POSIX shell, jq, TypeScript, Bun, Node.js, Codex hooks/custom agents, Cursor plugins/hooks, Claude Code plugins/hooks, Grok Build plugins/hooks/roles, ZCode runtime patches, Open Dynamic Workflows, GitHub Actions and GitHub CLI.

## Fixed Product Contract

- Default Codex advisor: `gpt-5.6-sol` / `ultra`.
- Default Codex grunt: `gpt-5.6-luna` / `high`.
- Every other host uses the exact model IDs and effort vocabulary configured for that host. Never translate names or choose a fallback.
- The same model may be configured for advisor and grunt.
- The primary advisor owns architecture, material judgment, verification, final review, and acceptance.
- A native or ODW child is acceptable only when authoritative runtime evidence matches the configured grunt tuple.
- A host/version that cannot expose both resolved model and resolved effort is disabled for strict delegation and documented as experimental or unsupported.
- A host whose hook runner fails open on handler crash/timeout cannot satisfy identical strict enforcement even when successful deny responses work. Grok Build 1.0.5 is therefore packaged as experimental with Advisor delegation disabled; promote it only after a current version passes failure-injection and runtime-evidence gates.
- ODW is optional. Its absence disables only the ODW lane.
- Policy-sensitive ODW runs are live only; cache/resume is rejected in the first release.
- Grok Bot and Claude Code's experimental native Advisor tool are outside this product.
- “Done” means merged origin branches, published/pinned artifacts, fresh installation, a positive live route, and an intentional wrong-route denial. A green source test alone is not completion.

## Repository and PR Dependency Graph

```text
atebites-hub/zcode-cli
          |
          v
atebites-hub/open-dynamic-workflows
  PR A: promote feat/zcode-executor to main
  PR B: immutable routing policy
          |
          v
atebites-hub/open-dynamic-workflows-plugin
  merged pins + five-host MCP packaging
          |
          v
atebites-hub/sol-advisor
  generalized Advisor product and native adapters
          |
          v
fresh-install/live acceptance and only then release/index updates
```

Use these subsystem plans:

- `docs/superpowers/plans/2026-08-21-advisor-zcode-runtime-attestation.md`
- `docs/superpowers/plans/2026-08-21-advisor-odw-routing-policy.md`
- `docs/superpowers/plans/2026-08-21-advisor-odw-plugin-bundle.md`
- `docs/superpowers/plans/2026-08-21-advisor-native-adapters.md`

## Global Safety Rules

- Use isolated worktrees for all four repositories.
- Preserve the existing dirty `/Users/jaskarn/github/open-dynamic-workflows-plugin` checkout and its modified `zcode-cli` gitlink.
- Before each worktree, fetch the current remote and record the exact base SHA in the PR body. Do not assume the SHAs named in the design are still current.
- Never resolve ZCode's fork files with blanket “ours” or “theirs”; rebase the fork additions onto current upstream behavior.
- Never force-push a shared/default branch.
- Do not merge a dependent PR until the dependency PR is green, merged, pulled from its default branch, and locally reverified.
- Do not create a new marketplace repository. Update only catalogs already owned by the repository being released.

---

### Task 1: Record Live Baselines Without Mutating User Checkouts

**Files:**

- Read: all four repositories' `.git/config`, manifests, lockfiles, and status
- Create in each PR worktree later: no baseline artifact

- [ ] **Step 1: Fetch remote refs and record status**

Run:

```sh
git -C "/Users/jaskarn/github/ZCode Dynamic Workflows/zcode-cli" fetch --prune origin
git -C "/Users/jaskarn/github/ZCode Dynamic Workflows/zcode-cli" fetch --prune kingsword09
git -C "/Users/jaskarn/github/ZCode Dynamic Workflows/open-dynamic-workflows" fetch --prune origin
git -C "/Users/jaskarn/github/open-dynamic-workflows-plugin" fetch --prune origin
git -C "/Users/jaskarn/github/sol-advisor" fetch --prune origin

git -C "/Users/jaskarn/github/ZCode Dynamic Workflows/zcode-cli" status --short --branch
git -C "/Users/jaskarn/github/ZCode Dynamic Workflows/open-dynamic-workflows" status --short --branch
git -C "/Users/jaskarn/github/open-dynamic-workflows-plugin" status --short --branch
git -C "/Users/jaskarn/github/sol-advisor" status --short --branch
```

Expected: the first, second, and fourth repository are safe to work from or can be isolated without touching their current checkout. The ODW plugin checkout still reports its known `zcode-cli` gitlink modification and remains untouched.

- [ ] **Step 2: Record exact remote heads**

Run:

```sh
git -C "/Users/jaskarn/github/ZCode Dynamic Workflows/zcode-cli" rev-parse origin/main kingsword09/main
git -C "/Users/jaskarn/github/ZCode Dynamic Workflows/open-dynamic-workflows" rev-parse origin/main origin/feat/zcode-executor
git -C "/Users/jaskarn/github/open-dynamic-workflows-plugin" rev-parse origin/main
git -C "/Users/jaskarn/github/sol-advisor" rev-parse origin/main
```

Expected: six resolved commit IDs. Copy them into the corresponding PR descriptions; do not commit a mutable “current SHA” file.

---

### Task 2: Update and Merge ZCode

**Plan:** `docs/superpowers/plans/2026-08-21-advisor-zcode-runtime-attestation.md`

- [ ] **Step 1: Execute the ZCode plan in an isolated worktree**

The PR must preserve the maintained fork's ODW protocol and temporary settings isolation while merging current `kingsword09/main`, exact reasoning-effort routing, and runtime-generated attestation.

- [ ] **Step 2: Open and merge the ZCode PR**

After all ZCode checks pass:

```sh
gh pr create --repo atebites-hub/zcode-cli --base main --head codex/advisor-routing --title "feat: add attestable Advisor routing" --body-file PR_BODY.md
gh pr checks --repo atebites-hub/zcode-cli --watch "$(gh pr view --repo atebites-hub/zcode-cli --json number --jq .number)"
gh pr merge --repo atebites-hub/zcode-cli --merge --delete-branch "$(gh pr view --repo atebites-hub/zcode-cli --json number --jq .number)"
```

Do not commit `PR_BODY.md`. The body must name the upstream base SHA, preserved fork commits, test commands, and attestation contract.

- [ ] **Step 3: Reverify merged origin**

Create a clean worktree from the new `origin/main` and run:

```sh
bun install --frozen-lockfile
bun test test/launcher.test.ts test/sync-runtime.test.ts
bun run typecheck
bun run build
bun run check
git diff --check
```

Expected: every command exits zero and the clean worktree stays clean after generated checks that are not meant to be committed.

---

### Task 3: Promote ODW's Existing Host Executors to `main`

**Files:**

- Source branch: `origin/feat/zcode-executor`
- Base branch: `origin/main`
- Test: the repository's current typecheck, smoke, and build scripts

- [ ] **Step 1: Prove the promotion diff is the already-reviewed host-executor line**

Run in an isolated ODW worktree:

```sh
git log --oneline --decorate origin/main..origin/feat/zcode-executor
git diff --stat origin/main...origin/feat/zcode-executor
gh pr list --repo atebites-hub/open-dynamic-workflows --state merged --base feat/zcode-executor --json number,title,headRefName,mergeCommit
```

Expected: the feature branch contains the merged ZCode, Codex effort/security, Grok, and Cursor executor work; no unrelated user change is present.

- [ ] **Step 2: Run the feature branch's full zero-token checks**

```sh
npm ci
npm run typecheck
npm run smoke
npm run build
git diff --check
```

- [ ] **Step 3: Open a promotion PR and merge it before policy work**

```sh
gh pr create --repo atebites-hub/open-dynamic-workflows --base main --head feat/zcode-executor --title "feat: promote supported host executors to main" --body-file PR_BODY.md
gh pr checks --repo atebites-hub/open-dynamic-workflows --watch "$(gh pr view --repo atebites-hub/open-dynamic-workflows --json number --jq .number)"
gh pr merge --repo atebites-hub/open-dynamic-workflows --merge "$(gh pr view --repo atebites-hub/open-dynamic-workflows --json number --jq .number)"
```

The PR body must link the already-merged component PRs and the exact source/base SHAs. If GitHub reports the branch already merged or an equivalent promotion PR exists, inspect that merged diff and use the resulting `origin/main` instead of creating a duplicate.

- [ ] **Step 4: Reverify the merged default branch**

Fetch `origin/main` into a new clean worktree and rerun `npm ci`, `npm run typecheck`, `npm run smoke`, `npm run build`, and `git diff --check`.

---

### Task 4: Add and Merge the ODW Routing Policy

**Plan:** `docs/superpowers/plans/2026-08-21-advisor-odw-routing-policy.md`

- [ ] **Step 1: Execute the ODW policy plan from the newly promoted `origin/main`**

The public API must be one optional `routingPolicy` with `executor`, `model`, and `reasoningEffort`. It is normalized/fingerprinted once, inherited by nested workflows, and checked before cache lookup or executor launch.

- [ ] **Step 2: Open, check, and merge the ODW policy PR**

Use branch `codex/advisor-routing-policy` and base `main`. The PR body must state that unpolicy workflows remain compatible and policy runs reject cache/resume.

- [ ] **Step 3: Reverify merged origin**

Run every command listed in the subsystem plan from a fresh `origin/main` worktree. Record the merged SHA for the ODW plugin pin.

---

### Task 5: Update and Merge the ODW Plugin

**Plan:** `docs/superpowers/plans/2026-08-21-advisor-odw-plugin-bundle.md`

- [ ] **Step 1: Execute the bundle plan in a new worktree**

Pin the merged ZCode and ODW `origin/main` SHAs, move `.gitmodules` off the permanent ODW feature branch, expose `routingPolicy` through MCP, rebuild both tracked bundles, and package only valid host surfaces.

- [ ] **Step 2: Open, check, and merge the ODW plugin PR**

Use branch `codex/advisor-routing-policy` and base `main`. Do not mutate or clean the user's existing dirty checkout.

- [ ] **Step 3: Reverify merged origin and install the candidate in clean host profiles**

Run the repository suite plus MCP startup/list-tools smokes for each advertised host. Record the merged SHA and the version declared by that merged manifest as the release candidate for Advisor's pre-release compatibility checks. Do not call it released or require a published artifact yet.

---

### Task 6: Generalize and Merge Advisor

**Plan:** `docs/superpowers/plans/2026-08-21-advisor-native-adapters.md`

- [ ] **Step 1: Execute the Advisor plan from current `origin/main` plus the approved design commit**

Keep package ID `sol-advisor`, use `Advisor` for display/commands, retain one small `advisor configure|doctor` helper, and reuse native host formats. Do not introduce an adapter SDK, daemon, service, database, or dependency.

- [ ] **Step 2: Open, check, and merge the Advisor PR**

Use a `codex/` branch based on current `origin/main`. Include migration from the current Codex-only profile and exact dependency versions/SHAs in the PR body.

- [ ] **Step 3: Reverify merged origin**

Run `plugins/sol-advisor/scripts/verify.sh` and all focused host/config checks from a fresh `origin/main` worktree.

---

### Task 7: Fresh-Install and Live Acceptance

**Files:**

- Modify only if a smoke finds a product defect: the owning repository's source/tests/docs
- Do not edit installed caches by hand

- [ ] **Step 1: Create disposable host profiles**

Use `mktemp -d` per host. Set only that host's supported config-home variables to the disposable directory. Never repurpose the shell's `HOME` variable in a script variable; pass explicit environment assignments to the launched command.

- [ ] **Step 2: Prove the positive native path**

For each host advertised as strict:

1. Install the exact merged-origin Advisor snapshot through a disposable local marketplace.
2. Configure exact advisor and grunt tuples.
3. Start a new primary session.
4. Prove the actual primary tuple from runtime metadata.
5. Run one bounded native child.
6. Prove the child's actual grunt tuple and runtime identity.
7. Have the primary independently review the result.

Save only allowlisted evidence: host/version, session/runtime IDs, model, effort, result state, and timestamps. Never save prompts, secrets, arbitrary transcripts, or environment dumps.

- [ ] **Step 3: Prove the intentional native denial**

Request one exact wrong model or effort through the supported native delegation call and stop immediately after the pre-launch denial or post-run rejection is proven.

- [ ] **Step 4: Prove the positive ODW path**

Run a two-node live workflow with the configured grunt tuple. Verify one policy fingerprint, two distinct runtime IDs, exact effective route fields, no cache/resume, and authoritative host evidence for both nodes.

- [ ] **Step 5: Prove the intentional ODW denial**

Set one node to a conflicting model or effort. Prove the executor invocation count remains zero for that node.

- [ ] **Step 6: Prove uninstall safety**

Run Advisor's collision-safe Codex `remove` action while the plugin is still installed, then disable/uninstall Advisor and ODW from each test profile. Compare unrelated config keys/files before and after; Advisor-owned Codex roles/profiles/snapshots and host plugin settings disappear, while unrelated entries remain byte-for-byte equivalent after JSON normalization where the host rewrites formatting. ZCode requires no rollback action because Advisor never mutates its `model.*` fields; host-owned session history remains ordinary history.

- [ ] **Step 7: Publish the support matrix truthfully**

Mark a host “strict” only after Steps 2–6 pass on its current version. Cursor or Claude remains experimental/unsupported if either resolved effort or child evidence is unavailable; installation assets alone do not upgrade that label.

---

### Task 8: Release and Origin Closure

- [ ] **Step 1: Verify all dependency PRs are merged**

```sh
gh pr list --repo atebites-hub/zcode-cli --state open
gh pr list --repo atebites-hub/open-dynamic-workflows --state open
gh pr list --repo atebites-hub/open-dynamic-workflows-plugin --state open
gh pr list --repo atebites-hub/sol-advisor --state open
```

Inspect the specific PRs by number; unrelated open PRs do not block release.

- [ ] **Step 2: Verify origin contents and release pins**

For every repository, fetch `origin/main`, compare the merged PR commit, candidate version manifests, submodule SHAs, and generated bundles. Do not equate a local branch or tag with origin.

- [ ] **Step 3: Create repository releases only after fresh-install acceptance**

Use each repository's existing release workflow. Do not invent a new release script or tag scheme. Confirm the release artifact/checksum points to the merged default-branch commit.

After publishing, repeat the clean install, positive route, intentional denial, and removal smoke from the released artifact. A local-marketplace snapshot proves the merge candidate; the released-artifact repeat proves distribution.

- [ ] **Step 4: Update only required marketplace catalogs**

The ODW plugin and Advisor repositories own their current catalogs. Submit to any external marketplace only where a live install requires it; report external review as pending rather than merged.

- [ ] **Step 5: Produce the completion report**

Report separately:

- local test status,
- PR URLs and merge SHAs,
- origin verification,
- released versions and pins,
- fresh-install results,
- strict/experimental/excluded host matrix,
- positive runtime-evidence samples,
- intentional-denial samples,
- any external marketplace review still pending.

Do not call the project complete while any required strict-host live proof or dependent origin merge is missing.
