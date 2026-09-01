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

Configuration is not runtime proof. Do not call a lane strict unless `doctor`
and the host-specific runtime acceptance both succeed.
