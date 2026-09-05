#!/bin/sh
set -eu

fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: smoke-odw-one-leaf.sh --host codex|zcode [--checkout PATH] [--run-dir PATH]' \
    '' \
    'Fail-closed one-leaf ODW seating smoke. Does not soft-pass.' \
    'This script does not auto-launch a run. Session-gated: launch a one-leaf ODW' \
    'workflow() first (MCP or equivalent host path), then inspect or smoke:' \
    '  inspect-odw-run.sh --host <codex|zcode> /absolute/.odw/.../runs/run-ID' \
    '  smoke-odw-one-leaf.sh --host <codex|zcode> --run-dir /absolute/.odw/.../runs/run-ID' \
    'If the ODW checkout is missing, prints:' \
    '  git submodule update --init plugins/open-dynamic-workflows' \
    'After that submodule exists, re-run this script. compatible=true still' \
    'requires install/enable open-dynamic-workflows@0.3.0 on the chosen host.'
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
advisor=$script_dir/../bin/advisor
inspector=$script_dir/inspect-odw-run.sh
odw_required_version=0.3.0
submodule_init='git submodule update --init plugins/open-dynamic-workflows'
host= checkout= run_dir=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host|--checkout|--run-dir)
      option=$1
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "$option requires a value."
      case "$2" in --*) fail "$option requires an explicit value." ;; esac
      case "$option" in
        --host) [ -z "$host" ] || fail "duplicate --host."; host=$2 ;;
        --checkout) [ -z "$checkout" ] || fail "duplicate --checkout."; checkout=$2 ;;
        --run-dir) [ -z "$run_dir" ] || fail "duplicate --run-dir."; run_dir=$2 ;;
      esac
      shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown or positional argument: $1" ;;
  esac
done
case "$host" in
  codex|zcode) ;;
  '') fail "--host is required (codex or zcode). This script does not guess." ;;
  *) fail "unsupported smoke host: $host (codex or zcode only)." ;;
esac
[ -x "$advisor" ] || fail "Advisor helper is missing: $advisor"
[ -x "$inspector" ] || fail "ODW inspector is missing: $inspector"
command -v jq >/dev/null 2>&1 || fail "jq is unavailable."

odw_manifest_complete() {
  [ -n "$1" ] && [ -d "$1" ] && [ ! -L "$1" ] && {
    [ -f "$1/package.json" ] || [ -f "$1/.codex-plugin/plugin.json" ] || [ -f "$1/.zcode-plugin/plugin.json" ]
  }
}

missing_checkout() {
  printf '%s\n' \
    'FAIL: Open Dynamic Workflows checkout is missing or uninitialized.' \
    "From the marketplace/box root run: $submodule_init" \
    'Then re-run this script. This is not a pass.' >&2
  exit 1
}

resolve_checkout() {
  if [ -n "$checkout" ]; then
    odw_checkout=$checkout
    return 0
  fi
  if [ -n "${ODW_CHECKOUT-}" ]; then
    odw_checkout=$ODW_CHECKOUT
    return 0
  fi
  dir=$(pwd -P)
  while :; do
    candidate=$dir/plugins/open-dynamic-workflows
    if [ -e "$candidate" ] || [ -L "$candidate" ]; then
      odw_checkout=$candidate
      return 0
    fi
    parent=$(dirname "$dir")
    [ "$parent" = "$dir" ] && break
    dir=$parent
  done
  advisor_root=$(CDPATH= cd "$script_dir/../.." && pwd) || return 1
  sibling=$advisor_root/../open-dynamic-workflows
  if [ -e "$sibling" ] || [ -L "$sibling" ]; then
    case "$sibling" in /*) odw_checkout=$sibling ;; *) odw_checkout=$(CDPATH= cd "$sibling" && pwd) ;; esac
    return 0
  fi
  return 1
}

resolve_checkout || missing_checkout
case "$odw_checkout" in /*) ;; *) odw_checkout=$(pwd -P)/$odw_checkout ;; esac
[ -L "$odw_checkout" ] && fail "ODW checkout must not be a symlink: $odw_checkout"
odw_manifest_complete "$odw_checkout" || missing_checkout

odw_version=
for manifest in "$odw_checkout/package.json" \
  "$odw_checkout/.codex-plugin/plugin.json" \
  "$odw_checkout/.zcode-plugin/plugin.json"
do
  [ -f "$manifest" ] && [ ! -L "$manifest" ] || continue
  odw_version=$(jq -r '.version // empty' "$manifest") || fail "ODW manifest is not readable JSON: $manifest"
  [ -n "$odw_version" ] && break
done
[ "$odw_version" = "$odw_required_version" ] ||
  fail "ODW checkout version is ${odw_version:-missing}, required $odw_required_version (install/enable open-dynamic-workflows@0.3.0; this is not a version-bump pass)."

printf '%s\n' "ODW checkout: $odw_checkout (version $odw_version)"

doctor_json=$(sh "$advisor" doctor --host "$host" --json || true)
printf '%s\n' "$doctor_json" | jq -e --arg host "$host" 'type == "object" and .schemaVersion == 1 and .host == $host' >/dev/null 2>&1 ||
  fail "doctor --host $host did not return Advisor JSON."
printf '%s\n' "$doctor_json"
code=$(printf '%s\n' "$doctor_json" | jq -r '.code')
compatible=$(printf '%s\n' "$doctor_json" | jq -r '.checks.odwPlugin.compatible')
if [ "$code" = plugin_settings_required ]; then
  fail "doctor code=plugin_settings_required; run \`advisor apply --host zcode\` (or configure) so Advisor settings are present."
fi
if [ "$compatible" != true ]; then
  fail "odwPlugin.compatible=false; install/enable open-dynamic-workflows@0.3.0 on $host. Marketplace package.json at 0.3.0 is not enough."
fi

if [ -z "$run_dir" ] && [ -n "${ODW_RUN_DIR-}" ]; then
  run_dir=$ODW_RUN_DIR
fi
if [ -z "$run_dir" ]; then
  found=
  for candidate in .odw/*/runs/run-*; do
    [ -d "$candidate" ] || continue
    [ -z "$found" ] || fail "multiple ODW runs under .odw/; pass --run-dir for the one-leaf run."
    found=$candidate
  done
  [ -n "$found" ] || fail "no one-leaf ODW run to inspect. Launch a one-leaf workflow, then re-run with --run-dir /absolute/.odw/.../runs/run-ID."
  case "$found" in /*) run_dir=$found ;; *) run_dir=$(pwd -P)/$found ;; esac
fi
case "$run_dir" in /*) ;; *) fail "run directory must be absolute: $run_dir" ;; esac
[ -d "$run_dir" ] && [ ! -L "$run_dir" ] || fail "run directory is missing or unsafe: $run_dir"

summary=$(sh "$inspector" --host "$host" "$run_dir") || fail "inspect-odw-run.sh rejected $run_dir"
printf '%s\n' "$summary"
printf '%s\n' "$summary" | jq -e --arg host "$host" '
  .host == $host and .agent_count == 1 and
  all(.agents[]; .state == "completed" and (.model | type == "string" and length > 0) and (.effort | type == "string" and length > 0))
' >/dev/null || fail "run is not a completed one-leaf ODW seating (agent_count must be 1)."
printf '%s\n' "PASS: one-leaf ODW seating on $host"
