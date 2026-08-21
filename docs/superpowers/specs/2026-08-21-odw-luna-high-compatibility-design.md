# Open Dynamic Workflows Luna / High Compatibility

Status: design approved on 2026-08-21.

## Decision

Sol Advisor will govern Open Dynamic Workflows (ODW) without modifying ODW source,
its installed cache, or its executor. The outer Codex task remains GPT-5.6 Sol with
Ultra reasoning and owns workflow design, material judgment, verification, final
review, and acceptance. Every ODW node that executes model work—including discovery,
implementation, judging, verification, and synthesis—must run through Codex on
GPT-5.6 Luna with High reasoning.

ODW is an execution mechanism within the existing `delegate` or `audit` route, not a
fourth route. It is used only when the task satisfies ODW's own scale or repeatability
criteria. Ordinary bounded delegation continues to use the native
`sol_advisor_luna_subagent` profile.

## Current behavior and compatibility gap

Installed ODW v0.2.0 does not call Codex's native `spawn_agent` tool. Each
`agent()` node launches a separate process equivalent to:

```text
codex exec --json ...
```

Therefore Sol Advisor's current `PreToolUse` spawn guard never sees ODW nodes. ODW's
`agentType` option is only an `Explore`, `Plan`, or `General` prompt preset; it is not
a Codex custom-agent role and does not select a model. A node-level model override
defaults Codex reasoning to Medium unless `reasoningEffort` is also explicit.

Accordingly, ODW workers do not claim the native `sol_advisor_luna_subagent` role.
Their accepted identity is a trace-linked ODW Codex process whose actual runtime is
GPT-5.6 Luna / High. The native role remains exclusive to native delegation.

A live ODW-style subprocess test confirmed that a Luna / High `codex exec` loads the
current Sol Advisor `SessionStart` context but is still a standalone session without
the native Luna role. Instruction injection alone is therefore not sufficient proof
of the worker model, effort, or relationship to the parent run.

## Goals

1. Make Sol Advisor-authored ODW workflows use Codex Luna / High for every model node.
2. Keep all architecture and final acceptance in the outer Sol / Ultra task.
3. Prevent node options from overriding the selected executor, model, or effort.
4. Give Luna ODW workers context appropriate to bounded execution rather than the
   primary-task Sol / Ultra contract.
5. Verify every fresh ODW node from persisted launch traces and actual Codex runtime
   metadata before accepting any workflow result.
6. Fail closed on missing, conflicting, cached, or otherwise unverifiable evidence.
7. Preserve native Luna child enforcement unchanged.

## Non-goals and boundaries

- Do not edit, patch, fork, or reinstall ODW as part of this feature.
- Do not claim ODW's runtime globally enforces Sol Advisor policy. Arbitrary workflows
  created outside Sol Advisor remain outside the boundary.
- Do not treat ODW `agentType` as model or role evidence.
- Do not add an ODW-specific primary route or a second reviewer role.
- Do not permit ZCode, mixed executors, alternate models, or alternate reasoning
  levels in a Sol Advisor-governed ODW run.
- Do not accept an ODW run merely because its source text contains the expected model
  names. Persisted launch and runtime evidence are required.
- The plugin still cannot select or prove the outer task's Ultra effort through hook
  input; the outer task must be started and verified as Sol / Ultra separately.
- Native `spawn_agent` denial remains the only pre-spawn machine guard. ODW enforcement
  is an authoring plus acceptance contract because ODW launches subprocesses outside
  that tool path.

## Approaches considered

### 1. Prompt-only ODW guidance — rejected

The orchestration skill could merely tell the primary task to add Luna / High options.
This is small but provides no durable proof and cannot catch an omitted option, ODW's
Medium fallback, or a mixed executor.

### 2. Sol Advisor node contract plus runtime verifier — selected

Sol Advisor authors every ODW script through one locked helper, gives Luna processes a
worker-specific session context, and validates the completed run's ODW traces against
the corresponding Codex rollouts. This needs changes only in Sol Advisor and states the
enforcement boundary truthfully.

### 3. Add an enforced policy API to ODW — deferred

ODW could gain a runtime-level immutable executor/model/effort policy. That would be
the strongest pre-spawn guarantee but requires changing another project and its public
contract. Revisit only if plugin-local authoring and fail-closed acceptance prove
insufficient.

## Workflow authoring contract

Every Sol Advisor ODW script defines one local wrapper with caller options spread
first and immutable routing fields applied last:

```js
const lunaAgent = (prompt, options = {}) => agent(prompt, {
  ...options,
  executor: 'codex',
  model: 'gpt-5.6-luna',
  reasoningEffort: 'high',
})
```

The script uses `lunaAgent()` for every model call and never calls raw `agent()`
elsewhere. Applying the fixed fields after `...options` prevents a caller from
overriding them. ODW options such as `label`, `phase`, `schema`, `agentType`, retries,
and worktree isolation remain available.

All worker prompts retain the existing bounded-task principles: observable objective,
explicit ownership, settled interfaces, constraints, verification, and structured
return. They also state that the worker must not spawn subagents or render the final
verdict. A Luna synthesis node may consolidate results, but its output remains a draft
for independent Sol / Ultra review.

Nested workflows and saved scripts are allowed only when their complete resolved run
produces the same per-node evidence. Source shape is guidance; runtime evidence is the
acceptance authority.

## Model-sensitive session context

The trusted `SessionStart` hook will delegate context selection to one plugin-owned
script instead of unconditionally printing the primary orchestration skill:

- `gpt-5.6-luna`: emit a compact bounded-worker context aligned with the native Luna
  profile. It says not to act as the primary, spawn children, or perform final review.
- Any other model: emit the canonical orchestration skill, which retains the Sol /
  Ultra primary check and stops unsupported primary tasks.

