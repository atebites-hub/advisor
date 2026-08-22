#!/bin/sh
set -eu

usage() {
  printf '%s\n' \
    'Usage: install-agents.sh [--target-dir PATH] [--profile PATH] [--check] [--check-role grunt]' \
    '' \
    'Render and install Advisor\x27s one configured Codex grunt role. Retire only' \
    'byte-exact profiles shipped by earlier Advisor releases.'
}

fail() { printf '%s\n' "ERROR: $*" >&2; exit 1; }
report_preflight_error() { printf '%s\n' "ERROR: $*" >&2; preflight_failed=1; }
path_exists() { [ -e "$1" ] || [ -L "$1" ]; }
sha256_file() { shasum -a 256 "$1" 2>/dev/null | awk 'NF >= 1 && length($1) == 64 { print $1; exit }'; }
file_mode() { stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1" 2>/dev/null; }
valid_model() { printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:+/-]{0,255}$'; }
valid_effort() { printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'; }

classify_current() {
  destination=$1 rendered=$2
  if ! path_exists "$destination"; then printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then printf '%s\n' unsafe
  elif cmp -s "$rendered" "$destination" && [ "$(file_mode "$destination")" = 600 ]; then printf '%s\n' current
  else printf '%s\n' conflict
  fi
}

classify_retired() {
  destination=$1 known_digests=$2
  if ! path_exists "$destination"; then printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then printf '%s\n' unsafe
  else
    digest=$(sha256_file "$destination")
    [ -n "$digest" ] || { printf '%s\n' unreadable; return; }
    for known_digest in $known_digests; do
      if [ "$digest" = "$known_digest" ]; then printf '%s\n' retired; return; fi
    done
    printf '%s\n' conflict
  fi
}

same_state() {
  label=$1 expected=$2 actual=$3
  [ "$expected" = "$actual" ] || fail "$label changed after preflight; no further destination files were changed."
}

install_missing() {
  rendered=$1 destination=$2 staged=
  path_exists "$destination" && fail "destination changed after preflight and will not be overwritten: $destination"
  staged=$(mktemp "$target_dir/.advisor-agent.XXXXXX") || fail "could not stage role: $destination"
  if ! cp "$rendered" "$staged" || ! chmod 600 "$staged"; then rm -f "$staged"; fail "could not stage role: $destination"; fi
  if ! ln "$staged" "$destination"; then rm -f "$staged"; fail "destination changed after preflight: $destination"; fi
  rm -f "$staged" || fail "could not remove staged role: $staged"
  printf '%s\n' "INSTALLED: $destination"
}

retire_exact() {
  label=$1 destination=$2 known_digests=$3
  [ "$(classify_retired "$destination" "$known_digests")" = retired ] ||
    fail "$label destination changed after preflight and will not be removed: $destination"
  rm "$destination" || fail "could not retire exact $label profile: $destination"
  printf '%s\n' "RETIRED: $destination"
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
template=$plugin_dir/templates/codex-advisor-grunt.toml.in

if [ -n "${ADVISOR_AGENT_DIR-}" ]; then target_dir=$ADVISOR_AGENT_DIR
elif [ -n "${CODEX_HOME-}" ]; then target_dir=$CODEX_HOME/agents
else
  [ -n "${HOME-}" ] || fail "HOME is unset; pass --target-dir explicitly."
  target_dir=$HOME/.codex/agents
fi

if [ -n "${ADVISOR_CONFIG_HOME-}" ]; then profile_path=$ADVISOR_CONFIG_HOME/codex.json
elif [ -n "${XDG_CONFIG_HOME-}" ]; then profile_path=$XDG_CONFIG_HOME/advisor/codex.json
else [ -n "${HOME-}" ] || fail "HOME is unset; pass --profile explicitly."; profile_path=$HOME/.config/advisor/codex.json
fi

check_only=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "--target-dir requires a path."
      case "$2" in --*) fail "--target-dir requires an explicit path." ;; esac
      target_dir=$2; shift 2 ;;
    --profile)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "--profile requires a path."
      case "$2" in --*) fail "--profile requires an explicit path." ;; esac
      profile_path=$2; shift 2 ;;
    --check) check_only=1; shift ;;
    --check-role)
      [ "$#" -ge 2 ] || fail "--check-role requires grunt."
      case "$2" in grunt|luna) ;; *) fail "unknown --check-role '$2'; expected grunt." ;; esac
      check_only=1; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

