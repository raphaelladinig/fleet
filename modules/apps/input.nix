{ den, ... }:
{
  den.aspects.apps.input.includes = [ den.aspects.homebrew ];

  den.aspects.apps.input.darwin.homebrew.casks = [
    "colemak-dh"
    "hammerspoon"
    "linearmouse"
    "middledrag"
  ];
}
