# Open Dynamic Workflows operations

Use ODW only when a task needs more agents than one conversation can coordinate or the
orchestration must be a rerunnable script. ODW is an execution mechanism within
`delegate` or `audit`; it is not a fourth route. The Sol / Ultra primary task owns the
workflow design, material judgment, independent verification, final review, and
acceptance.

ODW may exceed the native one-child default only because justified fanout is the reason
to choose it. Select a finite task-specific node count and obey ODW's concurrency and
total-agent limits.

## Preflight

Require enabled ODW v0.2.0 before authoring or running the workflow:

~~~sh
codex plugin list --json | jq -e '
  .installed[]
  | select(.pluginId == "open-dynamic-workflows@open-dynamic-workflows")
  | .version == "0.2.0" and .enabled == true
'
~~~

Any other version is unverified until its executor arguments and artifact format are
revalidated. Do not edit ODW, its installed source, or its cache to satisfy this check.

## Locked model node

Every inline script defines this wrapper once:

~~~js
const lunaAgent = (prompt, options = {}) => agent(prompt, {
  ...options,
  executor: 'codex',
  model: 'gpt-5.6-luna',
  reasoningEffort: 'high',
})
~~~

Every model call uses `lunaAgent()`. The script contains no other raw `agent()` call.
Review every resolved saved or nested script against the same rule before execution;
nested agents share the parent run's evidence inventory. The fixed fields follow
`...options`, so labels, phases, schemas, retries, `agentType`, and worktree isolation
remain configurable while executor, model, and effort cannot be overridden. ZCode and
mixed-executor workflows are invalid.

Each worker prompt includes this exact boundary:

~~~text
OBJECTIVE
State one observable bounded outcome and why it matters.

FILES AND OWNERSHIP
List the exact owned files or the exact read-only evidence scope.

INTERFACES
List the settled signatures, schemas, commands, and behavior.

CONSTRAINTS
- Preserve concurrent work and do not revert unrelated edits.
- Do not redesign the settled architecture or widen scope.
- Do not spawn subagents or nested workflows.
- Do not render the final verdict or accept your own result.

VERIFICATION
- Run the exact task-specific command.
- State the concrete output that proves success.

RETURN
Return changes, exact verification evidence, judgment calls, and gaps.
~~~

A Luna synthesis node may consolidate worker results, but its output is a draft for
independent Sol / Ultra review.

## Runtime acceptance

Do not accept the tool result by itself. Resolve the installed plugin path, bind
`run_dir` to the exact absolute run directory returned by ODW, and inspect it:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -n "$plugin_dir" && test "$plugin_dir" != null && test -f "$plugin_dir/scripts/inspect-odw-run.sh"
sh "$plugin_dir/scripts/inspect-odw-run.sh" "$run_dir"
~~~

The accepted output contains only `run_id`, `agent_count`, and per-node `agent_id`,
`thread_id`, `model`, and `effort`. Every node must report `gpt-5.6-luna` and `high`.
Missing, duplicate, conflicting, failed, skipped, symlinked, partial, ZCode, mixed,
wrong-route, or cached evidence invalidates the entire run. The first release does not
follow cached provenance; rerun every node live.

After inspection, the Sol / Ultra primary task independently checks the actual work,
reruns relevant verification, corrects or rejects failures, and performs final review.
The inspector proves routing only; it does not prove implementation quality.
