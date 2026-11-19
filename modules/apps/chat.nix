{ den, ... }:
{
  den.aspects.apps.chat.includes = [ den.aspects.homebrew ];

  den.aspects.apps.chat.darwin.homebrew.casks = [
    "signal"
    "vesktop"
    "whatsapp"
  ];
}
