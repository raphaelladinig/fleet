{ den, ... }:
{
  den.aspects.apps.neovim.langs.rust.includes = [ den.aspects.apps.neovim.core ];

  den.aspects.apps.neovim.langs.rust.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.dotfiles.neovim.langs.rust.enable = lib.mkEnableOption "Neovim Rust support" // {
        default = true;
      };

      config = lib.mkIf config.dotfiles.neovim.langs.rust.enable {
        dotfiles.neovim.configFiles."lua/my/langs/rust.lua" = "langs/rust/rust.lua";
        dotfiles.neovim.treesitterParsers = [ "rust" ];

        home.packages =
          with pkgs;
          [ rustfmt ] ++ lib.optionals config.dotfiles.neovim.lsp.enable [ rust-analyzer ];
      };
    };
}