case "$target_dir" in /*) ;; *) target_dir=$(pwd -P)/$target_dir ;; esac
case "$profile_path" in /*) ;; *) profile_path=$(pwd -P)/$profile_path ;; esac
case "$target_dir" in /|//) fail "refusing the filesystem root as an agent directory." ;; esac

[ -f "$template" ] && [ ! -L "$template" ] || fail "shipped role template is missing or unsafe: $template"
grunt_model=gpt-5.6-luna
grunt_effort=high
if path_exists "$profile_path"; then
  [ -f "$profile_path" ] && [ ! -L "$profile_path" ] && [ -r "$profile_path" ] || fail "profile is unsafe: $profile_path"
  command -v jq >/dev/null 2>&1 || fail "jq is required to read the Advisor profile."
  jq -e '
    type == "object" and keys == ["advisor","grunt","host","schemaVersion"] and
    .schemaVersion == 1 and .host == "codex" and
    (.advisor | type == "object" and keys == ["effort","model"]) and
    (.grunt | type == "object" and keys == ["effort","model"])
  ' "$profile_path" >/dev/null 2>&1 || fail "profile schema is invalid: $profile_path"
  grunt_model=$(jq -r '.grunt.model' "$profile_path")
  grunt_effort=$(jq -r '.grunt.effort' "$profile_path")
fi
valid_model "$grunt_model" || fail "profile grunt model is unsafe."
valid_effort "$grunt_effort" || fail "profile grunt effort is unsafe."

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_base=$(CDPATH= cd "$tmp_base" && pwd -P)
rendered=$(mktemp "$tmp_base/advisor-grunt.XXXXXX") || fail "could not create rendered role"
cleanup() { case "${rendered-}" in "$tmp_base"/advisor-grunt.*) rm -f "$rendered" ;; esac; }
trap cleanup 0 HUP INT TERM
sed -e "s|@GRUNT_MODEL@|$grunt_model|g" -e "s|@GRUNT_EFFORT@|$grunt_effort|g" "$template" > "$rendered" ||
  fail "could not render configured role"
chmod 600 "$rendered" || fail "could not secure rendered role"

current_destination=$target_dir/advisor-grunt.toml
retired_luna_subagent=$target_dir/sol-advisor-luna-subagent.toml
retired_luna=$target_dir/sol-advisor-luna-implementer.toml
retired_terra=$target_dir/sol-advisor-terra-implementer.toml
retired_sol=$target_dir/sol-advisor-sol-reviewer.toml

retired_luna_subagent_sha256s='7efae829b44a3e68f75d6f0f4988c8192502f7bdf0fb06c4802482b4ac7f497f'
retired_luna_sha256s='fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb 5cfaf77f14757074ca5d3cfecd0b8204c91dc14eff8d6119985c64416ddf4853 12fa9180a292876e6731bc325779123bcd931c3caa902fbf90d676a31833be84'
retired_terra_sha256s='4425a8c1f21ce8c6af93f96adc253bbc33ea301f1389b3fa8ce350be08584eca 06c318e5e93f37452635906394e6ea69fb6a65ba9e6ad7172d37b444e0dc871d dc329fe87f6f6610c13157ec16432f91c79cf5a541ee3e7448f6afb165dd18ce 77ed2f36bb149da5d9032230c3d6f5e5cd56b059b3fa5f59085249bba06e1f3a'
retired_sol_sha256s='0333acf0ef562bcfebd06009ac09bd1dd8cbc04c4cf28e08e9e049bd8bf202d2'

preflight_failed=0
if path_exists "$target_dir" && { [ -L "$target_dir" ] || [ ! -d "$target_dir" ]; }; then
  report_preflight_error "target directory is not a real directory: $target_dir"
fi
current_state=$(classify_current "$current_destination" "$rendered")
subagent_state=$(classify_retired "$retired_luna_subagent" "$retired_luna_subagent_sha256s")
luna_state=$(classify_retired "$retired_luna" "$retired_luna_sha256s")
terra_state=$(classify_retired "$retired_terra" "$retired_terra_sha256s")
sol_state=$(classify_retired "$retired_sol" "$retired_sol_sha256s")

if [ "$check_only" -eq 1 ]; then
  [ "$current_state" = current ] || report_preflight_error "Advisor grunt role is $current_state: $current_destination"
  [ "$subagent_state" = missing ] || report_preflight_error "retired Luna subagent remains $subagent_state: $retired_luna_subagent"
  [ "$luna_state" = missing ] || report_preflight_error "retired Luna implementer remains $luna_state: $retired_luna"
  [ "$terra_state" = missing ] || report_preflight_error "retired Terra implementer remains $terra_state: $retired_terra"
  [ "$sol_state" = missing ] || report_preflight_error "retired Sol reviewer remains $sol_state: $retired_sol"
else
  case "$current_state" in current|missing) ;; *) report_preflight_error "Advisor grunt destination is $current_state and will not be replaced: $current_destination" ;; esac
  case "$subagent_state" in retired|missing) ;; *) report_preflight_error "retired Luna subagent is $subagent_state and will not be removed: $retired_luna_subagent" ;; esac
  case "$luna_state" in retired|missing) ;; *) report_preflight_error "retired Luna implementer is $luna_state and will not be removed: $retired_luna" ;; esac
  case "$terra_state" in retired|missing) ;; *) report_preflight_error "retired Terra implementer is $terra_state and will not be removed: $retired_terra" ;; esac
  case "$sol_state" in retired|missing) ;; *) report_preflight_error "retired Sol reviewer is $sol_state and will not be removed: $retired_sol" ;; esac
fi
[ "$preflight_failed" -eq 0 ] || exit 1

if [ "$check_only" -eq 1 ]; then printf '%s\n' "CHECK PASSED: configured Advisor grunt role is current."; exit 0; fi
if [ ! -d "$target_dir" ]; then mkdir -p "$target_dir" || fail "could not create target directory: $target_dir"; fi
[ -d "$target_dir" ] && [ ! -L "$target_dir" ] || fail "target directory changed after preflight"

same_state "Advisor grunt" "$current_state" "$(classify_current "$current_destination" "$rendered")"
same_state "retired Luna subagent" "$subagent_state" "$(classify_retired "$retired_luna_subagent" "$retired_luna_subagent_sha256s")"
same_state "retired Luna" "$luna_state" "$(classify_retired "$retired_luna" "$retired_luna_sha256s")"
same_state "retired Terra" "$terra_state" "$(classify_retired "$retired_terra" "$retired_terra_sha256s")"
same_state "retired Sol" "$sol_state" "$(classify_retired "$retired_sol" "$retired_sol_sha256s")"

case "$current_state" in missing) install_missing "$rendered" "$current_destination" ;; current) printf '%s\n' "ALREADY CURRENT: $current_destination" ;; esac
case "$subagent_state" in retired) retire_exact "Luna subagent" "$retired_luna_subagent" "$retired_luna_subagent_sha256s" ;; esac
case "$luna_state" in retired) retire_exact "Luna implementer" "$retired_luna" "$retired_luna_sha256s" ;; esac
case "$terra_state" in retired) retire_exact "Terra implementer" "$retired_terra" "$retired_terra_sha256s" ;; esac
case "$sol_state" in retired) retire_exact "Sol reviewer" "$retired_sol" "$retired_sol_sha256s" ;; esac

[ "$(classify_current "$current_destination" "$rendered")" = current ] || fail "post-install role exactness check failed"
for retired in "$retired_luna_subagent" "$retired_luna" "$retired_terra" "$retired_sol"; do
  path_exists "$retired" && fail "post-install retired role remains: $retired"
done
printf '%s\n' "INSTALL PASSED: Advisor grunt role is $grunt_model / $grunt_effort and retired profiles are absent."
