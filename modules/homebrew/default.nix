{ inputs, ... }:
{
  flake-file.inputs.homebrew-cask = {
    url = "github:Homebrew/homebrew-cask";
    flake = false;
  };
  flake-file.inputs.homebrew-core = {
    url = "github:Homebrew/homebrew-core";
    flake = false;
  };
  flake-file.inputs.nix-homebrew.url = "github:zhaofengli/nix-homebrew";

  den.aspects.homebrew.darwin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      brew = "${config.homebrew.prefix}/bin/brew";
      restartCasks =
        mode:
        ''${lib.getExe pkgs.python3} -I ${./restart-casks.py} ${mode} "$homebrew_restart_state" ${lib.escapeShellArg brew} ${lib.escapeShellArg config.homebrew.user}'';
    in
    {
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

      nix-homebrew = {
        enable = true;
        autoMigrate = true;
        mutableTaps = false;
        taps = {
          "homebrew/homebrew-cask" = inputs.homebrew-cask;
          "homebrew/homebrew-core" = inputs.homebrew-core;
        };
        user = config.system.primaryUser;
      };

      homebrew = {
        enable = true;
        taps = builtins.attrNames config.nix-homebrew.taps;

        onActivation = {
          extraFlags = [ "--verbose" ];
          autoUpdate = false;
          cleanup = "uninstall";
          upgrade = true;
        };
      };

      # Restart apps that brew bundle upgrades while they run. The EXIT trap
      # covers a failed bundle, which ends activation after Homebrew may have
      # quit an app to replace it.
      system.activationScripts.homebrew.text = lib.mkMerge [
        (lib.mkBefore ''
          homebrew_restart_armed=false
          homebrew_restart_state=
          homebrew_restart_casks() {
            homebrew_restart_armed=false
            trap - EXIT
            ${restartCasks "restart"} || true
            rm -f "$homebrew_restart_state"
          }
          if [ -f ${lib.escapeShellArg brew} ] && homebrew_restart_state="$(mktemp)" && ${restartCasks "snapshot"}; then
            homebrew_restart_armed=true
            trap homebrew_restart_casks EXIT
          elif [ -n "$homebrew_restart_state" ]; then
            rm -f "$homebrew_restart_state"
          fi
        '')
        (lib.mkAfter ''
          if [[ "$homebrew_restart_armed" == true ]]; then
            homebrew_restart_casks
          fi
        '')
      ];
    };
}