The documented SessionStart payload exposes model but not reasoning effort. Model
selection is therefore contextual routing, not proof that an ODW worker used High.
The run verifier supplies that proof. Treating every Luna task as a worker is
intentional while Sol Advisor is enabled: Luna is never a valid primary under this
plugin's contract.

## Runtime evidence and acceptance

Sol Advisor will ship a repository-relative ODW run inspector. It accepts one exact
fresh run directory under `.odw/<workflow>/runs/<run-id>/` and emits only allowlisted
routing evidence. For every non-cached `agent_start`, it must prove:

1. One corresponding agent trace exists.
2. The executable is `codex`, not ZCode or another executor.
3. The recorded argv contains exactly GPT-5.6 Luna and High reasoning selections.
4. The trace contains one Codex thread ID.
5. Exactly one local rollout matches that thread ID.
6. Runtime metadata reports `gpt-5.6-luna` and `high` without conflicting contexts.
7. The agent completed successfully and no started agent is unaccounted for.

The inspector never emits prompts, schemas, arbitrary tool output, environment
variables, tokens, or full trace payloads. Invalid paths, symlinks, missing files,
duplicate thread matches, wrong options, failed agents, and partial journals are
rejected.

ODW resume creates a new run whose cached nodes do not have new launch traces. The
first release therefore rejects any run containing `cached: true`; the user may rerun
it fully live for acceptance. Cached provenance support can be added later if a real
need justifies following and validating the complete prior-run lineage.

## Data flow

```text
fresh outer task on Sol / Ultra
  -> SessionStart loads primary orchestration context
  -> primary selects delegate or audit and confirms ODW fits the task
  -> primary writes inline workflow using only locked lunaAgent()
  -> ODW starts independent Codex Luna / High processes
  -> each Luna SessionStart loads bounded-worker context
  -> ODW records run events, argv traces, and child thread IDs
  -> Sol Advisor run inspector validates every fresh node and rollout
  -> Sol / Ultra primary independently reviews evidence and final result
  -> accept, correct and rerun, or reject
```

ODW may fan out beyond Sol Advisor's normal one-native-child default because scale is
the reason to choose ODW. The primary must still choose a finite, task-justified fanout
and use ODW's own concurrency and total-agent limits.

## Error handling

- ODW plugin missing or disabled: stop before authoring or running a workflow.
- An ODW version other than the initially supported and tested v0.2.0: treat
  compatibility as unverified until its executor and trace contract are revalidated.
- Wrong outer model or unconfirmed effort: stop before the workflow tool call.
- Raw or unpinned `agent()` call found during primary review: correct the script before
  running it.
- Wrong executor/model/effort in any trace: reject the entire run; do not accept the
  remaining nodes.
- Missing or conflicting runtime metadata: reject the affected run rather than infer.
- Failed or skipped node: the inspector rejects the run. The primary may revise and
  rerun it or report a partial result, but may not accept it as complete evidence.
- Cached node: reject the run for Sol Advisor acceptance in the first release.
- Worker attempts architecture, child spawning, or final review: disregard that output
  and correct the worker packet or keep the work in the primary task.

## Files and release scope

Sol Advisor v0.8.0 will modify only this repository:

- `plugins/sol-advisor/hooks/hooks.json`: run model-sensitive session context selection.
- `plugins/sol-advisor/hooks/session-context.sh`: choose primary or bounded-worker
  context from validated SessionStart input.
- `plugins/sol-advisor/skills/orchestration/SKILL.md`: define when ODW is valid and keep
  final acceptance in the primary task.
- `plugins/sol-advisor/skills/orchestration/references/odw.md`: document the exact
  `lunaAgent` wrapper, worker packet, evidence, and failure boundary.
- `plugins/sol-advisor/scripts/inspect-odw-run.sh`: validate fresh ODW run traces and
  corresponding Codex runtime metadata without leaking payloads.
- `plugins/sol-advisor/scripts/verify.sh`: add SessionStart and ODW trace fixtures.
- `README.md`, operations reference, UI copy, and manifest: publish the compatibility
  boundary and bump the minor version.

The native Luna profile, its installer, the native spawn guard, and ODW itself remain
unchanged.

## Verification and acceptance

Repository verification must cover:

- Sol SessionStart input emits the canonical primary orchestration skill.
- Luna SessionStart input emits only the bounded-worker context.
- Missing or malformed hook input fails. Any valid non-Luna model receives the
  canonical primary skill, which stops before task work unless it is Sol / Ultra.
- Existing native Luna spawn allowance and wrong-role denials remain unchanged.
- A fixture ODW run with multiple Codex Luna / High traces passes.
- Fixtures with ZCode, wrong/missing/duplicate model or effort flags, failed nodes,
  missing/duplicate rollouts, unsafe paths, and cached nodes fail without leaking
  payload content.
- Active documentation contains no Terra, separate reviewer, or mixed-executor route.
- JSON, TOML, shell syntax, and `git diff --check` pass.

Live acceptance requires fresh CLI and desktop Sol / Ultra tasks with both plugins
enabled and current hooks trusted:

1. Use an ordinary large-task prompt that legitimately selects ODW without explicitly
   naming Sol Advisor.
2. Observe the outer route declaration before the workflow tool.
3. Run a small multi-node inline workflow through `lunaAgent()`.
4. Inspect the resulting run and verify every recorded child is Luna / High.
5. Deliberately run or fixture one wrong-model node and prove acceptance fails.
6. Confirm the outer recorded runtime remains Sol / Ultra and performs the final
   review rather than delegating that verdict.

Report source verification, installed versions, hook trust, workflow execution,
per-node runtime evidence, rejected negative probe, and root review as separate claims.
