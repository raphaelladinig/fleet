{ den, ... }:
{
  den.aspects.apps.development.includes = [ den.aspects.homebrew ];

  den.aspects.apps.development.darwin.homebrew = {
    casks = [ "t3-code@nightly" ];
    masApps."Xcode" = 497799835;
  };

  den.aspects.apps.development.homeManager =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        gh
        just
        nh
        tokei
      ];
    };
}
