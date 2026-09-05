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
configure --host codex --advisor-model MODEL --advisor-effort EFFORT --grunt-model MODEL --grunt-effort EFFORT
apply --host codex
doctor --host codex|zcode|grok|cursor|claude [--json]
remove --host codex
```

`configure` accepts any catalog-backed advisor/grunt pair. When a local Codex
model catalog is present, both tuples must exist there; when it is absent,
configure still writes the pair and `doctor` reports
`model_capability_unverified`. The Codex built-in default (used when no
profile exists) is the Sol / Ultra + Luna / High preset only—not the product
identity.

On Claude, prefer ultracode or the built-in advisor / Opus plan.
`doctor --host claude` reports `code=native_advisor_unverified`,
`diagnostics.seating=defer_to_native_when_present`, and `odwLane=disabled`.
Do not overlay Sol-style plugin seating. Mapping the live Opus plan /
ultracode surface is a follow-up; this scrub does not claim `nativeAdvisor=present`.

ODW is not the default orchestrator on Claude, Codex ultra mode, or Cursor
multitask.

Configuration is not runtime proof. Do not call a lane strict unless `doctor`
and the host-specific runtime acceptance both succeed.
