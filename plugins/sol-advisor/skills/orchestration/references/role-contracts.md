# Native advisor/grunt contract

Use this contract only after the current host proves its immutable advisor/grunt
policy and strict native lane are active.

## Route and preflight

Declare `solo`, `delegate`, or `audit` before task tools. `solo` needs no grunt.
Codex delegation requires the installed generated role to pass:

```sh
sh plugins/sol-advisor/scripts/install-agents.sh --check --check-role grunt
```

Its only valid spawn is:

```text
agent_type: advisor_grunt
fork_turns: none
```

ZCode delegation uses its native Agent path without an explicit model or effort; every
child must attest `role=lite`, the parent runtime ID, and the persisted grunt tuple.
Set `run_in_background=false`; background results lack the synchronous completion join
required by the strict lane. Cursor IDE and Cursor CLI have a first-class plugin and
doctor but no supported native or ODW delegation route. Claude Code and Grok Build
have no supported native delegation route.

## Exact route contracts

- `solo`: the advisor implements, verifies, and self-reviews.
- `delegate`: one grunt completes a bounded packet; the advisor verifies and accepts or
  rejects it.
- `audit`: the advisor renders the verdict; a grunt may gather evidence only.

One native grunt is the default maximum. Multiple workers require explicitly
independent parallel slices. High-judgment or architectural work remains primary.

## Required packet

```text
OBJECTIVE
<Observable outcome and why it matters.>

FILES AND OWNERSHIP
You own only:
- <exact file, module, or read-only evidence scope>

You are not alone in the codebase. Preserve concurrent edits, do not revert unrelated
work, and do not modify files outside your ownership.

INTERFACES
- <Signatures, types, schemas, commands, and behavior that must remain compatible.>

CONSTRAINTS
- <Safety boundaries, excluded scope, repository conventions, and settled decisions.>
- Do not spawn subagents or nested workflows.
- Do not render the final verdict or accept your own result.

VERIFICATION
- Run: <exact command>
  Success: <concrete expected result>
- Inspect: <exact file, diff, runtime record, or artifact>
  Success: <concrete expected evidence>

RETURN
Return exact commands and actual evidence. A completion claim without evidence is invalid.

IMPLEMENTATION REPORT
STATUS: complete | partial | blocked
OBJECTIVE: <one-line restatement>
CHANGES: <file-by-file summary from the actual diff>
VERIFIED: <exact commands plus concrete output evidence>
JUDGMENT CALLS: <decisions the packet left open, or none>
GAPS: <unfinished work, ambiguity, or none>
```

## Advisor acceptance

Inspect the actual diff or artifact, confirm ownership, rerun the requested checks,
join the exact child runtime to its parent and immutable policy, and perform final
review. Failed, timed-out, cancelled, incomplete, cached, missing, duplicate, or
conflicting evidence invalidates the result. Corrections require fresh verification
and another advisor review.
