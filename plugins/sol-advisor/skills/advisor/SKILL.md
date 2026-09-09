---
name: advisor
description: Configure, apply, remove, or diagnose Advisor host routing without requiring a PATH-installed executable.
---

# Advisor command

Resolve this skill's installed directory, then run `../../bin/advisor` with the
arguments the user requested. Show the helper's exact result. Never claim plugin
installation exports an `advisor` command to the user's shell.

Codex exposes this skill as `$advisor`; ZCode exposes the qualified
`$sol-advisor:advisor`. Cursor IDE and Cursor CLI expose `/advisor` plus this
skill. Resolve the helper from `CURSOR_PLUGIN_ROOT`, `PLUGIN_ROOT`,
`~/.cursor/plugins/local/sol-advisor/plugins/sol-advisor/bin/advisor`, or
`../../bin/advisor`. Cursor doctor is first-class and still disables strict
delegation until runtime evidence matches the contract.

Supported commands:

```text
configure --host codex|zcode --advisor-model MODEL --advisor-effort EFFORT --grunt-model MODEL --grunt-effort EFFORT
apply --host codex|zcode
doctor --host codex|zcode|grok|cursor|claude [--json]
remove --host codex
```

`configure` accepts any catalog-backed advisor/grunt pair. For Codex, when a local Codex
model catalog is present, both tuples must exist there; when it is absent,
configure still writes the pair and `doctor` reports
`model_capability_unverified`. ZCode never borrows Codex's catalog. An explicit
`ADVISOR_MODEL_CATALOG` may supply the target host's catalog; otherwise ZCode
accepts configuration intent and its runtime must verify availability.
Configure all four ZCode options first. `apply --host zcode` preserves that pair
in `~/.zcode/cli/config.json` (or `ZCODE_CONFIG`) and refuses empty settings.
The legacy Sol / Ultra + Luna / High preset belongs to Codex only, not the
product identity. Explicit choices, including Astra on Codex, take precedence.

`doctor` reports `odwPlugin.compatible=true` only when
`open-dynamic-workflows@open-dynamic-workflows` is installed+enabled at
version 0.3.0 on that Codex or ZCode host. If `compatible` is false,
install/enable `open-dynamic-workflows@0.3.0`; marketplace `package.json`
at 0.3.0 is not enough.

On Claude Code, use the native `/advisor MODEL`, `advisorModel` user setting,
or session-local `claude --advisor MODEL`. The native `/advisor` command is
not this plugin's skill. Keep the existing main model unless the user asks
to change it. The advisor tool is separate from `opusplan` (plan-mode model
switching), subagents, and ultracode. Use native pairing/account checks; never
substitute Sol, map main effort onto advisor effort, or accept billing consent
on the user's behalf. Native advisor effort is not separately exposed.
`doctor --host claude` reports
`code=native_advisor_unverified`,
`diagnostics.seating=defer_to_native_when_present`, and `odwLane=disabled`.
`diagnostics.userSettings` reports only the configured advisor/main/effort,
not effective policy or a successful consultation. Keep that seating honest:
`nativeAdvisor` stays `unverified`. Do not
overlay Sol-style plugin seating. `defer_to_native_when_present` does not
mean skip ODW.

Native-first **with ODW alignment required**. Prefer ultracode (Claude),
ultra (Codex), or multitask (Cursor) as harness specialty orchestration.
ODW must still detect those modes, not fight them, document how it seats
or composes (or explicitly defers), and fill cross-executor /
multi-harness gaps. Alignment is required design and unproven until live
fixtures and QA. Cursor multitask investigation is that alignment, not a
soft-green “ODW unused.” ODW is not the default orchestrator on those
hosts.

Configuration is not runtime proof. Do not call a lane strict unless `doctor`
and the host-specific runtime acceptance both succeed.
