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

`origin/main` already contains that parent tip. The weekday sync workflow
rewrites only the `upstream-tip-begin/end` span when it opens a clean sync PR.

## Owners

- **Jaskarn** (atebites-hub)
- **Factory Plugins bot**

## Divergence (patches we own)

These are atebites-only. Do not drop them in an upstream merge without
recording the deferral here.

| Patch / behavior | Why we keep it | Conflict risk |
| --- | --- | --- |
| Cross-host Advisor (Cursor, ZCode, Claude Code, Grok) | Upstream is Codex-only; factory hosts need install, doctor, and truthful routing | **High** — README, skills, `verify.sh`, host packages |
| Product name Advisor; Sol/Luna is one Codex preset | Upstream product identity is Sol-specific; factory copy and doctor treat any catalog-backed pair as valid | Medium — README, skills, helper usage |
| Repo slug `atebites-hub/advisor` | GitHub renamed this fork; workflow `github.repository` and origin URL must match. Package id stays `sol-advisor` | Medium — README, workflows, homepage URLs |
| Claude native-first seating | Claude has ultracode / Opus plan; doctor defers to that path and never overlays Sol-style strict seating | Medium — README, doctor, Claude skill copy |
| Native-first vs ODW | ODW is not the default orchestrator on Claude, Codex ultra mode, or Cursor multitask | Medium — README, `odw.md`, operations |
| First-class Cursor IDE / CLI plugin | `.cursor-plugin/`, `install-cursor.sh`, session context, doctor; strict delegation stays disabled | Medium — plugin manifests and Cursor hooks |
| Isolated host plugin packages | Codex / ZCode / Cursor packages stay separate so one host cannot load another host's files | Medium — marketplace and package layout |
| Packaged `advisor` helper + canonical paths | `$advisor` / `/advisor` run the in-repo helper; no PATH binary | Medium — `bin/advisor`, `find-helper.sh` |
| ZCode runtime attestation + authoritative session IDs | Strict ZCode native / ODW lanes need observed role, model, effort, parent, completion | **High** — ZCode hooks and inspect scripts |
| ODW inspect-odw-run (immutable policy) | Accept only fresh completed traces that match the immutable `{executor, model, reasoningEffort}` policy | Medium — ODW references and inspectors |
| Automatic session activation | Inject orchestration contract at session start on supported hosts | Medium — hooks and prompt copy |
| Bounded grunt enforcement / ordinary-tool continuity | One bounded grunt when useful; solo tools stay available outside Advisor routing | Medium — spawn guards and verifier isolation |
| atebites-hub marketplace catalogs | Install origin is this fork (`atebites-hub/advisor`), not `DannyMac180/sol-advisor` | Low — catalog JSON only |

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
| Live Claude Opus plan / ultracode fixture | Doctor reports `native_advisor_unverified` until a live Claude harness maps the native command surface |

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

- [ ] Factory host adapters still present (or a deferral is recorded above)
- [ ] `sh plugins/sol-advisor/scripts/verify.sh` and `git diff --check`
- [ ] This file’s last-synced SHA matches `upstream/main`
- [ ] Fork still `fork: true` with parent `DannyMac180/sol-advisor`
- [ ] Origin URL and workflow `github.repository` still `atebites-hub/advisor`
- [ ] No marketplace pin bumps in the sync PR
