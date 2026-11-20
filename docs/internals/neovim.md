# Neovim

Read `modules/apps/neovim/default.nix` and `init.lua` before adding a feature.

- Feature modules contribute files through `dotfiles.neovim.configFiles`.
  `init.lua` discovers the linked Lua modules.
- Language modules return `{ filetypes, setup }` and initialize on the first
  matching filetype.
- Keep packages and plugins in Nix and runtime behavior in Lua.
- The `lsp`, `formatting`, `linting`, `dap`, `editing`, and `treesitter`
  aspects each have a `dotfiles.neovim.<name>.enable` flag. A flag is false
  while its aspect is not included. `default.nix` writes the six values into
  the generated `lua/my/features.lua`, and Lua code checks
  `require("my.features").<name>` before using a feature.
- A new flag needs a `mkAspectEnableOption` in `modules/defaults.nix`, a
  `mkDefault true` and a `lib.mkIf` around its configuration in its aspect, and
  an entry in the generated table. Without the entry, Lua reads `nil`, so `if`
  checks skip the feature without an error.
- Keep lazy triggers aligned with bundled server filetypes and formatter
  mappings.
- `settings.lua` loads a project's `.nvim/init.lua` and applies each
  `.nvim/lsp/<server>.lua` through `vim.lsp.config(<server>, ...)`. Each file
  runs only after `vim.secure.read(file)` trusts its current contents, so an
  edit prompts again. Never trust the `.nvim` directory or add it to the
  runtimepath. Neovim trusts directories by name only, and the runtimepath
  would load `plugin/`, `ftplugin/`, and `lua/my/` modules unchecked.
- Luacheck captures each buffer's filename and project config directory when
  lint starts.
- Configuration files are linked through `home.file`, so edits take effect after
  a rebuild and activation.
