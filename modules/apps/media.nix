{ den, ... }:
{
  den.aspects.apps.media.includes = [ den.aspects.homebrew ];

  den.aspects.apps.media.darwin.homebrew.casks = [
    "iina"
    "obs"
    "petrichor"
    "soulseek"
    "spotify"
  ];
}
