#!/bin/sh
# Install Sol Advisor's shipped custom-agent templates without changing Codex config.

set -eu

usage() {
  cat <<'EOF'
Usage: install-agents.sh [--target-dir PATH] [--check] [--check-role luna]

Install Sol Advisor's one Luna / High subagent profile and retire only byte-exact
Sol Advisor profiles shipped by earlier releases. Never overwrite or remove a
modified, nonregular, unreadable, or symlinked destination.

Without --target-dir, the target is "$CODEX_HOME/agents" when CODEX_HOME is already
set, otherwise "$HOME/.codex/agents".

Options:
  --target-dir PATH  Explicit destination directory (absolute or relative).
  --check            Verify the current profile and absence of retired profiles;
                     do not create, replace, or remove anything.
  --check-role luna  Equivalent Luna-only compatibility spelling for --check.
  --help             Show this help text.
EOF
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

report_preflight_error() {
  printf '%s\n' "ERROR: $*" >&2
  preflight_failed=1
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

sha256_file() {
  shasum -a 256 "$1" 2>/dev/null | awk 'NF >= 1 && length($1) == 64 { print $1; exit }'
}

classify_current() {
  destination=$1
  template=$2
  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  elif cmp -s "$template" "$destination"; then
    printf '%s\n' current
  else
    printf '%s\n' conflict
  fi
}

classify_retired() {
  destination=$1
  known_digests=$2
  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  else
    digest=$(sha256_file "$destination")
    if [ -z "$digest" ]; then
      printf '%s\n' unreadable
      return
    fi
    for known_digest in $known_digests; do
      if [ "$digest" = "$known_digest" ]; then
        printf '%s\n' retired
        return
      fi
    done
    printf '%s\n' conflict
  fi
}

same_state() {
  label=$1
  expected=$2
  actual=$3
  [ "$expected" = "$actual" ] || fail "$label changed after preflight; no further destination files were changed."
}

install_missing() {
  template=$1
  destination=$2
  staged=''

  if path_exists "$destination"; then
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi

  staged=$(mktemp "$target_dir/.sol-advisor-agent.XXXXXX") || fail "could not stage template for installation: $destination"
  if ! cp "$template" "$staged"; then
    rm -f "$staged"
    fail "could not stage template for installation: $destination"
  fi

  if ! ln "$staged" "$destination"; then
    rm -f "$staged"
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi

  rm -f "$staged" || fail "could not remove staged template after installation: $staged"
  printf '%s\n' "INSTALLED: $destination"
}

retire_exact() {
  label=$1
  destination=$2
  known_digests=$3
  [ "$(classify_retired "$destination" "$known_digests")" = retired ] ||
    fail "$label destination changed after preflight and will not be removed: $destination"
  rm "$destination" || fail "could not retire exact $label profile: $destination"
  printf '%s\n' "RETIRED: $destination"
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
template_dir=$script_dir/../agents

if [ -n "${CODEX_HOME-}" ]; then
  target_dir=$CODEX_HOME/agents
else
  [ -n "${HOME-}" ] || fail "HOME is unset and CODEX_HOME was not supplied; pass --target-dir explicitly."
  target_dir=$HOME/.codex/agents
fi

check_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] || fail "--target-dir requires a path."
      [ -n "$2" ] || fail "--target-dir requires a non-empty path."
      case "$2" in
        --*) fail "--target-dir path must be explicit; prefix an option-like relative name with ./ or use an absolute path." ;;
      esac
      target_dir=$2
      shift 2
      ;;
    --check)
      check_only=1
      shift
      ;;
    --check-role)
      [ "$#" -ge 2 ] || fail "--check-role requires the role: luna."
      [ "$2" = luna ] || fail "unknown --check-role '$2'; expected luna."
      check_only=1
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1 (run with --help for usage)."
      ;;
  esac
done

