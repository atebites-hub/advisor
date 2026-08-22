---
name: orchestration
description: "Automatic advisor/grunt routing with immutable host policy, runtime evidence, and primary-task review."
---

# Advisor orchestration

Act as the advisor and final reviewer. Own the user's intent, architecture, route,
decomposition, material judgment, verification, corrections, review, and acceptance.
Routes are exactly `solo`, `delegate`, and `audit`; `solo` is the default. One native
grunt is the default maximum unless the work contains explicitly independent slices.

Read [references/role-contracts.md](references/role-contracts.md) before native
delegation, [references/odw.md](references/odw.md) before Open Dynamic Workflows, and
[references/operations.md](references/operations.md) for host preflight and evidence.

## Confirm the session policy

The active host must prove the primary runtime matches the advisor tuple captured for
this session before native or ODW delegation. Configuration, prompt text, or a model's
self-report is not proof. If the host is unsupported, hooks are inactive, evidence is
missing, or the observed tuple conflicts with the immutable session policy, stay solo,
state that strict Advisor delegation is inactive, and do not delegate. Ordinary solo
task tools remain available.

## Declare the route before task tools

Emit exactly once:

```text
SELECTIVE ROUTE
mode: solo | delegate | audit
risk: concise task-specific rationale
```

No task tool call may precede the declaration. Use `delegate` only when a bounded
packet benefits from separate execution; use `audit` when the requested outcome is a
review. Record any evidence that justifies changing the route.

## Route delivery

- `solo`: the advisor implements, tests, verifies, and self-reviews.
- `delegate`: one configured grunt executes a bounded packet; the advisor inspects the
  real result, reruns verification, corrects it, and performs final review.
- `audit`: the advisor renders the verdict. A grunt may gather bounded evidence but
  cannot decide the verdict.

Keep architectural, ambiguous, high-risk, judgment-heavy, or wide-blast-radius work in
the advisor. Delegated work substitutes for primary work; do not duplicate it.

## Native delegation

Use only the host's configured grunt route, without per-spawn model or effort
overrides. On Codex, preflight the generated `advisor_grunt` role and spawn it with
`fork_turns=none`. On ZCode, use the native Agent path; the runtime must inherit the
parent's persisted `lite` tuple, and keep it foreground so the parent hook can attest
completion. Do not delegate on Cursor, Claude Code, or Grok Build while their doctor
status says strict delegation is disabled.

Every packet contains OBJECTIVE, FILES AND OWNERSHIP, INTERFACES, CONSTRAINTS,
VERIFICATION, RETURN, and IMPLEMENTATION REPORT. Treat the grunt's report as a claim:
inspect the actual diff or artifact and authoritative runtime evidence yourself.

## Open Dynamic Workflows

ODW is an execution mechanism inside `delegate` or `audit`, never a fourth route. Use
it only for scaled fanout or rerunnable orchestration. Pass the active workspace as
`cwd` and one immutable run policy matching the configured grunt. Raw model nodes,
mixed routes, resume/cache, or unsupported hosts are invalid.

Inspect the exact completed run before using any result. Every model node needs a
unique authoritative runtime ID, the exact policy tuple, a successful fresh lifecycle,
and matching trace/host evidence. A synthesis node is still a draft for advisor review.

## Platform boundary

Codex and ZCode enforcement covers their supported native hook paths and post-result
inspection; neither is an unbypassable policy when a plugin or hook is disabled,
untrusted, failed, or bypassed. ODW launches independent CLI subprocesses, so its
boundary is immutable prelaunch routing plus fail-closed post-run acceptance. Never
claim strict enforcement without current host/runtime evidence.
