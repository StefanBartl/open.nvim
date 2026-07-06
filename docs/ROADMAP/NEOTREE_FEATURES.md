# Tree-buffer feature audit → filetree.nvim port map

**Purpose.** Sweep called for in `FINISH.md`: check whether open.nvim's
Neo-tree / nvim-tree / netrw handling (`lua/open_nvim/context.lua`) has
anything worth porting into **filetree.nvim**
(`E:/repos/filetree.nvim`) — cross-platform and filetree-manager agnostic.

**Result up front:** the yield is small. open.nvim's tree-buffer logic exists
only to answer one narrow question — "what path is under the cursor right
now, for the `:Open` command" — for exactly three backends. filetree.nvim
already has a formal `FiletreeAdapter` interface
(`lua/filetree/adapter/{neotree,nvimtree,netrw,oil,mini_files}.lua`) that
answers a much richer set of questions (current node, visible nodes, expand/
collapse, highlight, reveal, …) for five backends. Every open.nvim technique
below is already superseded there, more generally. No new port targets.

## How to read

- **Origin**: `open_nvim/context.lua:<line>`.
- **filetree.nvim**: the adapter file/function that already does the
  equivalent (more general) thing.
- **Status:** ✅ already superseded (nothing to port) · 🟡 partial nuance,
  see notes · ➖ different paradigm, not portable.

| Feature | Origin | filetree.nvim | Status |
|---|---|---|---|
| Tree-buffer dispatch by `filetype` (neo-tree / NvimTree / netrw) | [context.lua:130-138](../../lua/open_nvim/context.lua) (`resolve_tree_node_path`) | `filetypes` field on each adapter (e.g. [adapter/neotree.lua:17](E:/repos/filetree.nvim/lua/filetree/adapter/neotree.lua), [adapter/nvimtree.lua:10](E:/repos/filetree.nvim/lua/filetree/adapter/nvimtree.lua), [adapter/netrw.lua:7](E:/repos/filetree.nvim/lua/filetree/adapter/netrw.lua)) | ✅ superseded — adapter registry also covers oil.nvim + mini.files |
| Neo-tree node-path resolution: try a richer node helper first, fall back to `state.tree:get_node()` | [context.lua:72-101](../../lua/open_nvim/context.lua) (`resolve_neotree_path`) | [adapter/neotree.lua:47-68](E:/repos/filetree.nvim/lua/filetree/adapter/neotree.lua) (`node_path`, via `lib.nvim.neotree.node` with local fallback) | ✅ superseded — same fallback *shape* independently arrived at on both sides, which cross-validates the pattern rather than adding anything new |
| nvim-tree current-node resolution via `api.tree.get_node_under_cursor()` | [context.lua:104-112](../../lua/open_nvim/context.lua) (`resolve_nvimtree_path`) | [adapter/nvimtree.lua:76-91](E:/repos/filetree.nvim/lua/filetree/adapter/nvimtree.lua) (`get_current_node`) | ✅ superseded — adapter version also captures type/depth/expanded state |
| netrw path resolution: `netrw_curdir` + current line, string-concatenated | [context.lua:115-126](../../lua/open_nvim/context.lua) (`resolve_netrw_path`) | [adapter/netrw.lua:43-114](E:/repos/filetree.nvim/lua/filetree/adapter/netrw.lua) (`parse_netrw_line` + `get_current_node`) | 🟡 see note below — filetree.nvim's version is strictly more correct |
| `PATH_TARGETS` scope heuristic (does this handler key want a validated path, or cword/visual text?) | [context.lua:144-151, 236](../../lua/open_nvim/context.lua) | — | ➖ different paradigm — filetree.nvim's features operate on adapter node objects, not on a generic scope-token/text heuristic for an arbitrary open command. Nothing to port. |

## Gaps — port targets not yet in filetree.nvim

None found. open.nvim's tree-buffer surface is fully covered, more generally,
by the existing adapter layer.

## Note (open.nvim side, not a port item)

While comparing the two netrw implementations, `context.lua`'s
`resolve_netrw_path()` (line 115) does **not** skip netrw's banner/header
lines (the `"..` comment line, `--..` sort/filter markers) the way
filetree.nvim's `parse_netrw_line` ([adapter/netrw.lua:47](E:/repos/filetree.nvim/lua/filetree/adapter/netrw.lua))
does. In practice this is low-impact for open.nvim (the cursor is rarely
parked on the banner line when invoking `:Open`), so it's not filed as an
action item here — flagging it only because it surfaced during this audit.
