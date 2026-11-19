{ den, ... }:
{
  den.aspects.users.raphaelladinig = {
    includes = [
      den.batteries.define-user
      den.batteries.primary-user
      den.aspects.homebrew
      den.aspects.apps.alcove
      den.aspects.apps.cmux
      den.aspects.apps.git
      den.aspects.apps.helium
      den.aspects.apps.keepassxc
      den.aspects.apps.lazygit
      den.aspects.apps.neovim
      den.aspects.apps.rex
      den.aspects.apps.fish
      den.aspects.ai.agents-md
      den.aspects.ai.skills
      den.aspects.fonts
    ];

    darwin.homebrew.casks = [
      "affinity"
      "claude"
      "claude-code@latest"
      "chatgpt"
      "codex"
      "colemak-dh"
      "hammerspoon"
      "hyperkey"
      "linearmouse"
      "middledrag"
      "obs"
      "petrichor"
      "soulseek"
      "spotify"
      "tailscale-app"
      "vicinae"
      "wispr-flow"
      "equinox"
      "t3-code@nightly"
      "istat-menus"
      "finetune"
      "libreoffice"
      "anki"
      "betterdisplay"
      "iina"
      "shottr"
      "signal"
      "vesktop"
      "whatsapp"
    ];

    darwin.homebrew.masApps = {
      "Brother iPrint&Scan" = 1193539993;
      "Xcode" = 497799835;
    };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          btop
          fastfetch
          gh
          just
          nh
          tokei
          typst
        ];
      };
  };
}
