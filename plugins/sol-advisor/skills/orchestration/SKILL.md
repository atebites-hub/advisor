---
name: orchestration
description: "Codex-native routing with a Sol / Ultra primary task, Luna / High children, and primary-task review."
---

# Sol Advisor Orchestration

Act as the architect and final reviewer. Own the user's intent, architecture, route,
decomposition, material judgment, parent verification, review, and acceptance. Routes
are exactly `solo`, `delegate`, and `audit`. Solo is the default.
One child is the default maximum; use more only for explicitly independent parallel work.

Read [references/role-contracts.md](references/role-contracts.md) before native
delegation. Read [references/odw.md](references/odw.md) before using Open Dynamic
Workflows. Use [references/operations.md](references/operations.md) for hook trust,
preflight, runtime evidence, migration, and release procedures.

## Confirm the primary task

Run the primary Codex task on gpt-5.6-sol with ultra reasoning. Verify model and effort
when runtime metadata exposes them. If either differs, stop before task tools and ask
the user to select Sol / Ultra. If effort is not observable, ask the user to confirm it
and stop until confirmed. A skill cannot change the primary model or effort.

## Declare the route before task tools

Emit exactly one declaration before the first task tool call:

~~~text
SELECTIVE ROUTE
mode: solo | delegate | audit
risk: concise task-specific rationale
~~~

No task tool call may precede this declaration. Choose `solo` unless delegation or a
review-only task has a concrete benefit. Change the route only when new evidence
justifies it; record that evidence and never silently downgrade.

## Use only the Luna / High child

For any delegation, verify the installed role with `install-agents.sh --check
--check-role luna`. Treat an untrusted or disabled plugin hook as inactive enforcement
and stop before delegation. Spawn exactly:

~~~text
agent_type: sol_advisor_luna_subagent
fork_turns: none
~~~

Do not attach model or reasoning overrides. Public spawn metadata is authoritative for
role, model, and effort. Use the local runtime inspector only for omitted fields. The
accepted tuple is `sol_advisor_luna_subagent`, `gpt-5.6-luna`, and `high`; missing or
conflicting evidence invalidates the child result.

## Route delivery

- `solo`: implement, test, verify, and self-review in the primary task; spawn no child.
- `delegate`: give one Luna / High child a complete bounded packet; then inspect its
  complete output, rerun verification, review, and accept or reject it in the primary
  task.
- `audit`: review the target directly in the primary task. A Luna / High child may
  gather bounded evidence but cannot render the verdict.

Keep judgment-heavy, high-risk, architectural, ambiguous, or wide-blast-radius work in
the Sol / Ultra primary task. Child work substitutes for primary-task work; do not
duplicate it.

## Use ODW only for scaled or rerunnable work

Open Dynamic Workflows is an execution mechanism within `delegate` or `audit`, never a
fourth route. Use it only when its own scale or repeatability criteria apply. Confirm
enabled ODW v0.2.0, author every model node through the immutable Luna / High wrapper in
`references/odw.md`, and prohibit ZCode or mixed executors.

Inspect the exact completed run before using any result. Missing, cached, failed, or
conflicting trace and rollout evidence invalidates the whole run. A Luna synthesis is
only a draft; the Sol / Ultra primary task performs final review and acceptance.

## Specify and verify every child task

Every child packet contains OBJECTIVE, FILES AND OWNERSHIP, INTERFACES, CONSTRAINTS,
VERIFICATION, and the structured return defined in the role contracts. State exact
owned files, preserve concurrent edits, and do not widen scope.

Treat child reports as claims. Inspect the complete diff or artifact, verify changed
scope, rerun requested checks, and confirm runtime evidence. The primary task performs
final review after every correction; no reviewer child exists.

## State the platform boundary truthfully

The trusted plugin hook blocks supported `spawn_agent` calls, including the `Agent`
alias and code-mode calls. It is not an unbypassable platform policy: disabled,
untrusted, failed, or specialized opt-out paths are outside the guard. Never claim
enforcement without observed hook trust and runtime evidence.

ODW launches independent `codex exec` subprocesses outside the native spawn hook. Its
Sol Advisor boundary is locked authoring plus fail-closed post-run acceptance, not a
pre-spawn platform policy or a modification to ODW.
