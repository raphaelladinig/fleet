{ den, ... }:
{
  den.aspects.apps.productivity.includes = [ den.aspects.homebrew ];

  den.aspects.apps.productivity.darwin.homebrew.casks = [
    "affinity"
    "anki"
  ];

  den.aspects.apps.productivity.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.typst ];
    };
}
