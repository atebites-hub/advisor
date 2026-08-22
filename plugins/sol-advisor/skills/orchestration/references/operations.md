# Advisor operations

This is the operator and maintainer reference. The package ID remains `sol-advisor`;
all user-facing surfaces are Advisor.

## Host status

| Host | Native | ODW | Gate |
|---|---|---|---|
| Codex CLI / ChatGPT Codex app | supported | supported | trusted hooks plus rollout evidence |
| maintained ZCode fork | supported | supported | runtime 0.16.3 attestation plus plugin hooks |
| Cursor | disabled | disabled | resolved effort is not authoritative |
| Claude Code | disabled | disabled | resolved effort is not authoritative |
| Grok Build | disabled | disabled | hook-handler failures are fail-open |
| Grok Bot | excluded | excluded | outside product scope |

Configuration intent is never runtime proof.

## Codex lifecycle

`SessionStart` snapshots the complete configured advisor/grunt policy and fixed-key
SHA-256 fingerprint to a private per-runtime file. Only a brand-new root reads the
current profile; resume, clear, and compaction retain the existing snapshot.

`PreToolUse` leaves ordinary solo tools untouched. Before native or ODW delegation it
verifies the primary rollout against that immutable snapshot. Spawn tools allow only
`agent_type=advisor_grunt`, `fork_turns=none`, and no model/effort override. A primary
tuple mismatch disables delegation without locking the task's ordinary tools.
`SubagentStart` supplies bounded grunt context but cannot block. Post-result acceptance
joins the child runtime ID to its rollout, exact role, parent, policy tuple, and
completed lifecycle.

After install or any hook change, review and trust all Advisor hooks in `/hooks` and
start a fresh session. Disabled, untrusted, crashed, timed-out, malformed, or bypassed
hooks mean the lane is unsupported.

Codex workers launched by the compatible ODW plugin carry its `ODW_HOST=codex` and
`ODW_REQUIRE_CWD=1` markers. They receive bounded-worker context, create no native root
snapshot, and cannot use the native spawn or nested-workflow tools. Their route is
accepted only from the completed ODW run evidence described below.

Install or verify the generated role:

```sh
sh plugins/sol-advisor/scripts/install-agents.sh
sh plugins/sol-advisor/scripts/install-agents.sh --check --check-role grunt
```

The installer stages mode-600 output, refuses modified or unsafe destinations, and
retires only byte-exact files from earlier releases.

## ZCode lifecycle

The enabled plugin owns four required nonsensitive settings. A new root reads them once
and persists an immutable `main`/`lite` policy plus fingerprint. Restored roots retain
their saved policy; all foreground, background, and resumed children inherit the
parent's `lite` route. Advisor does not copy values into host model settings or touch
provider credentials.

The maintained runtime emits one `zcode_runtime_attestation`. Native acceptance
recomputes its four-field policy fingerprint and checks runtime version, `main|lite`
role, parent, source, model, effort, and lifecycle. The strict native lane permits only
foreground delegation because only its parent tool result carries joined terminal
child evidence; background launch remains route-correct but is denied by Advisor.
ZCode plugin hooks must block
missing, crashing, timed-out, malformed, disabled, or conflicting enforcement paths.
The ZCode ODW executor's `ZCODE_ODW_PROTOCOL=1` workers are accepted only with a
runtime-owned standalone ODW attestation and cannot launch nested native agents; their
exact tuple and completion remain subject to post-run ODW inspection.

## Runtime inspectors

Use only the exact runtime/result IDs from the host:

```sh
sh plugins/sol-advisor/scripts/inspect-codex-runtime.sh --mode native --policy SNAPSHOT --role advisor ROOT_ID
sh plugins/sol-advisor/scripts/inspect-codex-runtime.sh --mode native --policy SNAPSHOT --role grunt --result RESULT CHILD_ID
sh plugins/sol-advisor/scripts/inspect-zcode-runtime.sh --mode native --role advisor --config ZCODE_CONFIG < HOOK_PAYLOAD
sh plugins/sol-advisor/scripts/inspect-zcode-runtime.sh --mode native --role grunt --config ZCODE_CONFIG < HOOK_PAYLOAD
```

Inspectors emit only allowlisted routing/lifecycle fields. They reject unsafe paths,
ambiguous records, wrong roles/parents/tuples, policy drift, fallback evidence, and
failed, timed-out, cancelled, or incomplete children.

See `odw.md` for the separate standalone ODW contract. Native grunt evidence is never
accepted as ODW evidence, or vice versa.

## Configuration and removal

The installed `advisor` skill resolves `../../bin/advisor`; no executable is exported
to `PATH`. `configure` and `apply` currently write only Codex-owned Advisor state.
ZCode configuration remains in its plugin record. `doctor` is read-only and reports
capability gates independently. `remove --host codex` is the explicit pre-uninstall
cleanup and refuses any state it cannot prove Advisor owns.

## Maintainer verification and release

```sh
sh plugins/sol-advisor/scripts/verify.sh
find . -name '*.json' -not -path './.git/*' -exec jq empty {} \;
git diff --check
```

Release 0.9.2 only after source checks pass from fresh
`origin/main`, and clean-profile positive and intentional-denial probes pass for Codex,
ZCode, and ODW. Publish releases only after candidate acceptance, then repeat install,
positive route, denial, inspection, and removal from the released artifacts. Cursor,
Claude Code, and Grok Build remain experimental until their named runtime gates are
demonstrably closed.
