# Sol/Ultra Root and Luna/High Subagent Enforcement

Status: design and written spec approved on 2026-08-20.

## Decision

Sol Advisor will use one capability boundary:

- The primary task runs `gpt-5.6-sol` with `ultra` reasoning.
- The primary task owns requirements, architecture, judgment, integration, verification,
  review, and final acceptance.
- Every spawned child uses `gpt-5.6-luna` with `high` reasoning.
- Terra and the separate Sol reviewer are retired.

Review is therefore Sol/Ultra work performed in the primary task, never a reviewer
subagent.

## Goals

1. Make every supported subagent spawn Luna/High in both Codex CLI and the Codex
   experience in the ChatGPT desktop app while the plugin and its hook are enabled and
   trusted.
2. Reject nonconforming spawns before they start instead of silently changing their
   arguments.
3. Keep Sol/Ultra responsible for all high-judgment work and final review.
4. Reduce the installed agent inventory to one generic Luna child profile.
5. Prove the actual child model and effort before accepting its result.
6. Safely retire exact Sol Advisor agent files installed by earlier releases without
   deleting modified or unrelated user files.

## Non-goals and platform boundary

- A plugin cannot select or change the primary task's model. The orchestration skill
  will verify Sol/Ultra when metadata exposes it and otherwise require user
  confirmation before task work. A mismatch stops the workflow.
- The hook is plugin-wide while enabled: it applies to supported `spawn_agent` calls
  even when the orchestration skill was not explicitly invoked. This is intentional.
- Plugin hooks require explicit trust. An untrusted, disabled, missing, or crashed hook
  is not an enforcement boundary.
- OpenAI documents that specialized tool paths may bypass ordinary tool hooks. Sol
  Advisor will describe its hook as a guardrail for supported spawn calls, not an
  unbypassable global policy.
- This change will not edit the user's global Codex model configuration.

