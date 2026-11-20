{ den, ... }:
{
  den.aspects.apps.helium.includes = [
    den.aspects.homebrew
    den.aspects.app-preferences
  ];

  den.aspects.apps.helium.darwin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../_lib/quit-app.nix { inherit lib; }) quitApp;
      user = config.system.primaryUser;
      userDataDir = "${config.users.users.${user}.home}/Library/Application Support/net.imput.helium";
      asUser = (import ../../_lib/run-as-user.nix { inherit lib; }).runAsUser { inherit user; };
      extensionPython = pkgs.python3.withPackages (ps: [ ps.plyvel ]);
      applyPreferences = asUser "${pkgs.python3}/bin/python3 ${./apply-preferences.py}";
      applyDarkReader = asUser "${extensionPython}/bin/python3 ${./apply-dark-reader.py}";
      preferencesArgs = "--seed ${./preferences-seed.json} ${lib.escapeShellArg "${userDataDir}/Default/Preferences"} ${./preferences.json}";
      localStateArgs = "${lib.escapeShellArg "${userDataDir}/Local State"} ${./local-state.json}";
      profilePath = lib.escapeShellArg "${userDataDir}/Default";
      uncheckedWarning =
        target:
        ''printf '\033[1;33m%s\033[0m\n' ${lib.escapeShellArg "Could not inspect Helium ${target}, so activation skipped it. Check the error above, fix access or file contents, and run `just switch` again."} >&2'';
    in
    {
      homebrew.casks = [ "helium-browser" ];

      dotfiles.appPreferences.helium = {
        domain = "net.imput.helium";
        processName = "Helium";
        preferences = {
          SUAutomaticallyUpdate = true;
          SUEnableAutomaticChecks = true;
          DefaultSearchProviderEnabled = true;
          DefaultSearchProviderName = "DuckDuckGo";
          DefaultSearchProviderKeyword = "duckduckgo.com";
          DefaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}";
          DefaultSearchProviderSuggestURL = "https://duckduckgo.com/ac/?q={searchTerms}&type=list";
        };
      };

      system.activationScripts.postActivation.text = lib.mkAfter ''
        # Helium rewrites these files while running, so quit it only when a check
        # reports drift. Checks exit 0 on a match, 1 on drift, and 2 when they
        # could not inspect the file, which skips that file's writer.
        helium_preferences_status=0
        ${applyPreferences} --check ${preferencesArgs} || helium_preferences_status=$?
        helium_local_state_status=0
        ${applyPreferences} --check ${localStateArgs} || helium_local_state_status=$?
        helium_dark_reader_status=0
        ${applyDarkReader} --check ${profilePath} || helium_dark_reader_status=$?
        if [[ "$helium_preferences_status" -gt 1 ]]; then
          ${uncheckedWarning "preferences at ${userDataDir}/Default/Preferences"}
        fi
        if [[ "$helium_local_state_status" -gt 1 ]]; then
          ${uncheckedWarning "Local State at ${userDataDir}/Local State"}
        fi
        if [[ "$helium_dark_reader_status" -gt 1 ]]; then
          ${uncheckedWarning "Dark Reader settings under ${userDataDir}/Default"}
        fi
        if {
          [[ "$helium_preferences_status" -eq 1 || "$helium_local_state_status" -eq 1 || "$helium_dark_reader_status" -eq 1 ]]
        } && ${
          quitApp {
            processName = "Helium";
            bundleId = "net.imput.helium";
            inherit user;
            run = asUser;
          }
        }; then
          if [[ "$helium_preferences_status" -le 1 ]] && ! ${applyPreferences} ${preferencesArgs}; then
            printf '%s\n' ${lib.escapeShellArg "Could not apply Helium preferences at ${userDataDir}/Default/Preferences. Check the error above, fix access or file contents, and run `just switch` again."} >&2
          fi
          if [[ "$helium_local_state_status" -le 1 ]] && ! ${applyPreferences} ${localStateArgs}; then
            printf '%s\n' ${lib.escapeShellArg "Could not apply Helium Local State at ${userDataDir}/Local State. Check the error above, fix access or file contents, and run `just switch` again."} >&2
          fi
          if [[ "$helium_dark_reader_status" -le 1 ]] && ! ${applyDarkReader} ${profilePath}; then
            printf '%s\n' ${lib.escapeShellArg "Could not apply Helium Dark Reader settings under ${userDataDir}/Default. Check the error above, fix access or close processes using its extension databases, and run `just switch` again."} >&2
          fi
        fi
      '';
    };

  den.aspects.apps.helium.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      dotfiles.helium.enable = lib.mkDefault true;

      home.file.".config/helium/extensions.mobileconfig" = {
        source = pkgs.runCommand "helium-extensions.mobileconfig" { } ''
          ${pkgs.python3}/bin/python3 ${./generate-extension-profile.py} ${./extensions.csv} "$out"
        '';
        onChange = ''
          echo 'Helium extension profile changed. Open ~/.config/helium/extensions.mobileconfig and install it in System Settings > General > Device Management.'
        '';
      };

      home.file."Library/Application Support/net.imput.helium/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json" =
        lib.mkIf (config.dotfiles.helium.enable && config.dotfiles.keepassxc.enable) {
          source = (pkgs.formats.json { }).generate "org.keepassxc.keepassxc_browser.json" {
            name = "org.keepassxc.keepassxc_browser";
            description = "KeePassXC integration with native messaging support";
            path = "/Applications/KeePassXC.app/Contents/MacOS/keepassxc-proxy";
            type = "stdio";
            allowed_origins = [ "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/" ];
          };
        };
    };
}
