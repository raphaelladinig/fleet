# Neovim

Read `modules/apps/neovim/default.nix` and `init.lua` before adding a feature.

- Feature modules contribute files through `dotfiles.neovim.configFiles`.
  `init.lua` discovers the linked Lua modules.
- Language modules return `{ filetypes, setup }` and initialize on the first
  matching filetype.
- Keep packages and plugins in Nix and runtime behavior in Lua.
- The `lsp`, `formatting`, `linting`, `dap`, `editing`, `spell`, and
  `treesitter` aspects each have a `dotfiles.neovim.<name>.enable` flag. A flag
  is false while its aspect is not included. `default.nix` writes the seven
  values into the generated `lua/my/features.lua`, and Lua code checks
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
- `.stylua.toml` and `.luacheckrc` sit at the repository root so they cover
  this repository's `.nvim/` as well as `modules/apps/neovim/`. `just check`
  names both directories, so add any new Lua location to that recipe.
  `.luarc.json` stays in `modules/apps/neovim/`, which keeps that directory the
  lua_ls root.
- Luacheck captures each buffer's filename and project config directory when
  lint starts.
- Luacheck executes `.luacheckrc` as Lua, so the linter passes a project
  `.luacheckrc` only when the vim.secure trust database holds its current hash.
  Otherwise it passes `--no-config`, because without a flag luacheck searches
  upward from the working directory. An untrusted file triggers one deferred
  `vim.secure.read` prompt per file version; trust it with `:trust` from the
  file's buffer. Editing or moving the file revokes trust. In the editor, files
  under `.nvim/` never use a `.luacheckrc` and get `--globals=vim` instead.
  `just check` lints them with the root file, so a global added there stays
  undefined for `.nvim/` files in the editor.
- Tree-sitter maps must not shadow builtins used in prose buffers. The scope
  text object is `av` with motions `]v` and `[v`, and the fold motions are `]Z`
  and `[Z`, leaving `as`, `]s`, and `]z` to Vim. Check new keys against
  `:help index` and `maparg()` in the built config.
- Prose ftplugins turn on `spell` window-locally and set `spelllang` per buffer.
  German comes from the spell aspect's files, so ftplugins add `de` only when
  `require("my.features").spell` is true. Without those files Neovim prompts to
  download them.
- Configuration files are linked through `home.file`, so edits take effect after
  a rebuild and activation.
