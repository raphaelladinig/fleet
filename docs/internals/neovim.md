# Neovim

Read `modules/apps/neovim/default.nix` and `init.lua` before adding a feature.

- Feature modules contribute files through `dotfiles.neovim.configFiles`.
  `init.lua` discovers the linked Lua modules.
- Language modules return `{ filetypes, setup }` and initialize on the first
  matching filetype.
- Keep packages and plugins in Nix and runtime behavior in Lua.
- Keep lazy triggers aligned with bundled server filetypes and formatter
  mappings.
- Luacheck captures each buffer's filename and project config directory when
  lint starts.
- Configuration files are linked through `home.file`, so edits take effect after
  a rebuild and activation.
