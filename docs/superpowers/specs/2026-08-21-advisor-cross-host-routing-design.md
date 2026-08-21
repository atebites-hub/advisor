# Advisor Cross-Host Routing and ODW Enforcement

Status: design approved on 2026-08-21.

## Decision

Generalize Sol Advisor into a two-role Advisor product for Codex/ChatGPT, Cursor,
Claude Code, Grok Build, and ZCode. Each host has one configured `advisor` tuple and
one configured `grunt` tuple:

```json
{
  "advisor": { "model": "host-specific-model-id", "effort": "level" },
  "grunt": { "model": "host-specific-model-id", "effort": "level" }
}
```

The advisor remains the primary session and owns architecture, material judgment,
verification, final review, and acceptance. Ordinary bounded delegation uses the
host's native subagent facility. Work that independently satisfies Open Dynamic
Workflows' scale or repeatability criteria uses ODW. Every accepted child in either
lane must be proven to have run with the configured grunt model and effort.

The initial Codex profile preserves the current behavior: GPT-5.6 Sol / Ultra as the
advisor and GPT-5.6 Luna / High as the grunt. Other hosts use their own exact model
identifiers and supported effort vocabulary. Advisor does not rank models, translate
marketing names, or silently choose substitutes. A user may configure the same model
for both roles.

Grok Bot is excluded because its product-managed routing does not expose the strict
model-selection and runtime-evidence contract required here. Claude Code's separate,
experimental native Advisor tool is also excluded: this product already places the
configured advisor in the primary session.

For compatibility, the first generalized release keeps the existing repository and
package identifier `sol-advisor`. The user-facing product name becomes Advisor and
the configuration command is `advisor`. Renaming the GitHub repository or package ID
is a separate migration and is not required for this functional release.

## Goals

1. Let users select an exact advisor and grunt model/effort pair per supported host.
2. Make ordinary vibe coding work automatically after configuration and a fresh
   session: solo work stays with the advisor, and delegated work uses only the grunt.
3. Apply the same policy to native subagents and ODW workers.
4. Keep final review and acceptance in the primary advisor session.
5. Fail closed on wrong models, wrong effort, fallback, missing runtime evidence,
   stale ODW evidence, or inactive enforcement hooks.
6. Preserve existing user configuration and keep host-specific changes removable.
7. Upgrade and merge the required ZCode, ODW core, ODW plugin, and Advisor changes in
   dependency order, then prove the published result from fresh installations.

## Non-goals and boundaries

- Advisor is not an operating-system sandbox and cannot prevent users from bypassing
  it through unsupported host paths. Strict enforcement means that Advisor accepts
  results only from verified Advisor-controlled paths.
- Advisor does not add a third reviewer model, a model-ranking service, automatic
  fallback, cost optimization, or cross-host model-name translation.
- Advisor does not take over every task. The primary may work solo when delegation
  does not improve the result.
- ODW remains optional. Its absence disables only the ODW lane.
- Deterministic ODW steps that do not invoke a model are not grunt executions and do
  not need model evidence.
- The ZCode repository's missing GitHub fork badge is metadata, not a runtime
  dependency. Restoring it requires repository recreation or GitHub support and is
  outside the code PRs; the functional requirement is a current, traceable upstream
  merge that preserves the fork's ODW changes.

## Approaches considered

### 1. Prompt-only cross-host guidance -- rejected

One shared skill could tell every host which models to use. This is small but cannot
prove resolved models, detect fallbacks, or stop node-level ODW overrides.

### 2. One new cross-host orchestration runtime -- rejected

A central service could launch and supervise every worker. It would duplicate native
host agents and ODW, add credentials and lifecycle management, and create a new
failure boundary without improving the ordinary user flow.

### 3. Shared policy with native adapters and ODW enforcement -- selected

Advisor owns one logical policy. Thin host-specific integrations enforce it on native
delegation, while ODW enforces the same tuple for repeatable or high-fanout work. This
reuses each host's supported mechanisms and changes ODW only where a run-level
immutable policy is actually needed.

## Architecture

```text
configured advisor/grunt pair
            |
            +-- native lane -- host subagent + hooks + runtime verification
            |
            +-- ODW lane ---- immutable routing policy + traces
                                                     |
                                      final advisor verification
```

Advisor contains the shared role contract, configuration UX, documentation, and a
small integration for each host. An integration has four concrete responsibilities:

1. Write or generate only Advisor-owned configuration and agent files.
2. Verify the primary session against the configured advisor tuple.
3. Restrict supported native delegation to the configured grunt tuple.
4. Inspect host runtime evidence before the primary accepts delegated work.

