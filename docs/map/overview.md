# open.nvim — module map

> **Generated** by `documentation`. Do not edit by hand — run `:DocMap`
> (or `nvim --headless -l scripts/gen_map.lua`) to regenerate.

**3 modules** · 4 namespaces · 21 helper files

The [interactive map](index.html) has filtering, full descriptions and
source links; this page is the version the code host renders directly.


## Namespaces

```mermaid
flowchart LR
  nlua["open.nvim"]
  nlua_open["openbr/smallRegisters the :Open target scope user…/small"]
  nlua_open_bindings["bindings"]
  nlua_open_config["configbr/smallSetup options and defaults for open.nvim./small"]
  nlua_open_handlers["handlers"]
  nlua_open_integrations["integrations"]
  nlua_open_viewer["viewerbr/smallthen open, export, or copy them./small"]
  nlua --> nlua_open
  nlua_open --> nlua_open_bindings
  nlua_open --> nlua_open_config
  nlua_open --> nlua_open_handlers
  nlua_open --> nlua_open_integrations
  nlua_open --> nlua_open_viewer
```


## Dependencies

Which parts of the tree require which, rolled up to the second level.
The [interactive map](index.html)'s **Deps** view has this per module,
in both directions, with load-time and lazy requires told apart.

```mermaid
flowchart LR
  nlua_open_bindings["bindings"]
  nlua_open_config["open.config"]
  nlua_open_context_lua["open.context"]
  nlua_open_handlers["handlers"]
  nlua_open_health_lua["open.health"]
  nlua_open_integrations["integrations"]
  nlua_open_keywords_lua["open.keywords"]
  nlua_open_picker_lua["open.picker"]
  nlua_open_platform_lua["open.platform"]
  nlua_open_registry_lua["open.registry"]
  nlua_open_util_lua["open.util"]
  nlua_open_viewer["open.viewer"]
  nlua_open_bindings --> nlua_open_config
  nlua_open_bindings --> nlua_open_context_lua
  nlua_open_bindings --> nlua_open_picker_lua
  nlua_open_bindings --> nlua_open_registry_lua
  nlua_open_bindings --> nlua_open_viewer
  nlua_open_config --> nlua_open_keywords_lua
  nlua_open_context_lua --> nlua_open_config
  nlua_open_handlers --> nlua_open_config
  nlua_open_handlers --> nlua_open_platform_lua
  nlua_open_handlers --> nlua_open_util_lua
  nlua_open_health_lua --> nlua_open_config
  nlua_open_health_lua --> nlua_open_platform_lua
  nlua_open_health_lua --> nlua_open_registry_lua
  nlua_open_integrations --> nlua_open_config
  nlua_open_integrations --> nlua_open_context_lua
  nlua_open_integrations --> nlua_open_registry_lua
  nlua_open_keywords_lua --> nlua_open_platform_lua
  nlua_open_picker_lua --> nlua_open_context_lua
  nlua_open_picker_lua --> nlua_open_registry_lua
  nlua_open_registry_lua --> nlua_open_config
  nlua_open_viewer --> nlua_open_config
  nlua_open_viewer --> nlua_open_registry_lua
```


## Modules

| Module | Description | Fns | Docs |
|---|---|---|---|
| `open` | Registers the :Open [target] [scope] user command with tab-completion over the registered handler names (1st arg) and explicit scope tokens (2nd arg). | 2 | [src](../../lua/open/init.lua) |
| &nbsp;&nbsp;`bindings` |  |  |  |
| &nbsp;&nbsp;`open.config` | Setup options and defaults for open.nvim. | 3 | [src](../../lua/open/config/init.lua) |
| &nbsp;&nbsp;`handlers` |  |  |  |
| &nbsp;&nbsp;`integrations` |  |  |  |
| &nbsp;&nbsp;`open.viewer` | then open, export, or copy them. | 14 | [src](../../lua/open/viewer/init.lua) |

## Drift

0 errors · 0 warnings · 13 info

No errors or warnings.


<details>
<summary>13 informational findings</summary>


| Check | Message |
|---|---|
| `missing-readme` | lua/open has no README.md |
| `missing-readme` | lua/open/config has no README.md |
| `missing-readme` | lua/open/viewer has no README.md |
| `unreferenced-module` | open.handlers.browser is required by no other file in the tree |
| `unreferenced-module` | open.handlers.default is required by no other file in the tree |
| `unreferenced-module` | open.handlers.filemanager is required by no other file in the tree |
| `unreferenced-module` | open.handlers.image is required by no other file in the tree |
| `unreferenced-module` | open.handlers.notepad is required by no other file in the tree |
| `unreferenced-module` | open.handlers.nvim_internal is required by no other file in the tree |
| `unreferenced-module` | open.handlers.terminal is required by no other file in the tree |
| `unreferenced-module` | open.health is required by no other file in the tree |
| `unreferenced-module` | open.integrations.telescope is required by no other file in the tree |
| `unreferenced-module` | open.integrations.urlview is required by no other file in the tree |

</details>
