#!/bin/sh
set -u

emit() {
  printf '%s\n' "$1"
  exit 0
}

payload=$(cat || true)
plugin_root=${CURSOR_PLUGIN_ROOT:-${PLUGIN_ROOT-}}
if [ -z "$plugin_root" ]; then
  script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || emit '{}'
  cursor_host=$(CDPATH= cd "$script_dir/.." && pwd) || emit '{}'
  hosts_dir=$(CDPATH= cd "$cursor_host/.." && pwd) || emit '{}'
  package_dir=$(CDPATH= cd "$hosts_dir/.." && pwd) || emit '{}'
  plugins_dir=$(CDPATH= cd "$package_dir/.." && pwd) || emit '{}'
  plugin_root=$(CDPATH= cd "$plugins_dir/.." && pwd) || emit '{}'
fi

skill=
if [ -f "$plugin_root/plugins/sol-advisor/skills/orchestration/SKILL.md" ]; then
  skill=$plugin_root/plugins/sol-advisor/skills/orchestration/SKILL.md
elif [ -f "$plugin_root/skills/orchestration/SKILL.md" ]; then
  skill=$plugin_root/skills/orchestration/SKILL.md
else
  emit '{}'
fi

if ! command -v jq >/dev/null 2>&1; then
  emit '{}'
fi

if ! printf '%s\n' "$payload" | jq -e 'type == "object"' >/dev/null 2>&1; then
  emit '{}'
fi

event=$(printf '%s\n' "$payload" | jq -r '.hook_event_name // empty')
if [ -n "$event" ] && [ "$event" != sessionStart ]; then
  emit '{}'
fi

if [ "${ODW_HOST-}" = cursor ]; then
  jq -n '{additional_context:"# Advisor bounded ODW worker\n\nExecute only the bounded workflow-node prompt. Do not declare a route, spawn native subagents, launch nested workflows, broaden scope, or render the final verdict. Return exact work and verification evidence to the outer advisor. Requested Cursor CLI flags and ODW routingPolicy fingerprints are not runtime proof of model, effort, role, parent, or completion."}'
  exit 0
fi

skill_text=$(cat "$skill") || emit '{}'
jq -n --arg skill "$skill_text" '{additional_context:$skill}'
