#!/bin/sh
# Emit primary or bounded-worker context from validated SessionStart input.

set -eu

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "the jq dependency is unavailable."

plugin_root=${PLUGIN_ROOT-}
case "$plugin_root" in
  /*) ;;
  *) fail "PLUGIN_ROOT must be an absolute directory." ;;
esac

primary_skill=$plugin_root/skills/orchestration/SKILL.md
[ -f "$primary_skill" ] || fail "the canonical orchestration skill is unavailable."

payload=$(cat)
model=$(printf '%s\n' "$payload" | jq -ers '
  if length == 1 and (.[0] | type) == "object" and
    .[0].hook_event_name == "SessionStart" and
    (.[0].source == "startup" or .[0].source == "resume" or .[0].source == "clear" or .[0].source == "compact")
  then .[0].model
  else empty
  end
  | select(type == "string" and length > 0)
' 2>/dev/null) || fail "invalid SessionStart input."

if [ "$model" = gpt-5.6-luna ]; then
  cat <<'EOF'
# Sol Advisor Luna / High Worker

Act only as a bounded execution worker. Complete the supplied objective within its
explicit ownership, interfaces, constraints, and verification requirements.

- Do not act as the primary architect or broaden the settled scope.
- Do not spawn subagents or launch nested agent workflows.
- Do not render the final verdict or accept your own result.
- Preserve concurrent edits and never revert unrelated work.
- Return actual changes, exact verification evidence, judgment calls, and gaps.

The outer GPT-5.6 Sol / Ultra task owns architecture, material judgment, independent
verification, final review, and acceptance. Your active High effort must be proven from
runtime metadata; this context does not select or prove reasoning effort.
EOF
else
  cat "$primary_skill"
fi
