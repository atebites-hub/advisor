# Native Codex child contract

Use this contract only with Sol Advisor's role-pinned Luna / High child. It does
not select the primary model or launch a nested CLI.

## Route and preflight

Before task tools, declare `solo`, `delegate`, or `audit`. Confirm Sol / Ultra in the
primary task. `solo` needs no companion check. Any route that spawns a child requires:

~~~sh
sh plugins/sol-advisor/scripts/install-agents.sh --check --check-role luna
~~~

The only valid spawn is:

~~~text
agent_type: sol_advisor_luna_subagent
fork_turns: none
~~~

Omit per-spawn model and effort fields. Require public metadata or inspector evidence
for `sol_advisor_luna_subagent`, `gpt-5.6-luna`, and `high` before accepting the result.

## Exact route contracts

- `solo`: the Sol / Ultra primary task implements, verifies, and self-reviews.
- `delegate`: one Luna / High child completes the bounded packet; the primary task
  inspects, reruns verification, reviews, and accepts or rejects it.
- `audit`: the Sol / Ultra primary task renders the verdict. A Luna / High child may
  gather bounded evidence only.

One child is the default maximum. Multiple children require explicitly independent
parallel work. High-judgment or architectural work remains in the primary task.

## Shared implementation contract

Every Luna child prompt must contain all five sections:

~~~text
OBJECTIVE
<Observable outcome and why it matters.>

FILES AND OWNERSHIP
You own only:
- <exact file or module>

You are not alone in the codebase. Other agents or the user may be editing concurrently.
Preserve their edits, do not revert unrelated work, and adapt to changes already present.
Do not modify files outside your ownership.

INTERFACES
- <Signatures, types, schemas, commands, or behavior that must remain compatible.>

CONSTRAINTS
- <Repository conventions, safety boundaries, excluded scope, and settled decisions.>

VERIFICATION
- Run: <exact command>
  Success: <concrete expected result>
- Inspect: <exact file, diff, or generated artifact>
  Success: <concrete expected evidence>

RETURN
Return exact commands and actual evidence. A completion claim without evidence is invalid.

IMPLEMENTATION REPORT
STATUS: complete | partial | blocked
OBJECTIVE: <one-line restatement>
CHANGES: <file-by-file summary from the actual diff>
VERIFIED: <exact commands plus concrete output evidence>
JUDGMENT CALLS: <decisions the specification left open, or none>
GAPS: <unfinished work, ambiguity, or none>
~~~

## Parent acceptance

The primary task must inspect the actual diff or artifact, confirm owned-file scope,
rerun every requested check, compare public and local runtime evidence when both exist,
and perform final review. Any correction invalidates the prior review and requires
verification plus a new primary-task review. Child claims never replace direct evidence.
