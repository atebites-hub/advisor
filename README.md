# Advisor

Advisor keeps architecture, judgment, verification, and final review in the primary
model. It delegates only bounded execution to a configured grunt, and accepts delegated
work only when the host can prove the actual role, model, effort, parent, and completion
state.

The package coordinate stays `sol-advisor@sol-advisor` for upgrade compatibility; the
product name is Advisor.

## Support

| Host | Native delegation | ODW delegation | Status |
|---|---|---|---|
| Codex CLI / ChatGPT Codex app | custom `advisor_grunt` plus rollout inspection | Codex executor plus rollout inspection | strict after hook trust and live runtime acceptance |
| ZCode | persisted `main` / `lite` policy plus runtime attestation | ZCode executor plus runtime attestation | strict on the maintained fork after live runtime acceptance |
| Cursor | disabled | disabled | experimental detection; strict delegation disabled |
| Claude Code | disabled | disabled | experimental detection; strict delegation disabled |
| Grok Build | disabled | disabled | experimental detection; strict delegation disabled because hook failures are fail-open |
| Grok Bot | excluded | excluded | excluded |

## Install and start coding

### Codex CLI or ChatGPT Codex app

```sh
codex plugin marketplace add atebites-hub/sol-advisor --ref main
codex plugin add sol-advisor@sol-advisor
```

In Codex, invoke `$advisor`. To accept the built-in Codex default—GPT-5.6 Sol / Ultra
as advisor and GPT-5.6 Luna / High as grunt—apply it once:

```text
$advisor apply --host codex
```

Or configure and apply another catalog-backed pair:

```text
$advisor configure --host codex --advisor-model MODEL --advisor-effort EFFORT --grunt-model MODEL --grunt-effort EFFORT
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
zcode plugins marketplace add atebites-hub/sol-advisor
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

### Cursor, Claude Code, and Grok Build

Install this repository through the host's plugin marketplace and invoke its installed
`advisor` skill. These packages intentionally provide guidance and diagnostics only.
Their current runtimes cannot prove the identical strict contract, so Advisor refuses
delegation instead of treating requested settings as runtime evidence.

## Open Dynamic Workflows

With `open-dynamic-workflows` 0.3.0 installed, Advisor may choose ODW for scaled or
rerunnable work. It passes one immutable `{executor, model, reasoningEffort}` policy,
rejects node conflicts before launch, and accepts only fresh completed traces whose
host runtime evidence matches that policy. Codex and ZCode are the supported ODW hosts;
experimental hosts are rejected. Ordinary work stays on the native path.

The policy fingerprint is correlation evidence, not proof by itself. The primary
advisor still inspects the real output, reruns verification, and renders the verdict.

## Maintainers

```sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
```

See [operations](plugins/sol-advisor/skills/orchestration/references/operations.md) for
host contracts, runtime evidence, migrations, and release acceptance.

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) to get new posts to your inbox.
