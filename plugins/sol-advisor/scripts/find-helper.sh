#!/bin/sh
set -eu

fail() { printf '%s\n' "ERROR: $*" >&2; exit 1; }

path_exists() { [ -e "$1" ] || [ -L "$1" ]; }

is_helper() {
  [ -f "$1" ] && [ ! -L "$1" ] && [ -x "$1" ]
}

emit_if_helper() {
  candidate=$1
  [ -n "$candidate" ] || return 1
  case "$candidate" in /*) ;; *) return 1 ;; esac
  if is_helper "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

# Resolve the packaged Advisor helper. Plugin installation never exports `advisor`
# onto PATH; callers must run this file or the skill/command that locates it.
if [ -n "${CURSOR_PLUGIN_ROOT-}" ] && emit_if_helper "$CURSOR_PLUGIN_ROOT/plugins/sol-advisor/bin/advisor"; then
  exit 0
fi
if [ -n "${PLUGIN_ROOT-}" ]; then
  if emit_if_helper "$PLUGIN_ROOT/bin/advisor"; then exit 0; fi
  if emit_if_helper "$PLUGIN_ROOT/plugins/sol-advisor/bin/advisor"; then exit 0; fi
fi

if [ -n "${HOME-}" ]; then
  if emit_if_helper "$HOME/.cursor/plugins/local/sol-advisor/plugins/sol-advisor/bin/advisor"; then
    exit 0
  fi
fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
if emit_if_helper "$script_dir/../bin/advisor"; then exit 0; fi

fail "could not resolve the packaged Advisor helper; install to ~/.cursor/plugins/local/sol-advisor or set CURSOR_PLUGIN_ROOT."
