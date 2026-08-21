# Sol Advisor

**Sol / Ultra runs the show. It owns judgment and review; every supported child is
Luna / High.**

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) to get new posts to your inbox.

## Quick start

You need a current Codex CLI or ChatGPT desktop app with plugins enabled, GPT-5.6
Sol / Ultra for the primary task, GPT-5.6 Luna / High access, native custom-agent
support, and jq.

~~~sh
codex plugin marketplace add DannyMac180/sol-advisor --ref main
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')" && test -n "$plugin_dir" && test "$plugin_dir" != null && test -d "$plugin_dir" && test -f "$plugin_dir/scripts/install-agents.sh" && sh "$plugin_dir/scripts/install-agents.sh"
~~~

The companion installer leaves one exact Luna / High profile and safely retires only
byte-exact Sol Advisor profiles from older releases. It refuses modified, unsafe,
nonregular, symlinked, unreadable, or conflicting destinations without partial
mutation and does not edit Codex configuration.

After installation, open `/hooks`, review and trust the Sol Advisor lifecycle hooks,
then start a fresh task on Sol / Ultra. The trusted `SessionStart` hook
automatically loads the orchestration contract for ordinary prompts; no explicit skill
invocation is required. The trusted `PreToolUse` hook enforces supported child spawns.
Until the hooks are trusted, neither automatic activation nor spawn enforcement is
active.

| Mode | Use it when | Delivery |
|---|---|---|
| `solo` | Default; primary-task execution is appropriate. | Sol / Ultra implements, verifies, and self-reviews. |
| `delegate` | A bounded packet benefits from separate execution. | Luna / High executes; Sol / Ultra verifies and reviews. |
| `audit` | The requested outcome is a review. | Sol / Ultra renders the verdict; Luna / High may gather bounded evidence. |

When enabled Open Dynamic Workflows v0.2.0 genuinely fits a large or rerunnable task,
Sol Advisor keeps workflow design and final review in Sol / Ultra, pins every ODW model
node to Codex Luna / High, and rejects the run unless traces and Codex runtime metadata
prove every node. ODW itself remains unchanged; workflows authored outside Sol Advisor
are outside this contract.

The trusted hook blocks supported `spawn_agent` calls unless they use the exact fresh
Luna / High profile. [OpenAI's Codex hooks documentation](https://learn.chatgpt.com/docs/hooks)
notes that specialized paths may bypass ordinary tool hooks, so runtime evidence is
still required and the plugin does not claim an unbypassable platform policy.

## Updating

Update the marketplace plugin, reinstall the companion profile, and start a new task:

~~~sh
codex plugin marketplace upgrade sol-advisor
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')" && test -n "$plugin_dir" && test "$plugin_dir" != null && test -d "$plugin_dir" && test -f "$plugin_dir/scripts/install-agents.sh" && sh "$plugin_dir/scripts/install-agents.sh"
~~~

For exact spawn, runtime-evidence, sandbox, installer, and maintainer verification
details, read [advanced operations](plugins/sol-advisor/skills/orchestration/references/operations.md).
For local development, install this checkout as a marketplace:

~~~sh
cd /absolute/path/to/sol-advisor
codex plugin marketplace add /absolute/path/to/sol-advisor
codex plugin add sol-advisor@sol-advisor
~~~
