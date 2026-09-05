# Open Dynamic Workflows contract

**Native-first with ODW alignment required.** Prefer the host specialty
path when that is the right tool. Native-first does **not** mean skip ODW
on Claude, Codex, or Cursor. ODW must still align with those modes:
detect them, do not fight them, document how it seats or composes (or
explicitly defers), and fill cross-executor / multi-harness gaps natives
do not cover. Alignment is required design; status is **unproven** until
live fixtures and QA. Unused ODW is not a soft-green pass.

| Host | Prefer this native path | ODW alignment |
|---|---|---|
| Claude Code | ultracode, or the built-in advisor / Opus plan | detect; do not fight; compose or explicitly defer |
| ChatGPT / Codex | ultra mode | same |
| Cursor | multitask | same. The live investigation is this alignment, not “ODW unused.” |
| ZCode | native Agent with persisted `lite` attestation | compose with persisted `lite`; use ODW for scaled or rerunnable inspector-accepted work |

ODW is **not** the default orchestrator. Use it for scaled fanout,
rerunnable orchestration, or multi-executor work those natives do not
cover. It remains inside `delegate` or `audit`; the advisor owns workflow
design, judgment, verification, final review, and acceptance. Claude,
Cursor, and Grok stay rejected ODW **executors** even when the ODW plugin
is installed. Executor refusal is not a pass on alignment.

## Preflight

Require the enabled `open-dynamic-workflows@open-dynamic-workflows` plugin at exactly
version 0.3.0 on the Codex or ZCode host. `doctor` reports
`odwPlugin.compatible=true` only for that installed+enabled state. A marketplace
`package.json` at 0.3.0 is not enough; if `compatible` is false,
install/enable `open-dynamic-workflows@0.3.0`. Other versions are unverified.
Do not edit ODW or its installed cache to satisfy this check.

If the box checkout lacks `plugins/open-dynamic-workflows`, initialize it
before one-leaf seating smoke:

```sh
git submodule update --init plugins/open-dynamic-workflows
sh plugins/sol-advisor/scripts/smoke-odw-one-leaf.sh --host zcode
```

The smoke script is fail-closed: missing checkout, wrong version,
`plugin_settings_required`, `compatible=false`, or a non-one-leaf run is
a failure, not a pass.

Pass `cwd` as the exact active workspace. ODW writes required evidence under
`.odw/<name>/runs/<runId>/`; a read-only project task does not prohibit these run
artifacts.

## Immutable route

Pass one raw three-field policy on the tool call:

```js
workflow({
  cwd: '/absolute/active/workspace',
  routingPolicy: {
    executor: '<codex-or-zcode>',
    model: '<configured-grunt-model>',
    reasoningEffort: '<configured-grunt-effort>',
  },
  script,
})
```

Every model node omits `executor`, `model`, and `reasoningEffort` so ODW fills them from
the immutable run policy. Explicit route fields must match exactly; mixed executors,
raw alternate agents, resume/cache, Cursor, Claude Code, and Grok Build are invalid.
Cursor may be the ODW host process (`ODW_HOST=cursor`) without becoming an accepted
Advisor ODW executor: run `doctor --host cursor` and keep the inspector on
`--host codex` or `--host zcode` only.
Nested workflows inherit the same policy.

Each worker prompt uses the packet in `role-contracts.md`, including exact ownership,
interfaces, constraints, verification, structured return, no subagents, and no final
verdict. Compatible Codex workers receive bounded ODW startup context and cannot use
native spawn or nested-workflow tools. Compatible ZCode workers accept only the
runtime's standalone ODW attestation and cannot use native Agent. Those markers are
context, not route proof. A synthesis node produces only a draft.

## Runtime acceptance

Bind `run_dir` to the exact absolute directory returned by the tool and run:

```sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -n "$plugin_dir" && test "$plugin_dir" != null && test -f "$plugin_dir/scripts/inspect-odw-run.sh"
sh "$plugin_dir/scripts/inspect-odw-run.sh" --host codex "$run_dir"
```

Use `--host zcode` for a ZCode run. The inspector requires one canonical run policy and
recomputed fingerprint, complete fresh lifecycle/journal accounting, one successful
trace per node, unique runtime IDs, and authoritative host evidence matching the
policy. Codex evidence must be a completed standalone root with no native role or
parent. ZCode evidence must attest `route=odw`, `role=main`, and no parent or native
policy fields.

Missing, duplicate, cached, failed, skipped, timed-out, cancelled, partial, symlinked,
wrong-host, wrong-route, or conflicting evidence invalidates the whole run. The
fingerprint correlates records; it never proves model or effort by itself. After route
acceptance, the advisor still inspects the work and reruns its real verification.
