---
name: advisor
description: Run Advisor doctor and host diagnostics for Cursor IDE or Cursor CLI (`agent`). Strict delegation stays disabled until runtime evidence matches the contract.
---

# Advisor

Resolve the packaged helper. Plugin installation does not export an `advisor`
binary to `PATH`. Then run it with the user's arguments, defaulting to
`doctor --host cursor` when none are given. Show the helper's exact result.

Resolve `bin/advisor` in this order and stop at the first executable file:

1. `$CURSOR_PLUGIN_ROOT/plugins/sol-advisor/bin/advisor`
2. `$PLUGIN_ROOT/bin/advisor`
3. `$PLUGIN_ROOT/plugins/sol-advisor/bin/advisor`
4. `~/.cursor/plugins/local/sol-advisor/plugins/sol-advisor/bin/advisor`

If those are missing, run `plugins/sol-advisor/scripts/find-helper.sh` from the
plugin checkout. Never install or recommend a PATH `advisor` command.

Cursor doctor is read-only. Configuration intent, `--model`, hook `model_params`,
and ODW routing fingerprints are not runtime proof. Do not delegate natively or
through ODW while doctor reports `strict: false`.
