{ den, lib, ... }:
{
  den.default.includes = [
    den.aspects.nix-settings
    den.aspects.nixpkgs
  ];

  den.default.darwin.system.stateVersion = 6;
  den.default.homeManager =
    {
      lib,
      user,
      ...
    }:
    let
      mkAspectEnableOption =
        description: aspect:
        lib.mkEnableOption description
        // {
          apply = enabled: enabled && user.hasAspect.forClass "homeManager" aspect;
        };
    in
    {
      # Cross-aspect dotfiles.* flags are declared here so any aspect can test
      # another aspect's flag without requiring that aspect to be included.
      # A flag is effective only while its providing aspect is included.
      options.dotfiles = {
        helium.enable = mkAspectEnableOption "Helium" den.aspects.apps.helium;
        keepassxc.enable = mkAspectEnableOption "KeePassXC" den.aspects.apps.keepassxc;
        neovim = {
          dap.enable = mkAspectEnableOption "Neovim DAP" den.aspects.apps.neovim.dap;
          editing.enable = mkAspectEnableOption "Neovim editing helpers" den.aspects.apps.neovim.editing;
          formatting.enable = mkAspectEnableOption "Neovim formatting" den.aspects.apps.neovim.formatting;
          linting.enable = mkAspectEnableOption "Neovim linting" den.aspects.apps.neovim.linting;
          lsp.enable = mkAspectEnableOption "Neovim LSP" den.aspects.apps.neovim.lsp;
          spell.enable = mkAspectEnableOption "Neovim spell files" den.aspects.apps.neovim.spell;
          treesitter.enable = mkAspectEnableOption "Neovim tree-sitter" den.aspects.apps.neovim.treesitter;
        };
      };

      config.home.stateVersion = "26.05";
    };

  # User aspects carry darwin content, such as Homebrew casks, that belongs on
  # the user's host.
  den.schema.host.includes = [ den.batteries.user-aspects ];
  den.schema.user.classes = lib.mkDefault [ "homeManager" ];
}
