# Advisor

Advisor keeps architecture, judgment, verification, and final review in the primary
model. It delegates only bounded execution to a configured grunt, and accepts delegated
work only when the host can prove the actual role, model, effort, parent, and completion
state.

The product name is **Advisor**. The GitHub repository is
[`atebites-hub/advisor`](https://github.com/atebites-hub/advisor) (former slug
`sol-advisor` still redirects). The package coordinate stays
`sol-advisor@sol-advisor` so existing installs keep upgrading.

Any catalog-backed advisor/grunt pair is valid. GPT-5.6 Sol / Ultra + GPT-5.6 Luna /
High is one Codex default **preset**, not the product identity.

## Support

| Host | Native orchestration | Plugin Advisor seating | ODW |
|---|---|---|---|
| Codex CLI / ChatGPT Codex app | **ultra mode first** | strict `advisor_grunt` after hook trust and live rollout evidence | optional; not the default orchestrator |
| ZCode | persisted `main` / `lite` plus runtime attestation | strict on the maintained fork after live attestation | optional; supported after the same evidence contract |
| Cursor IDE / Cursor CLI (`agent`) | **multitask first** (under-investigated) | first-class plugin, commands, CLI install, and doctor; strict seating disabled | not default; refused until runtime evidence can prove role, model, effort, parent, and completion |
| Claude Code | **ultracode / Opus plan first** when present | defer to that native path; else plugin guidance only. Never overlay Sol-style strict seating | not default; rejected |
| Grok Build | none proven | experimental detection; strict delegation disabled because hook failures are fail-open | rejected |
| Grok Bot | excluded | excluded | excluded |

