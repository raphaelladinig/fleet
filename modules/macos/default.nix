{ den, ... }:
{
  den.aspects.macos.includes = [ den.aspects.app-preferences ];

  den.aspects.macos.darwin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      userName = config.system.primaryUser;
      homeDirectory = config.users.users.${userName}.home;
      # Lossless, so the desktop renders exactly #000000.
      wallpaper = "${pkgs.runCommand "black.png" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 ${./config/black-png.py} > $out
      ''}";
      applyWallpaper = "${./config/apply-wallpaper.js}";
      wallpaperStore = "${homeDirectory}/Library/Application Support/com.apple.wallpaper/Store";
      dockApps = [
        "${homeDirectory}/Applications/Home Manager Apps/Rex.app"
        "/Applications/T3 Code (Nightly).app"
        "/Applications/Helium.app"
        "/Applications/KeePassXC.app"
        "/System/Applications/Mail.app"
      ];
      runAsUser =
        command:
        ''launchctl asuser "$(id -u -- ${lib.escapeShellArg userName})" sudo --user=${lib.escapeShellArg userName} -- ${command}'';
    in
    {
      security.pam.services.sudo_local.touchIdAuth = true;

      # macOS stores the system-wide AutoFill toggle in Safari's preferences.
      dotfiles.appPreferences.password-autofill = {
        domain = "com.apple.Safari";
        processName = "Safari";
        preferences.AutoFillPasswords = false;
      };

      system.defaults = {
        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          AppleShowAllExtensions = true;
          AppleShowScrollBars = "WhenScrolling";
          NSAutomaticCapitalizationEnabled = true;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticInlinePredictionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = true;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSTableViewDefaultSizeMode = 2;
          "com.apple.trackpad.scaling" = 1.0;
        };

        CustomUserPreferences.NSGlobalDomain = {
          NSGlassTintAmount = 1.0;
          SLSMenuBarUseBlurredAppearance = true;
        };

        # nix-darwin's controlcenter options write 18 for a shown item, but
        # this macOS version stores 2.
        CustomUserPreferences."~${userName}/Library/Preferences/ByHost/com.apple.controlcenter" = {
          Battery = 2;
          Bluetooth = 2;
          Display = 24;
          FocusModes = 24;
          Sound = 24;
        };

        CustomUserPreferences."com.apple.assistant.support" = {
          "Assistant Enabled" = true;
          "Dictation Enabled" = false;
        };

        CustomUserPreferences."com.apple.Siri" = {
          StatusMenuVisible = false;
          VoiceTriggerUserEnabled = false;
        };

        CustomUserPreferences."com.apple.dock" = {
          autohide = true;
          autohide-delay = 0.0;
          autohide-time-modifier = 0.0;
          largesize = 90;
          launchanim = false;
          magnification = true;
          mineffect = "scale";
          minimize-to-application = true;
          orientation = "bottom";
          show-recents = false;
          tilesize = 75;
          wvous-bl-corner = 10;
          wvous-br-corner = 4;
          wvous-tl-corner = 13;
          wvous-tr-corner = 12;
        };

        finder = {
          FXDefaultSearchScope = "SCcf";
          FXEnableExtensionChangeWarning = false;
          FXPreferredViewStyle = "Nlsv";
          FXRemoveOldTrashItems = true;
          NewWindowTarget = "Recents";
          ShowExternalHardDrivesOnDesktop = false;
          ShowHardDrivesOnDesktop = false;
          ShowPathbar = true;
          ShowRemovableMediaOnDesktop = true;
          ShowStatusBar = false;
        };

        trackpad = {
          ActuateDetents = true;
          Clicking = false;
          DragLock = false;
          Dragging = false;
          FirstClickThreshold = 0;
          ForceSuppressed = false;
          SecondClickThreshold = 0;
          TrackpadCornerSecondaryClick = 0;
          TrackpadFourFingerHorizSwipeGesture = 2;
          TrackpadFourFingerPinchGesture = 2;
          TrackpadFourFingerVertSwipeGesture = 2;
          TrackpadMomentumScroll = true;
          TrackpadPinch = true;
          TrackpadRightClick = true;
          TrackpadRotate = true;
          TrackpadThreeFingerDrag = false;
          TrackpadThreeFingerHorizSwipeGesture = 0;
          TrackpadThreeFingerTapGesture = 0;
          TrackpadThreeFingerVertSwipeGesture = 0;
          TrackpadTwoFingerDoubleTapGesture = true;
          TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
        };

        universalaccess = {
          mouseDriverCursorSize = 1.0;
          reduceMotion = true;
          reduceTransparency = false;
        };

        WindowManager = {
          AppWindowGroupingBehavior = true;
          AutoHide = true;
          EnableStandardClickToShowDesktop = true;
          EnableTiledWindowMargins = false;
          GloballyEnabled = false;
          HideDesktop = true;
          StageManagerHideWidgets = true;
          StandardHideWidgets = false;
        };

        controlcenter.BatteryShowPercentage = true;

        hitoolbox.AppleFnUsageType = "Do Nothing";

        menuExtraClock = {
          ShowAMPM = true;
          ShowDate = 2;
          ShowDayOfWeek = false;
        };
      };

      # nix-darwin restarts Dock unconditionally for system.defaults.dock.
      # Write those preferences above, then restart only when they changed.
      system.activationScripts.userDefaults.text = lib.mkMerge [
        (lib.mkBefore ''
          dock_preferences_before=$(${runAsUser "defaults export com.apple.dock -"} 2>/dev/null) || dock_preferences_before=""
        '')
        # Dock adds its own keys to each tile, so rewriting persistent-apps on
        # every switch would restart Dock every time. Compare app paths only.
        ''
          dock_apps_status=0
          dock_apps_plist=$(printf '%s' "$dock_preferences_before" | ${lib.getExe pkgs.python3} -c ${lib.escapeShellArg ''
            import plistlib, sys
            from urllib.parse import unquote

            try:
                dock = plistlib.loads(sys.stdin.buffer.read())
            except Exception:
                sys.exit(2)

            def app_path(tile):
                url = tile.get("tile-data", {}).get("file-data", {}).get("_CFURLString", "")
                if url.startswith("file://"):
                    url = unquote(url[len("file://"):])
                return url.rstrip("/")

            desired = sys.argv[1:]
            if [app_path(tile) for tile in dock.get("persistent-apps", [])] == desired:
                sys.exit(0)
            tiles = [
                {
                    "tile-data": {"file-data": {"_CFURLString": path, "_CFURLStringType": 0}},
                    "tile-type": "file-tile",
                }
                for path in desired
            ]
            sys.stdout.buffer.write(plistlib.dumps(tiles))
            sys.exit(3)
          ''} ${lib.escapeShellArgs dockApps}) || dock_apps_status=$?
          if [[ "$dock_apps_status" -eq 3 ]]; then
            if ! ${runAsUser ''defaults write com.apple.dock persistent-apps "$dock_apps_plist"''}; then
              echo >&2 "Could not write the Dock apps. Run \`just switch\` again to apply them."
            fi
          elif [[ "$dock_apps_status" -ne 0 ]]; then
            echo >&2 "Could not read the Dock preferences, so the Dock apps were left unchanged."
          fi
        ''
        (lib.mkAfter ''
          dock_preferences_after=$(${runAsUser "defaults export com.apple.dock -"} 2>/dev/null) || dock_preferences_after=""
          if [[ -z "$dock_preferences_before" || -z "$dock_preferences_after" || "$dock_preferences_before" != "$dock_preferences_after" ]]; then
            echo >&2 "restarting Dock..."
            killall -qu ${lib.escapeShellArg userName} Dock || true
          fi
        '')
      ];

      # pmset sets each power source separately and covers power modes, which
      # nix-darwin has no option for. powermode 1 is Low Power, 2 is High Power.
      system.activationScripts.power.text = lib.mkAfter ''
        pmset_value() {
          /usr/bin/pmset -g custom | /usr/bin/awk -v section="$1:" -v key="$2" '
            /^[^ ]/ { in_section = ($0 == section); next }
            in_section && $1 == key { print $2; exit }
          '
        }

        apply_pmset() {
          local flag="$1" section="$2" changes=()
          shift 2
          while (($# > 0)); do
            if [[ "$(pmset_value "$section" "$1")" != "$2" ]]; then
              changes+=("$1" "$2")
            fi
            shift 2
          done
          if ((''${#changes[@]} > 0)) && ! /usr/bin/pmset "$flag" "''${changes[@]}"; then
            echo >&2 "Could not apply $section settings: ''${changes[*]}"
          fi
        }

        apply_pmset -b "Battery Power" displaysleep 0 powermode 1
        apply_pmset -c "AC Power" displaysleep 0 powermode 2
      '';

      launchd.user.agents.apply-wallpaper = {
        script = ''
          if [[ "$(/usr/bin/id -un)" != ${lib.escapeShellArg userName} ]]; then
            exit 0
          fi

          if [[ ! -f ${lib.escapeShellArg wallpaper} ]]; then
            echo "Wallpaper not found: ${wallpaper}" >&2
            exit 1
          fi

          /usr/bin/osascript -l JavaScript \
            ${lib.escapeShellArg applyWallpaper} \
            ${lib.escapeShellArg wallpaper}
        '';

        serviceConfig = {
          LimitLoadToSessionType = "Aqua";
          ProcessType = "Interactive";
          RunAtLoad = true;
          # Attaching a display gives it a default wallpaper and rewrites the
          # store, so re-apply whenever the store changes instead of only at
          # login. The script is a no-op once every screen already matches.
          WatchPaths = [ wallpaperStore ];
        };
      };
    };
}
