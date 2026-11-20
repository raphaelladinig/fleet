{ den, ... }:
{
  den.aspects.macos.colemak-dh.includes = [ den.aspects.homebrew ];

  den.aspects.macos.colemak-dh.darwin =
    let
      colemakDH = {
        InputSourceKind = "Keyboard Layout";
        "KeyboardLayout ID" = -7379;
        "KeyboardLayout Name" = "Colemak DH ANSI";
      };
    in
    {
      homebrew.casks = [ "colemak-dh" ];

      system.defaults.CustomUserPreferences = {
        "com.apple.inputsources".AppleEnabledThirdPartyInputSources = [ colemakDH ];
        "com.apple.HIToolbox".AppleSelectedInputSources = [
          {
            "Bundle ID" = "com.apple.PressAndHold";
            InputSourceKind = "Non Keyboard Input Method";
          }
          colemakDH
        ];
      };
    };
}