These responsibilities do not require a new adapter framework. Each host uses small
scripts and templates following its existing plugin conventions. The documentation
uses one configure/doctor workflow, while the actual entry point remains native to
the host: settings UI for Cursor and ZCode, and the `advisor` helper elsewhere.

The host implementations use their native surfaces:

- **Codex/ChatGPT:** existing plugin hooks, custom TOML agent, spawn guard, and local
  runtime metadata. The default profile is Sol / Ultra plus Luna / High.
- **Cursor:** plugin agent definitions and hooks. Any host-selected fallback makes the
  result unacceptable. Support is advertised only if resolved model and effort can
  be observed reliably.
- **Claude Code:** plugin agents plus pre-tool denial and post-tool runtime evidence.
  The experimental Claude Advisor tool stays disabled or outside the supported path.
- **Grok Build:** plugin agents, settings, and hooks, with exact configured model and
  effort verified after execution.
- **ZCode:** its native main/lite roles map to advisor/grunt, hooks are enabled by the
  installation flow, and the maintained fork supplies exact effort and runtime
  attestation needed by both native and ODW paths.

If a host version cannot expose the resolved model and effort, Advisor disables
delegation for that version rather than presenting it as strictly supported. The
primary may continue solo only when its own tuple is verifiable.

## Configuration and installation

The two tuples are the entire public policy in the first release. There are no
fallback lists, per-task overrides, model aliases, or separate reviewer settings.

Cursor and ZCode use their plugin configuration surfaces. Codex/ChatGPT, Claude Code,
and Grok Build use the `advisor configure` helper because their relevant files are
split across host-owned locations. The helper:

1. Accepts exact host model and effort values.
2. Validates them against the installed host's documented capabilities where that
   information is locally available.
3. Renders only Advisor-owned agent, hook, and policy files.
4. Refuses ambiguous collisions instead of overwriting unrelated user content.
5. Reports that configuration takes effect only in new sessions.

A fresh or upgraded Codex installation seeds the existing Sol / Ultra and Luna / High
profile. Other hosts require an explicit complete profile before Advisor activates;
they do not infer an advisor or grunt from the currently selected model.

`advisor doctor` reports each check separately: installed host version, configured
tuples, model/effort availability, generated files, hook trust or enablement, native
agent visibility, ODW compatibility, and effective ODW routing policy. It never
changes configuration. Configuration contains no credentials.

## Native execution flow

1. A fresh session loads the Advisor integration.
2. Before task tools are used, the integration compares the actual primary runtime
   tuple to the configured advisor tuple.
3. A mismatch or unprovable tuple stops the supported workflow and gives the exact
   configuration or model-selection correction.
4. Work that does not need delegation stays in the primary session.
5. Native delegation may create only the Advisor-owned grunt definition. Attempts to
   pass a different model, effort, built-in role, or fallback are denied where the
   host provides a pre-tool hook and rejected everywhere during acceptance.
6. The host records the child identity and resolved runtime tuple.
7. The primary independently checks the evidence and work before accepting it.

Architecture decisions and the final review are never delegated to the grunt. A
grunt may inspect, test, implement a bounded change, or synthesize explicitly scoped
material, but its output is always input to the advisor's judgment.

## ODW policy and execution flow

ODW core gains one optional run-level routing policy containing an exact `executor`,
`model`, and `reasoningEffort`. When present, ODW validates it once and applies those
fields after node options to every model invocation. A node that supplies a
conflicting value is rejected before launch. Nested workflows inherit the policy and
cannot weaken it.

The active host integration supplies `executor`; it is not a third user-configured
role setting. The configured grunt tuple supplies `model` and `reasoningEffort`.

ODW serializes a normalized policy and a SHA-256 fingerprint in the run record using
standard-library facilities. Every agent launch trace records that fingerprint plus
the effective executor/model/effort and child runtime identifier. The fingerprint is
correlation and integrity evidence within the run, not a cryptographic signature or
host security boundary.

The Advisor ODW lane works as follows:

1. The primary decides that ODW is justified by scale or repeatability.
2. Advisor passes the configured grunt tuple as an immutable ODW routing policy.
3. Every model node launches through the selected host executor with that tuple.
4. ODW records the effective route and runtime identifier for each node.
5. Advisor matches every successful node to host runtime evidence and the same policy
   fingerprint.
6. The primary advisor independently verifies the results and performs final review.

The first release rejects cached ODW nodes because their evidence may belong to an
older policy or host runtime. Users can perform a fully live rerun. Proven cache
lineage can be added later only if a concrete use case justifies the added logic.

## Failure handling

### Hard stop before task tools

- The primary tuple is wrong or cannot be observed.
- The profile is missing, malformed, or names an unsupported model/effort.
- Required Advisor hooks are disabled or untrusted.
- Advisor-owned files conflict with an existing installation and cannot be resolved
  without overwriting user content.