Official basis: [Codex hooks](https://learn.chatgpt.com/docs/hooks) documents
plugin-bundled hooks, trust, `PreToolUse` denial, the `spawn_agent`/`Agent` matcher,
code-mode interception, and the specialized-path limitation.

## Approaches considered

### 1. Deny nonconforming spawns — selected

A `PreToolUse` hook permits only the exact Luna child profile with a fresh context.
Every other supported spawn receives a blocking reason and the exact compliant retry.
This preserves caller intent and makes violations visible.

### 2. Rewrite every spawn — rejected

The hook could replace model, effort, role, and context arguments. That would silently
change context semantics, can conflict with role-pinned profiles, and makes the actual
request harder to audit.

### 3. Instructions only — rejected

Skill prose and agent prompts are useful guidance but cannot stop a wrong tool call.
They remain supporting documentation, not the enforcement mechanism.

## Architecture

### Primary-task contract

The orchestration skill requires `gpt-5.6-sol` with `ultra` reasoning. The primary task
chooses the route, creates complete child packets, inspects the resulting diff or
artifact, reruns checks, performs the final review, and accepts or rejects the work.
Judgment-heavy or high-risk work stays in the primary task; it is not escalated to
another model.

### One generic child profile

The plugin ships one custom profile named `sol_advisor_luna_subagent`, pinned to:

```toml
model = "gpt-5.6-luna"
model_reasoning_effort = "high"
```

Its instructions support bounded implementation, research, evidence gathering, and
testing. It must stay within stated ownership, preserve concurrent edits, report
ambiguity instead of making architectural decisions, and return evidence. It does not
perform final review or spawn further children.

### Spawn guard

The plugin uses the native default `hooks/hooks.json` location and a synchronous
`PreToolUse` command hook matching `collaborationspawn_agent|spawn_agent|Agent`.
Codex 0.149 presents collaboration spawns to hooks as `collaborationspawn_agent`,
while rollout records retain namespace `collaboration` plus name `spawn_agent`.

A spawn is permitted only when all of these are true:

- `agent_type` is exactly `sol_advisor_luna_subagent`.
- `fork_turns` is exactly `none` so the child starts with a fresh context.
- No per-spawn `model` or `reasoning_effort` override is supplied; the installed role
  pin is authoritative.

Missing, malformed, conflicting, generic, built-in, Terra, or Sol child requests are
denied with the supported `PreToolUse` deny response. The reason tells the primary task
to retry with the exact Luna profile and fresh-context contract. The hook never rewrites
the request.

Malformed hook input is handled as a denial. The implementation will use the existing
`jq` dependency and no new runtime dependency. If Codex skips or cannot run the hook,
the UI warning and documented trust requirement are the only available signal; the
plugin must not claim the spawn was blocked.

### Runtime evidence

After a successful spawn, public spawn metadata is authoritative when it exposes role,
model, and effort. If model or effort is omitted, the existing runtime inspector checks
the exact child thread.

The accepted tuple is exactly:

```text
agent_role: sol_advisor_luna_subagent
model: gpt-5.6-luna
effort: high
```

Missing, conflicting, or different evidence invalidates the child result. The primary
task stops rather than accepting or silently substituting it.

## Workflow

The route vocabulary becomes:

- `solo`: Sol/Ultra performs the work, verification, and review without a child.
- `delegate`: one Luna/High child performs a bounded packet; Sol/Ultra verifies and
  reviews it.
- `audit`: Sol/Ultra reviews the target directly. A Luna/High child may gather bounded
  evidence, but it cannot render the verdict.

The old `full` route is removed because, without a separate implementer tier or reviewer
agent, it no longer has a distinct execution topology. The default remains at most one
child. An explicitly independent parallel-work case may use more Luna/High children;
the same guard applies to each spawn.

Every delegated packet retains explicit objective, ownership, interfaces, constraints,
verification, and return evidence. Child work substitutes for primary-task work rather
than duplicating it.

## Installation and migration

The companion installer will install and check the one generic Luna profile. During an
upgrade it will also retire prior Sol Advisor Luna implementer, Terra implementer, and
Sol reviewer files only when their bytes match a known shipped template.

Before changing anything, the installer classifies every affected destination. A
modified, symlinked, nonregular, unreadable, or unknown retired file causes a refusal
with no partial mutation. Unrelated agent files are untouched. A successful migration
leaves exactly the generic Luna profile from Sol Advisor and is idempotent.

Historical role names and fingerprints may remain only inside bounded migration or
spawn-enforcement tests and cleanup logic; they are not active roles or routing options.

## Documentation changes

The manifest, README, skill, role contract, operations reference, and UI metadata will
describe the same two-model contract. Quick start will require:

1. Select Sol/Ultra for the primary task.
2. Install the one companion Luna profile.
3. Review and trust the plugin hook through `/hooks`.
4. Start a fresh task so the role and hook are loaded.

No active documentation may recommend Terra, Luna/Max, a Sol reviewer subagent, or the
retired `full` route.

## Error handling

- Wrong spawn request: block before execution and return the exact compliant contract.
- Missing or conflicting installed profile: stop before delegation.
- Untrusted or disabled hook: treat Codex's hook warning as inactive enforcement; do
  not claim compliance.
- Runtime metadata mismatch: discard the child result and stop.
- Modified historical agent file: refuse automatic cleanup without touching any
  destination.
- Child reports material ambiguity or architectural risk: return the decision to the
  Sol/Ultra primary task instead of escalating models.

## Verification and acceptance

The repository verifier will cover:

- The manifest release and one-role inventory.
- The Luna/High TOML pin and generic child contract.
- Hook acceptance of the exact role/fresh-context request.
- Hook denial of missing roles, built-in roles, old Sol Advisor roles, model or effort
  overrides, inherited context, and malformed input.
- Clean installation, idempotence, exact historical cleanup, modified-file refusal,
  and zero partial mutation.
- Runtime-inspector fixtures reporting Luna/High and refusing conflicting evidence.
- Consistent docs with no active Terra, Luna/Max, Sol reviewer, or `full` routing.
- JSON/TOML validity, shell syntax, and `git diff --check`.

Release acceptance also requires fresh live smoke tests in Codex CLI and the ChatGPT
desktop app:

1. Enable the checkout plugin and trust its hook.
2. Start a Sol/Ultra primary task.
3. Confirm a conforming child starts and runtime evidence reports Luna/High.
4. Confirm a nonconforming supported spawn is denied before a child is created.
5. Confirm the primary task performs final review and acceptance itself.

The release must report separately what was source-verified, installed, trusted, and
live-smoke-tested on each surface.
