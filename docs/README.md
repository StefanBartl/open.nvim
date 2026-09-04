# open.nvim documentation

What is here, and which question each page answers. [The README](../README.md)
is the short version of all of it.

## Getting it running

| Page | Answers |
| --- | --- |
| [installation.md](installation.md) | What has to be there first, and a spec per plugin manager |
| [configuration.md](configuration.md) | Every option, with the full defaults printed out |
| [health-check.md](health-check.md) | What `:checkhealth` reports and how to read it |

## Using it

| Page | Answers |
| --- | --- |
| [cheatsheet.md](cheatsheet.md) | Everything on one screen: every registered handler, the scope tokens a second argument takes, the office auto-redirect, common command examples, the platform dispatch, and the link listing |
| [commands.md](commands.md) | The two command families in full, and what each argument does |
| [keywords.md](keywords.md) | The named scope aliases for config files you open often, and how to add your own |
| [BINDINGS.md](BINDINGS.md) | Every user command, keymap and autocommand this plugin registers |
| [api.md](api.md) | Every Lua function a config or another plugin can call |
| [WORKFLOW.md](WORKFLOW.md) | The different question: not what each command does, but how they combine day to day |

## Why it is the way it is

| Page | Answers |
| --- | --- |
| [FEATURES/](FEATURES/README.md) | One page per area — the core, the handlers, and the viewer — each about the decision rather than the feature list |
| [integrations.md](integrations.md) | Which other plugins this reaches, which it supersedes, and what changes when one is absent |

## Here, but not prose

**`install.json`** declares the external tools this plugin can use,
machine-readably, for `:Lib deps show open.nvim`.
