{ den, ... }:
{
  den.aspects.apps.utilities.includes = [ den.aspects.homebrew ];

  den.aspects.apps.utilities.darwin.homebrew = {
    casks = [
      "betterdisplay"
      "equinox"
      "finetune"
      "istat-menus"
      "middledrag"
      "shottr"
      "tailscale-app"
      "vicinae"
    ];
    masApps."Brother iPrint&Scan" = 1193539993;
  };

  den.aspects.apps.utilities.homeManager =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        btop
        fastfetch
      ];
    };
}
