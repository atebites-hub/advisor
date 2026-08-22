# Open Dynamic Workflows contract

Use ODW only for scaled fanout or rerunnable orchestration. It remains inside
`delegate` or `audit`; the advisor owns workflow design, judgment, verification, final
review, and acceptance.

## Preflight

Require the enabled `open-dynamic-workflows@open-dynamic-workflows` plugin at exactly
version 0.3.0. Other versions are unverified. Do not edit ODW or its installed cache to
satisfy this check.

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
