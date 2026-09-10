# Upstream fork maintenance

This repository is a **true GitHub fork** of
[DannyMac180/sol-advisor](https://github.com/DannyMac180/sol-advisor). Keep
`fork: true` and that parent. Do not convert it to a standalone repo.

Factory-owned behavior lives on `main` as first-class commits. Upstream moves
in through `chore: sync upstream` pull requests. Never force-push `main` unless
it is still identical to upstream and the only path is a reviewable PR.

## Remotes

| Remote | URL | Role |
| --- | --- | --- |
| `origin` | https://github.com/atebites-hub/advisor.git | This fork (push / PRs). GitHub renamed the slug from `sol-advisor`; old URLs redirect. |
| `upstream` | https://github.com/DannyMac180/sol-advisor.git | Parent (fetch only) |

```bash
git remote add origin https://github.com/atebites-hub/advisor.git   # if missing
git remote add upstream https://github.com/DannyMac180/sol-advisor.git  # if missing
git remote -v
# origin    https://github.com/atebites-hub/advisor.git (fetch/push)
# upstream  https://github.com/DannyMac180/sol-advisor.git (fetch)
```

Do not `git push` to `upstream`.

## Last synced upstream tip

- **Upstream:** https://github.com/DannyMac180/sol-advisor
- **Parent:** [DannyMac180/sol-advisor](https://github.com/DannyMac180/sol-advisor)
- **Last synced upstream tip:** <!-- upstream-tip-begin -->`37b75cad535abdd46531f0227483a8842d045ab8` (`37b75ca`, `feat: add risk-gated selective routing`)<!-- upstream-tip-end -->

That SHA is the current merge-base of `origin/main` and `upstream/main` (they
match: this fork is **ahead**, not behind). Reconfirmed 2026-09-10:

- GitHub compare `DannyMac180:main...atebites-hub:main` is **ahead 63 / behind 0**
  (48 non-merge factory commits + 15 merge commits). Reverse compare
  `atebites-hub:main...DannyMac180:main` is **ahead 0 / behind 63**.
- `git merge-base --is-ancestor upstream/main origin/main` is true.
- Weekday Sync upstream run [`34506380614`](https://github.com/atebites-hub/advisor/actions/runs/34506380614)
  logged `origin/main already contains upstream/main; nothing to sync`.

The weekday sync workflow rewrites only the `upstream-tip-begin/end` span when
it opens a clean sync PR.

## Owners

- **Jaskarn** (atebites-hub)
- **Factory Plugins bot**

## Divergence (patches we own)

These are atebites-only on `origin/main` and not in
`DannyMac180/sol-advisor`. Inventory via
`gh api repos/DannyMac180/sol-advisor/compare/main...atebites-hub:main`
(2026-09-10: **ahead 63 / behind 0**; was 42 / 0 when this file landed in
PR #7 on 2026-09-05). Do not drop them in an upstream merge without recording
the deferral here.

| Patch / behavior | Why we keep it | Conflict risk | Commits |
| --- | --- | --- | --- |
| Cross-host Advisor (Cursor, ZCode, Claude Code, Grok) | Upstream is Codex-only; factory hosts need install, doctor, and truthful routing | **High** — README, skills, `verify.sh`, host packages | `4e49a82` (PR #1) |
| Product name Advisor; Sol/Luna is one Codex preset | Upstream product identity is Sol-specific; factory copy and doctor treat any catalog-backed pair as valid | Medium — README, skills, helper usage | `d43610c`, `2744bdd` (PR #9) |
| Repo slug `atebites-hub/advisor` | GitHub renamed this fork; workflow `github.repository` and origin URL must match. Package id stays `sol-advisor` | Medium — README, workflows, homepage URLs | `d43610c`, `74b66bf` (PR #9) |
| Isolated host model choices | Doctor/apply report catalog-backed pairs; they do not copy values into host model or provider settings | Medium — doctor, README, helper | `c32abf2` (PR #16) |
| Claude native-first seating | Claude has a native advisor tool (`/advisor`, `advisorModel`, `--advisor`), distinct from opusplan and ultracode. Doctor reports configured intent without claiming runtime proof and never overlays Codex strict seating. Defer is not skip-ODW. | Medium — README, doctor, Claude skill copy | `74b66bf` (PR #9), `c32abf2` (PR #16) |
| Native-first with ODW alignment | Prefer ultracode / ultra / multitask when those are the right tool; ODW must still align (detect, do not fight, compose or defer). Alignment is required design and unproven. Native-first does not mean skip ODW. Cursor investigation is alignment, not “ODW unused.” | Medium — README, `odw.md`, operations | `4fcf5ed` (PR #10) |
| First-class Cursor IDE / CLI plugin | `.cursor-plugin/`, `install-cursor.sh`, session context, doctor; strict delegation stays disabled | Medium — plugin manifests and Cursor hooks | `4fd7892` (PR #6) |
| Isolated host plugin packages | Codex / ZCode / Cursor packages stay separate so one host cannot load another host's files | Medium — marketplace and package layout | `c9abee8` (PR #2) |
| Packaged `advisor` helper + canonical paths | `$advisor` / `/advisor` run the in-repo helper; no PATH binary | Medium — `bin/advisor`, `find-helper.sh` | `86016fb` |
| ZCode runtime attestation + authoritative session IDs | Strict ZCode native / ODW lanes need observed role, model, effort, parent, completion | **High** — ZCode hooks and inspect scripts | `03eafe9` (PR #3) |
| ZCode apply/configure defaults + ODW seating | `apply --host zcode` / `configure --host zcode` write plugin defaults; ODW seating still requires install/enable `open-dynamic-workflows@0.3.0` | Medium — helper, README, seating smoke | `1da33ee` (PR #11) |
| ZCode plugins list `.plugins[]` | Doctor treats ZCode `plugins list` `.plugins[]` as ODW-compatible (0.3.0); Codex `installed` shape stays valid | Medium — doctor matcher | `e3e5b04` (PR #12) |
| Codex `hooks.state` trust observation | Doctor reads Codex `[hooks.state]` and does not soft-pass attestation or suggest `--dangerously-bypass-hook-trust` | Medium — doctor, operations | `c47a3bd`, `d2c354c` (PR #14) |
| One-leaf smoke is launch-then `--run-dir` | `smoke-odw-one-leaf.sh` does not auto-launch; inspect a completed run with `inspect-odw-run.sh --host zcode` | Low — README, `odw.md`, operations, smoke | `96a3d47`, `bfd2c7c` (PR #13) |
| ODW inspect-odw-run (immutable policy) | Accept only fresh completed traces that match the immutable `{executor, model, reasoningEffort}` policy | Medium — ODW references and inspectors | `d57f2bc`, `1dbd761` |
| Automatic session activation | Inject orchestration contract at session start on supported hosts | Medium — hooks and prompt copy | `6fa9aac`, `17dba52` |
| Bounded grunt enforcement / ordinary-tool continuity | One bounded grunt when useful; solo tools stay available outside Advisor routing | Medium — spawn guards and verifier isolation | `7416c9a`, `60432dd` (PR #4), `aad5fe1` (PR #5) |
| Fork-maintenance docs + weekday sync | `UPSTREAM.md` + `.github/workflows/sync-upstream.yml`; keep the GitHub fork relationship | Low — docs and workflow only | `f6f4fb8` (PR #7) |
| Weekly Actions artifact cleanup | Delete artifacts older than 3 days (`cleanup-artifacts.yml`) | Low — workflow only | `d43e860` (PR #8) |
| atebites-hub marketplace catalogs | Install origin is this fork (`atebites-hub/advisor`), not `DannyMac180/sol-advisor` | Low — catalog JSON only | `f0f1257` |

Non-merge factory commits (newest first):

```
c32abf2 fix: isolate host model choices and use Claude native advisor
d2c354c docs: note python3 is required to read Codex hooks.state
c47a3bd fix: observe Codex hooks.state trust in advisor doctor
bfd2c7c docs: name inspect-odw-run.sh on the session-gated path
96a3d47 docs: one-leaf smoke is launch-then --run-dir
e3e5b04 fix: treat ZCode plugins list as ODW-compatible
50652bb docs: keep ODW install/enable and ZCode apply phrases contiguous
1da33ee feat: ZCode apply/configure defaults and ODW seating smoke
4fcf5ed docs: require ODW alignment with native orchestrators
74b66bf docs: native-first Claude seating and ODW, keep advisor slug
2744bdd docs: avoid retired Terra wording in the About-text note
d43610c docs: productize Advisor and retarget atebites-hub/advisor
d43e860 ci: weekly artifact cleanup
f6f4fb8 docs: add UPSTREAM.md and weekday sync workflow
86016fb fix: canonicalize packaged Advisor helper paths
4fd7892 feat: make Advisor a first-class Cursor IDE and CLI host
aad5fe1 test: isolate Advisor verification from installed roles
60432dd fix: keep ordinary tools available outside Advisor routing
03eafe9 fix: accept authoritative ZCode session IDs
c9abee8 fix: isolate host plugin packages
4e49a82 feat: generalize Advisor across coding hosts
1428851 docs: keep ZCode runtime checkpoints atomic
4063ca4 docs: plan cross-host Advisor rollout
6322f8d docs: design cross-host Advisor routing
f0f1257 fix: publish the installable origin
898e114 fix: preserve ODW on read-only audits
b751f5a fix: honor the Agent spawn alias
def97e3 fix: keep ODW runs in the active workspace
5a372b8 docs: select ODW for explicit repeatability
1dbd761 docs: publish ODW Luna High routing
d57f2bc feat: verify ODW Luna High runtimes
1e43d57 feat: route Luna sessions to worker context
c6125f7 docs: design ODW Luna High compatibility
17dba52 docs: publish automatic Sol Advisor activation
6fa9aac feat: activate Sol Advisor on session start
44ca310 docs: plan automatic session activation
065b2e5 docs: include automatic activation prompt copy
6b76ca1 docs: design automatic session activation
550c2fd fix: enforce collaboration subagent spawns
7b891a2 fix: tighten release verification
cdd421e docs: publish the Sol Ultra and Luna High workflow
923b198 feat: keep judgment and review in Sol Ultra
096849d fix: clarify Luna child boundaries
b9563b3 feat: migrate to one Luna High child role
7416c9a feat: enforce Luna subagent spawns
e97e9dd chore: ignore local worktrees
7968315 docs: plan Luna subagent enforcement
8b5a04c docs: specify Luna subagent enforcement
```

Do not bump [atebites-plugins](https://github.com/atebites-hub/atebites-plugins)
pins in a sync PR. Marketplace pin bumps stay a separate change after fork CI
and smoke.

## Deferred (intentionally not in this fork yet)

| Item | Reason |
| --- | --- |
| atebites-plugins pin / catalog cutover (`sol-advisor` → `advisor` paths) | Separate consumer PR after this fork lands; do not bump pins here |
| Advisor as factory default | Superpowers remains the provisional factory pack |
| Strict Cursor / Claude / Grok delegation | Hosts still cannot prove role, model, effort, parent, and completion |
| Antigravity / GitHub Copilot adapters | No plugin surface or evidence contract; Copilot Lane B is parked; explicit gap, not a support-table soft-pass |
| Live Claude native advisor fixture | Doctor reports `native_advisor_unverified`; native settings and a completed consultation are different evidence, and advisor effort is not separately exposed |
| Native/ODW alignment fixtures | ultracode, ultra, and Cursor multitask alignment with ODW (detect, compose, or explicit defer) is required design and unproven until live fixtures and QA |

## Sync policy (Project Factory FORK-MAINTENANCE)

1. **Keep the GitHub fork relationship.** Parent must stay `DannyMac180/sol-advisor`.
2. **Never rewrite published `main`.** No force-push to `main`. Exception only if `main` is still byte-identical to `upstream/main` and the change still goes through a PR.
3. **Do not rebase factory commits off `main`.** Replay happens by *merging* `upstream/main` into a branch that already has factory commits.
4. **Sync through a PR titled exactly `chore: sync upstream`** into `main`. Prefer GitHub **Create a merge commit** (not squash, not rebase) so factory SHAs stay reachable and the next merge has a sane merge-base.
5. **Preserve factory host adapters.** When README, hooks, or `verify.sh` conflict, keep cross-host Advisor, Cursor install/doctor, ZCode attestation, and isolated packages.
6. **Update this file** after each successful sync: last synced tip (the `upstream-tip` markers) and any new divergence or deferral.

### Manual sync

```bash
git fetch origin
git fetch upstream
git checkout -b chore/sync-upstream-$(git rev-parse --short upstream/main) origin/main

# Skip if we already contain upstream/main:
#   git merge-base --is-ancestor upstream/main HEAD && echo already synced

git merge --no-ff upstream/main -m "chore: merge upstream $(git rev-parse --short upstream/main)"
# Resolve conflicts using the divergence table. Keep factory host adapters.
# Update the Last synced upstream tip markers in this file.

git push -u origin HEAD
# Open PR title: chore: sync upstream
# Merge with a merge commit.
```

Weekday automation: `.github/workflows/sync-upstream.yml` (UTC cron, plus
`workflow_dispatch`). If an open PR already has that exact title, the workflow
leaves it alone.

`GITHUB_TOKEN` pull requests do not start other workflows. Set repository
secret `UPSTREAM_SYNC_TOKEN` (Factory Plugins bot PAT with `contents` +
`pull-requests`) so sync PRs still run CI.

### After every sync

- [ ] Factory host adapters and the commits above still reachable (or a deferral is recorded)
- [ ] `sh plugins/sol-advisor/scripts/verify.sh` and `git diff --check`
- [ ] This file’s last-synced SHA matches `upstream/main`
- [ ] Fork still `fork: true` with parent `DannyMac180/sol-advisor`
- [ ] Origin URL and workflow `github.repository` still `atebites-hub/advisor`
- [ ] No marketplace pin bumps in the sync PR