### Delegation disabled while verified solo work remains available

- The grunt tuple is unavailable.
- The host cannot attest a native child's resolved model and effort.
- ODW is absent, disabled, or outside the tested compatibility range. This affects
  only the ODW lane; native delegation may remain available.

### Delegated result rejected after execution

- Actual model or effort differs from policy, including a host fallback.
- A child failed, timed out, was cancelled, or has incomplete evidence.
- An ODW node used raw/unpolicy execution, a mixed executor, a cached result, or stale
  trace data.
- A run or node has a missing, duplicate, or mismatched policy fingerprint or runtime
  identity.
- The child attempted to provide final acceptance in place of the advisor.

There is no silent downgrade or automatic substitute. A cancelled or partial run may
be reported as partial evidence but cannot satisfy completion. Configuration changes
never affect already-running sessions.

## Repository responsibilities and PR order

Changes land in dependency order:

1. **`atebites-hub/zcode-cli`:** merge current `kingsword09/zcode-cli` upstream into
   the maintained fork; preserve the ODW protocol, per-process model routing, and
   telemetry patches; add exact effort selection and runtime attestation. Record the
   upstream base and preserved fork commits in the PR.
2. **`atebites-hub/open-dynamic-workflows`:** add the immutable generic routing
   policy, inherited nested-workflow behavior, normalized fingerprint, conflict
   rejection, and trace fields without changing unpolicied workflows.
3. **`atebites-hub/open-dynamic-workflows-plugin`:** update its ODW and ZCode pins,
   rebuild the bundle, and expose the supported host executors and policy behavior.
4. **`atebites-hub/sol-advisor`:** publish the generalized Advisor UX, configuration
   helpers, host templates/hooks/verifiers, ODW integration, migration guidance,
   documentation, and version bump.
5. **Marketplace indexes:** update only indexes required for users to install the new
   versions after repository releases pass fresh-install smoke tests.

Each dependency PR must be green, reviewed, merged, pulled from the resulting default
branch, and reverified before its consumer PR is finalized. Development uses isolated
worktrees and must not alter the existing dirty ODW plugin checkout or discard any
user-owned changes. No force pushes are required.

## Verification

### Repository checks

- **ZCode:** upstream regression suite; fork ODW protocol tests; exact advisor/grunt
  model and effort selection; runtime attestation; disabled-hook denial; preserved
  existing configuration.
- **ODW core:** policy validation; immutable application after node options; nested
  inheritance; pre-launch conflict denial; stable fingerprinting; complete trace
   fields; unchanged behavior for runs without a policy.
- **ODW plugin:** pinned dependency integrity; generated bundle/manifests for every
  supported host; executor smoke tests; clean installation and removal.
- **Advisor:** configuration parsing and collision refusal; generated host files;
  session preflight; native allow/deny guards; runtime inspectors; ODW evidence
  matching; migration from the current Codex profile.

Tests must include intentional failures for wrong model, wrong effort, host fallback,
untrusted or disabled hooks, missing/duplicate runtime evidence, mismatched policy
fingerprints, mixed executors, failed/cancelled workers, cached nodes, stale traces,
and configuration collisions. Failure tests use the exact prohibited action and stop
after proving denial or rejection.

### Live host acceptance

For each advertised host and both CLI/app surfaces where applicable:

1. Install the published plugin into a clean test profile.
2. Configure exact advisor and grunt tuples, then start a fresh session.
3. Prove the primary's actual advisor model and effort from runtime metadata.
4. Complete one small native delegation and prove the child's actual grunt tuple.
5. Complete one small ODW run and prove every model node's actual grunt tuple and
   matching policy fingerprint.
6. Deliberately request a wrong model or effort and prove denial or rejection.
7. Confirm that the primary advisor—not a worker—performed final review.
8. Confirm uninstall or disable leaves unrelated host configuration intact.

A host is documented as experimental or unsupported until every required proof is
available. Agent self-reporting, source configuration, successful exit status, and a
visible task card are not runtime proof.

## Release acceptance

The project is complete only when all applicable stages are true and reported
separately:

1. Focused local tests pass.
2. Every required PR is green and approved.
3. Every required PR is merged to the repository's origin default branch.
4. Version pins, manifests, bundles, and releases point to those merged commits.
5. A fresh installation from the published source succeeds.
6. Positive and intentional-denial live smokes pass on every advertised host.
7. Documentation clearly lists supported, experimental, and excluded paths, with
   Grok Bot explicitly excluded.

If repository permissions, marketplace review, or a host capability prevents one of
these stages, the release is reported at the last proven stage rather than called
done.
