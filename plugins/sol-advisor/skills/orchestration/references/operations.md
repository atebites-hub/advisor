# Native operations

This is the maintainer and operator reference for Sol Advisor's native custom-agent
workflow. Keep the README user-facing; use this page when installing, delegating,
inspecting routing, or validating a release.

## Role pin and spawn contract

| Role type | Model | Effort | Use |
|---|---|---|---|
| sol_advisor_luna_subagent | gpt-5.6-luna | high | Bounded implementation, research, evidence, and testing |

~~~text
agent_type: sol_advisor_luna_subagent
fork_turns: none
~~~

Do not attach model or reasoning overrides.

## Automatic activation, hook trust, and boundary

The plugin's synchronous `SessionStart` hook emits the canonical orchestration
`SKILL.md` as developer context on `startup`, `resume`, `clear`, and `compact`. The
separate synchronous `PreToolUse` hook denies supported child spawns that do not use
the exact contract above.

Review and trust both lifecycle behaviors through `/hooks` after installation or every
hook definition change, then start a fresh task. Disabled, untrusted, failed, and
specialized opt-out paths are not covered; runtime evidence remains required. The
hooks do not select or prove the primary task's reasoning effort.

## Installation and migration

At installation or update time, run:

~~~sh
sh plugins/sol-advisor/scripts/install-agents.sh
sh plugins/sol-advisor/scripts/install-agents.sh --check
~~~

The installer creates one Luna / High profile and removes only byte-exact historical
Sol Advisor profiles. Any modified, unsafe, unreadable, or conflicting destination
stops the whole preflight before mutation. Unrelated agent files remain untouched.

When operating from an installed skill, resolve the same script relative to this
reference's parent skill:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
installer="$skill_dir/../../scripts/install-agents.sh"
sh "$installer" --check
~~~

## Route preflight

The primary task must be Sol / Ultra. `solo` needs no child. `delegate` and any `audit`
evidence child require `install-agents.sh --check --check-role luna`. Cache a successful
check only for the current task and invalidate it after installation or configuration
changes.

## Accepted runtime evidence

Public spawn details are authoritative. When they omit model or effort, run the
repository-relative `../../scripts/inspect-agent-runtime.sh` for the exact child thread.
Accept only `sol_advisor_luna_subagent`, `gpt-5.6-luna`, and `high`. Missing,
conflicting, or different evidence invalidates the result; the inspector is not a
model-selection fallback.

When operating from an installed skill, resolve the helper relative to this reference's
parent skill and inspect the exact native thread ID:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
runtime_inspector="$skill_dir/../../scripts/inspect-agent-runtime.sh"
sh "$runtime_inspector" <native-subagent-thread-id>
~~~

For a disposable fixture or non-default session root:

~~~sh
sh "$runtime_inspector" --sessions-dir /absolute/path/to/sessions <native-subagent-thread-id>
~~~

The helper searches one exact rollout filename suffix and emits only allowlisted
routing fields. It refuses invalid IDs, zero/multiple matches, missing fields, or
conflicting model/effort/sandbox/permission/working-directory values. It never prints
prompts, messages, environment variables, tokens, configuration, or arbitrary rollout
payloads.

## Parent acceptance

Every child receives the five-part packet from role-contracts.md. The Sol / Ultra
primary task owns architecture, diff or artifact inspection, verification reruns,
corrections, final review, and acceptance. A child never renders the final verdict.

## Maintainer verification

From the repository root, run:

~~~sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git status --short
git diff --stat
~~~

The v0.7.1 verifier covers automatic canonical `SessionStart` context, one role, spawn
guard fixtures, Luna / High runtime evidence, three routes, JSON/TOML validity, shell
syntax, installer migration safety, and absence of retired workflow references.
