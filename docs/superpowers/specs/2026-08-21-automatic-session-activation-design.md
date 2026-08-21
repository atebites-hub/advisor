# Automatic Sol Advisor Session Activation

Status: design approved on 2026-08-21.

## Decision

When the Sol Advisor plugin is enabled and its hooks are trusted, every fresh Codex CLI
or ChatGPT desktop Codex task automatically receives the existing orchestration skill
as developer context. The user no longer needs to type
`$sol-advisor:orchestration`.

This is an activation change only. The existing Sol/Ultra primary-task contract,
Luna/High custom child, and deny-first spawn guard remain unchanged.

## Goals

1. Activate Sol Advisor automatically at the start of every fresh supported task.
2. Restore the same contract after resume, clear, or compaction.
3. Keep one source of truth by injecting the existing orchestration skill instead of
   duplicating its policy in a new prompt.
4. Preserve current Luna/High spawn enforcement and Sol/Ultra final review.
5. Verify ordinary prompts work without an explicit skill invocation in both Codex CLI
   and the ChatGPT desktop Codex experience.

## Non-goals and boundaries

- The plugin will not edit global Codex configuration.
- The plugin cannot select the primary model or reasoning effort. The user still starts
  the primary task on GPT-5.6 Sol / Ultra, and the injected skill retains its existing
  mismatch behavior.
- Hook input documents the active model but not reasoning effort, so this change does
  not claim machine-verifiable Ultra enforcement.
- Hook review remains a deliberate platform security step. Installation or upgrade
  does not automatically trust a new hook definition.
- The companion Luna profile remains required. This change does not replace native
  custom-agent installation with per-spawn overrides.
- Disabled, untrusted, failed, or specialized hook-bypass paths remain outside the
  enforcement boundary.

Official basis: [Codex hooks](https://learn.chatgpt.com/docs/hooks) documents that
`SessionStart` output becomes developer context, supports `startup`, `resume`, `clear`,
and `compact` sources, and requires non-managed hooks to be reviewed and trusted.

## Approaches considered

### 1. `SessionStart` injection — selected

Add one synchronous `SessionStart` handler that outputs the current orchestration
`SKILL.md`. Codex adds its plain stdout as developer context before the model request.
This is the smallest change that makes activation global and automatic while keeping
the skill as the sole policy source.

### 2. Reinject on every `UserPromptSubmit` — rejected

This would repeat the same contract on every turn, consume context, and risk duplicate
route declarations. `SessionStart` already runs again after resume, clear, and
compaction.

### 3. Add hard prompt/tool gates or spawn rewriting — rejected

More hooks could block all work on the wrong primary model or silently rewrite child
requests. They still could not verify Ultra through the documented hook input and would
expand the current deny-first design. They are unnecessary for automatic activation.

## Architecture and data flow

The plugin's default `hooks/hooks.json` gains a `SessionStart` matcher for:

```text
startup|resume|clear|compact
```

Its command reads `${PLUGIN_ROOT}/skills/orchestration/SKILL.md` and writes that content
to stdout. No new runtime dependency or duplicate orchestration file is introduced.

The task flow becomes:

```text
fresh or restored primary task
  -> trusted SessionStart hook
  -> orchestration SKILL.md added as developer context
  -> primary confirms Sol/Ultra and declares solo, delegate, or audit
  -> existing PreToolUse guard permits only the exact fresh Luna/High child
  -> Sol/Ultra primary verifies and performs final review
```

The existing `PreToolUse` handler remains responsible only for supported subagent
spawn enforcement. `SessionStart` is responsible only for automatic policy activation.
Keeping those responsibilities separate makes failures and hook trust state easy to
diagnose.

## Error handling

- Untrusted or disabled activation hook: Codex skips it; documentation requires `/hooks`
  review and a fresh task before claiming automatic activation.
- Missing or unreadable skill file: the `SessionStart` command fails visibly; it must
  not inject a partial replacement policy.
- Wrong primary model: the injected skill stops before task tools and asks the user to
  select Sol / Ultra.
- Missing Luna profile or inactive spawn guard: the existing delegation preflight stops
  before spawning.
- Compaction or resume: `SessionStart` reinjects the same canonical skill rather than a
  shortened copy.

## Files and release scope

- `plugins/sol-advisor/hooks/hooks.json`: add the `SessionStart` handler.
- `plugins/sol-advisor/scripts/verify.sh`: validate the matcher, command, canonical
  skill output, and unchanged spawn guard.
- `README.md`: describe automatic activation, hook trust, and the remaining manual
  Sol/Ultra selection.
- `plugins/sol-advisor/skills/orchestration/references/operations.md`: distinguish the
  activation hook from spawn enforcement and document preflight behavior.
- `plugins/sol-advisor/.codex-plugin/plugin.json`: bump the patch release and update
  activation wording.
- `plugins/sol-advisor/skills/orchestration/agents/openai.yaml`: remove the obsolete
  explicit-invocation prompt and describe automatic routing.

No Luna profile, installer, runtime-inspector, role-contract, or orchestration-policy
change is part of this release.

## Verification and acceptance

Repository verification must prove:

- Valid JSON and shell syntax.
- Exactly one `SessionStart` handler with the four intended sources.
- The handler emits the canonical orchestration skill rather than duplicated prose.
- The existing conforming Luna spawn still passes.
- Existing wrong-role, inherited-context, and override cases remain denied.
- Manifest and verifier release expectations agree.
- `git diff --check` passes.

Live release acceptance requires new tasks after trusting the updated hook:

1. In Codex CLI, submit an ordinary coding request without naming Sol Advisor and
   observe the route declaration before task tools.
2. Repeat in a fresh ChatGPT desktop Codex task.
3. Confirm a valid child reports Luna/High and a generic or wrong-role spawn is denied.
4. Confirm the Sol/Ultra primary performs final verification and review.
5. Confirm a pre-upgrade task is not presented as evidence for the new activation
   behavior.

Source verification, installed state, hook trust, CLI smoke, and desktop smoke must be
reported separately.