case "$target_dir" in
  /*) ;;
  *) target_dir=$(pwd -P)/$target_dir ;;
esac

case "$target_dir" in
  /|//) fail "refusing to use the filesystem root as an agent target directory." ;;
esac

current_file=sol-advisor-luna-subagent.toml
retired_luna_file=sol-advisor-luna-implementer.toml
retired_terra_file=sol-advisor-terra-implementer.toml
retired_sol_file=sol-advisor-sol-reviewer.toml

current_template=$template_dir/$current_file
current_destination=$target_dir/$current_file
retired_luna_destination=$target_dir/$retired_luna_file
retired_terra_destination=$target_dir/$retired_terra_file
retired_sol_destination=$target_dir/$retired_sol_file

retired_luna_sha256s='fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb 5cfaf77f14757074ca5d3cfecd0b8204c91dc14eff8d6119985c64416ddf4853 12fa9180a292876e6731bc325779123bcd931c3caa902fbf90d676a31833be84'
retired_terra_sha256s='4425a8c1f21ce8c6af93f96adc253bbc33ea301f1389b3fa8ce350be08584eca 06c318e5e93f37452635906394e6ea69fb6a65ba9e6ad7172d37b444e0dc871d dc329fe87f6f6610c13157ec16432f91c79cf5a541ee3e7448f6afb165dd18ce 77ed2f36bb149da5d9032230c3d6f5e5cd56b059b3fa5f59085249bba06e1f3a'
retired_sol_sha256s='0333acf0ef562bcfebd06009ac09bd1dd8cbc04c4cf28e08e9e049bd8bf202d2'

[ -f "$current_template" ] && [ ! -L "$current_template" ] ||
  fail "shipped template is missing or not a regular file: $current_template"

preflight_failed=0
if path_exists "$target_dir"; then
  if [ -L "$target_dir" ] || [ ! -d "$target_dir" ]; then
    report_preflight_error "target directory is not a real directory: $target_dir"
  fi
fi

current_state=$(classify_current "$current_destination" "$current_template")
retired_luna_state=$(classify_retired "$retired_luna_destination" "$retired_luna_sha256s")
retired_terra_state=$(classify_retired "$retired_terra_destination" "$retired_terra_sha256s")
retired_sol_state=$(classify_retired "$retired_sol_destination" "$retired_sol_sha256s")

if [ "$check_only" -eq 1 ]; then
  [ "$current_state" = current ] ||
    report_preflight_error "Luna subagent template is $current_state, not the current exact file: $current_destination"
  [ "$retired_luna_state" = missing ] ||
    report_preflight_error "retired Luna implementer remains $retired_luna_state: $retired_luna_destination"
  [ "$retired_terra_state" = missing ] ||
    report_preflight_error "retired Terra implementer remains $retired_terra_state: $retired_terra_destination"
  [ "$retired_sol_state" = missing ] ||
    report_preflight_error "retired Sol reviewer remains $retired_sol_state: $retired_sol_destination"
else
  case "$current_state" in current|missing) ;; *) report_preflight_error "Luna subagent destination is $current_state and will not be replaced: $current_destination" ;; esac
  case "$retired_luna_state" in retired|missing) ;; *) report_preflight_error "retired Luna destination is $retired_luna_state and will not be removed: $retired_luna_destination" ;; esac
  case "$retired_terra_state" in retired|missing) ;; *) report_preflight_error "retired Terra destination is $retired_terra_state and will not be removed: $retired_terra_destination" ;; esac
  case "$retired_sol_state" in retired|missing) ;; *) report_preflight_error "retired Sol destination is $retired_sol_state and will not be removed: $retired_sol_destination" ;; esac
fi

[ "$preflight_failed" -eq 0 ] || exit 1

if [ "$check_only" -eq 1 ]; then
  printf '%s\n' "CHECK PASSED: the Luna / High subagent profile is current and retired Sol Advisor profiles are absent."
  exit 0
fi

if [ ! -d "$target_dir" ]; then
  mkdir -p "$target_dir" || fail "could not create target directory: $target_dir"
fi
[ -d "$target_dir" ] && [ ! -L "$target_dir" ] ||
  fail "target directory changed after preflight: $target_dir"

same_state "Luna subagent" "$current_state" "$(classify_current "$current_destination" "$current_template")"
same_state "retired Luna" "$retired_luna_state" "$(classify_retired "$retired_luna_destination" "$retired_luna_sha256s")"
same_state "retired Terra" "$retired_terra_state" "$(classify_retired "$retired_terra_destination" "$retired_terra_sha256s")"
same_state "retired Sol" "$retired_sol_state" "$(classify_retired "$retired_sol_destination" "$retired_sol_sha256s")"

case "$current_state" in
  missing) install_missing "$current_template" "$current_destination" ;;
  current) printf '%s\n' "ALREADY CURRENT: $current_destination" ;;
esac
case "$retired_luna_state" in retired) retire_exact "Luna implementer" "$retired_luna_destination" "$retired_luna_sha256s" ;; esac
case "$retired_terra_state" in retired) retire_exact "Terra implementer" "$retired_terra_destination" "$retired_terra_sha256s" ;; esac
case "$retired_sol_state" in retired) retire_exact "Sol reviewer" "$retired_sol_destination" "$retired_sol_sha256s" ;; esac

[ "$(classify_current "$current_destination" "$current_template")" = current ] ||
  fail "post-install exactness check failed: $current_destination"
for retired_destination in "$retired_luna_destination" "$retired_terra_destination" "$retired_sol_destination"; do
  if path_exists "$retired_destination"; then
    fail "post-install retired profile remains: $retired_destination"
  fi
done

printf '%s\n' "INSTALL PASSED: the Luna / High subagent profile is current and retired Sol Advisor profiles are absent."
