#!/bin/sh
set -eu

fail() { printf '%s\n' "ERROR: $*" >&2; exit 1; }

usage() {
  printf '%s\n' \
    'Usage:' \
    '  install-cursor.sh [--repo PATH] [--mode link|copy] [--plugin-home PATH] [--skills-home PATH] [--skip-skills] [--check]' \
    'Install Advisor as a Cursor plugin at ~/.cursor/plugins/local/sol-advisor and optionally' \
    'mirror skills into ~/.cursor/skills for Cursor CLI. This does not add advisor to PATH.'
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
default_repo=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1

repo=$default_repo
mode=link
plugin_home=
skills_home=
skip_skills=0
check_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      [ "$#" -ge 2 ] || fail "--repo requires a value."
      repo=$2; shift 2 ;;
    --mode)
      [ "$#" -ge 2 ] || fail "--mode requires a value."
      mode=$2; shift 2 ;;
    --plugin-home)
      [ "$#" -ge 2 ] || fail "--plugin-home requires a value."
      plugin_home=$2; shift 2 ;;
    --skills-home)
      [ "$#" -ge 2 ] || fail "--skills-home requires a value."
      skills_home=$2; shift 2 ;;
    --skip-skills) skip_skills=1; shift ;;
    --check) check_only=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown or positional argument: $1" ;;
  esac
done

case "$mode" in link|copy) ;; *) fail "--mode must be link or copy." ;; esac
case "$repo" in /*) ;; *) repo=$(pwd -P)/$repo ;; esac
[ -d "$repo" ] && [ ! -L "$repo" ] || fail "repository path is unavailable or unsafe: $repo"
[ -f "$repo/.cursor-plugin/plugin.json" ] || fail "repository is not a Cursor Advisor plugin: $repo"
command -v jq >/dev/null 2>&1 || fail "jq is unavailable."
jq -e '.name == "sol-advisor"' "$repo/.cursor-plugin/plugin.json" >/dev/null ||
  fail "Cursor plugin name is not sol-advisor."

if [ -z "$plugin_home" ]; then
  [ -n "${HOME-}" ] || fail "HOME is unset; set --plugin-home."
  plugin_home=$HOME/.cursor/plugins/local
fi
if [ -z "$skills_home" ]; then
  [ -n "${HOME-}" ] || fail "HOME is unset; set --skills-home."
  skills_home=$HOME/.cursor/skills
fi
case "$plugin_home" in /*) ;; *) plugin_home=$(pwd -P)/$plugin_home ;; esac
case "$skills_home" in /*) ;; *) skills_home=$(pwd -P)/$skills_home ;; esac
target=$plugin_home/sol-advisor

is_advisor_plugin() {
  [ -f "$1/.cursor-plugin/plugin.json" ] &&
    jq -e '.name == "sol-advisor"' "$1/.cursor-plugin/plugin.json" >/dev/null 2>&1
}

check_install() {
  is_advisor_plugin "$target" || fail "Cursor plugin is missing or not Advisor: $target"
  [ -x "$target/plugins/sol-advisor/bin/advisor" ] || fail "packaged helper is missing: $target"
  [ -f "$target/plugins/sol-advisor/skills/advisor/SKILL.md" ] || fail "advisor skill is missing: $target"
  [ -f "$target/plugins/sol-advisor/hosts/cursor/commands/advisor.md" ] || fail "Cursor command is missing: $target"
  [ -f "$target/plugins/sol-advisor/hosts/cursor/hooks/hooks.json" ] || fail "Cursor hooks are missing: $target"
  if [ "$skip_skills" -eq 0 ]; then
    [ -f "$skills_home/advisor/SKILL.md" ] || fail "CLI skills fallback is missing: $skills_home/advisor"
    [ -f "$skills_home/orchestration/SKILL.md" ] || fail "CLI skills fallback is missing: $skills_home/orchestration"
  fi
}

if [ "$check_only" -eq 1 ]; then
  check_install
  printf '%s\n' "OK: $target"
  exit 0
fi

if [ -e "$target" ] || [ -L "$target" ]; then
  if [ -L "$target" ] || is_advisor_plugin "$target"; then
    :
  else
    fail "refusing to overwrite a non-Advisor path: $target"
  fi
  rm -rf "$target"
fi

mkdir -p "$plugin_home" || fail "could not create $plugin_home"
if [ "$mode" = link ]; then
  ln -sfn "$repo" "$target" || fail "could not symlink $repo to $target"
else
  mkdir -p "$target/.cursor-plugin" "$target/plugins" || fail "could not create copy target."
  cp -R "$repo/.cursor-plugin/." "$target/.cursor-plugin/" || fail "could not copy Cursor manifest."
  cp -R "$plugin_dir" "$target/plugins/sol-advisor" || fail "could not copy Advisor package."
fi

if [ "$skip_skills" -eq 0 ]; then
  mkdir -p "$skills_home" || fail "could not create $skills_home"
  for skill in advisor orchestration; do
    src=$target/plugins/sol-advisor/skills/$skill
    dest=$skills_home/$skill
    [ -d "$src" ] || fail "skill source is missing: $src"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ -f "$dest/SKILL.md" ]; then
        rm -rf "$dest"
      else
        fail "refusing to overwrite a non-skill path: $dest"
      fi
    fi
    ln -sfn "$src" "$dest" || fail "could not link CLI skill $skill"
  done
fi

check_install
printf '%s\n' "INSTALLED: $target"
if [ "$skip_skills" -eq 0 ]; then
  printf '%s\n' "SKILLS: $skills_home/advisor $skills_home/orchestration"
fi
printf '%s\n' 'Advisor is not on PATH. Invoke /advisor, the advisor skill, or the packaged helper.'