Native orchestration is preferred. ODW is for multi-executor / harness-agnostic
fan-out that those natives do not cover. See [Native-first vs ODW](#native-first-vs-odw).

Antigravity and GitHub Copilot are **deferred gaps** (Copilot Lane B is parked).
This repository has no adapter, doctor host, or evidence contract for them. A
missing row is not a soft pass.

Advisor is not a factory default. Superpowers remains the provisional factory skill
pack; enabling Advisor there is a separate consumer change.

## Native-first vs ODW

| Host | Use this native path | Use ODW only when |
|---|---|---|
| Claude Code | ultracode, or Claude's built-in advisor / Opus plan | multi-executor or harness-agnostic fan-out the native path cannot cover |
| ChatGPT / Codex | ultra mode | same |
| Cursor | multitask (needs a better live investigation before we treat it as proven) | same |
| ZCode | native Agent with persisted `lite` attestation | scaled or rerunnable work that already satisfies the ODW inspector |

`$advisor doctor` never treats ODW as required, and never reports `strict: true`
from ODW being installed. Codex and ZCode may accept an ODW run after
`inspect-odw-run.sh` proves a fresh completed trace. Claude, Cursor, and Grok
stay ODW-disabled.

## Install and start coding

### Codex CLI or ChatGPT Codex app

```sh
codex plugin marketplace add atebites-hub/advisor --ref main
codex plugin add sol-advisor@sol-advisor
```

In Codex, invoke `$advisor`. Prefer ultra mode for ordinary orchestration.
Configure any catalog-backed pair, then apply it when you want plugin grunt
seating:

```text
$advisor configure --host codex --advisor-model MODEL --advisor-effort EFFORT --grunt-model MODEL --grunt-effort EFFORT
$advisor apply --host codex
```

To accept the built-in Codex preset—GPT-5.6 Sol / Ultra as advisor and GPT-5.6 Luna /
High as grunt—apply it once without writing a profile:

```text
$advisor apply --host codex
```

Open `/hooks`, review and trust all Advisor hooks, then run:

```text
$advisor doctor --host codex
```

Start a fresh task and vibe code normally. Advisor activates at session start, verifies
the primary runtime before native or ODW delegation, delegates a bounded packet only
when useful, and performs the final review in the primary task. A mismatched primary
stays usable for ordinary solo tools but cannot delegate under Advisor. Plugin
installation does not add an `advisor` executable to your shell `PATH`; `$advisor` runs
the packaged helper.

Before uninstalling, invoke `$advisor remove --host codex`. It removes only the exact
generated role, valid profile, and validated Advisor session snapshots.

### ZCode

```sh
zcode plugins marketplace add atebites-hub/advisor
zcode plugins install sol-advisor@sol-advisor
```

Set all four Advisor options in ZCode Settings → Plugin Management, or use
`zcode plugins configure ... --options-file`. Then invoke:

```text
$sol-advisor:advisor doctor --host zcode
```

Start a new session after changing settings. The maintained runtime snapshots the pair
once per root session; every native child inherits the persisted grunt route. Strict
Advisor delegation is foreground-only so the parent hook can verify the completed
child before accepting its result. Advisor never rewrites ZCode provider credentials
or host-owned model settings.

### Cursor IDE and Cursor CLI (`agent`)

Install the repository as a Cursor plugin. The package coordinate stays
`sol-advisor@sol-advisor`. Plugin installation does not add an `advisor`
executable to your shell `PATH`; `/advisor` and the packaged helper are the
entrypoints.

Prefer Cursor **multitask** for native fan-out. That surface still needs a
better live investigation before Advisor will treat it as proven seating.
Strict plugin delegation stays disabled.

**Local plugin (IDE + CLI, no Customize required for CLI):**

```sh
git clone https://github.com/atebites-hub/advisor.git
cd advisor
sh plugins/sol-advisor/scripts/install-cursor.sh
```

That symlinks this checkout to `~/.cursor/plugins/local/sol-advisor` and mirrors
the `advisor` and `orchestration` skills into `~/.cursor/skills` so Cursor CLI
can load them even when plugin skills are invisible. Restart Cursor, or for a
one-shot CLI session:

```sh
agent --plugin-dir "$HOME/.cursor/plugins/local/sol-advisor"
```

From a checkout without installing locally:

```sh
agent --plugin-dir /path/to/advisor
```

Team marketplace installs use `.cursor-plugin/marketplace.json` (official Cursor
schema: plugin entries are only `name`, `source`, `description`, and optional
`minClientVersions`).

In the IDE, invoke `/advisor` or the `advisor` skill. In the CLI:

```text
/advisor
/advisor doctor --host cursor --json
```

Or run the packaged helper directly:

```sh
sh "$HOME/.cursor/plugins/local/sol-advisor/plugins/sol-advisor/bin/advisor" doctor --host cursor --json
```

`doctor --host cursor` is read-only. It detects `cursor-agent`, Cursor CLI
`agent`, `CURSOR_PLUGIN_ROOT`, `PLUGIN_ROOT`, and `ODW_HOST=cursor`, and it
lists the exact native and ODW evidence gaps. It never treats settings,
`--model`, or hook `model_params` as runtime proof.

Advisor does not ship MCP. If you also install Open Dynamic Workflows, inspect
it separately:

```sh
agent mcp list
agent mcp list-tools open-dynamic-workflows
```

Start a fresh Agent session after install. `sessionStart` injects the
orchestration contract as additional context in the IDE and in CLI plugin
sessions. Stay in `solo` unless Cursor multitask is already doing the fan-out.
Do not enable fail-open plugin delegation.

### Claude Code

Install this repository through the Claude plugin marketplace and invoke the
installed `advisor` skill for diagnostics only.

Claude already has a built-in advisor / Opus plan path (**ultracode**). Detect
that harness and **defer to it**. Do not seat a Sol-style plugin advisor/grunt
pair as if Claude had none.

```text
$advisor doctor --host claude --json
```

Doctor is honest and fail-closed:

- `strict` is always `false`
- `odwLane` is `disabled` (ODW is not Claude's default orchestrator)
- `code` is `native_advisor_unverified` until a live Claude fixture maps the
  Opus plan / ultracode command surface
- `diagnostics.seating` is `defer_to_native_when_present`
- `diagnostics.nativeAdvisor` stays `unverified` in this release (follow-up:
  prove the native path, then set `present` and keep plugin seating off)

If the native path is absent, the plugin skill is guidance only. It is not
runtime proof and must not spawn a Codex-shaped grunt.

### Grok Build

Install through the host marketplace and run `doctor --host grok`. Guidance
only; hook failures are fail-open, so strict delegation stays disabled.

## Names and coordinates

| Surface | Value | Why |
|---|---|---|
| Product name | Advisor | displayName, docs, doctor |
| GitHub slug | `atebites-hub/advisor` | renamed fork; `atebites-hub/sol-advisor` redirects |
| Package coordinate | `sol-advisor@sol-advisor` | Codex add, ZCode options key, Cursor local path |
| Codex default pair | Sol / Ultra + Luna / High | one catalog preset, not product identity |
| Upstream parent | `DannyMac180/sol-advisor` | keep the true fork; do not orphan |

Keep using `$advisor`, `/advisor`, and `$sol-advisor:advisor`. Do not look for a
PATH `advisor` binary. atebites-plugins pins stay unchanged in this PR.

The GitHub About description is repository metadata, not a file in this tree.
Update it in repo Settings (or `gh repo edit --description`) to Advisor framing;
the inherited Codex-native About text is stale.

## Open Dynamic Workflows

With `open-dynamic-workflows` 0.3.0 installed, Advisor may choose ODW for
**scaled or rerunnable multi-executor work that native orchestration does not
cover**. It is not the default orchestrator on Claude (ultracode), Codex
(ultra mode), or Cursor (multitask).

When ODW is used, Advisor passes one immutable
`{executor, model, reasoningEffort}` policy, rejects node conflicts before
launch, and accepts only fresh completed traces whose host runtime evidence
matches that policy. Codex and ZCode are the only accepted ODW executors.
Cursor may be the host process (`ODW_HOST=cursor`) and is still refused as an
executor. Claude Code and Grok Build remain rejected. Ordinary work stays on
the native path.

The policy fingerprint is correlation evidence, not proof by itself. The primary
advisor still inspects the real output, reruns verification, and renders the verdict.

## Maintainers

This repository is a true GitHub fork of
[DannyMac180/sol-advisor](https://github.com/DannyMac180/sol-advisor). Remotes,
last-synced tip, factory divergence, and weekday sync are in
[UPSTREAM.md](UPSTREAM.md).

```sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
```

See [operations](plugins/sol-advisor/skills/orchestration/references/operations.md) for
host contracts, runtime evidence, migrations, and release acceptance.

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=advisor) to get new posts to your inbox.
