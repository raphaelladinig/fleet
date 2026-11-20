{ den, ... }:
{
  den.aspects.apps.linearmouse.includes = [ den.aspects.homebrew ];

  den.aspects.apps.linearmouse.darwin.homebrew.casks = [ "linearmouse" ];

  den.aspects.apps.linearmouse.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../_lib/quit-app.nix { inherit lib; }) quitApp reopenApps;
      applyLinearMouseConfig = pkgs.writeShellScript "configure-linearmouse" ''
        set -eu

        config_dir="$HOME/.config/linearmouse"
        config_file="$config_dir/linearmouse.json"
        staged=""
        app_preferences_reopen=()
        cleanup() {
          if [[ -n "$staged" ]]; then /bin/rm -f "$staged"; fi
          ${reopenApps { }}
        }
        trap cleanup EXIT

        if [[ -e "$config_file" && ! -f "$config_file" ]]; then
          echo "Refusing to replace non-file LinearMouse settings: $config_file" >&2
          exit 1
        fi

        # LinearMouse writes its own JSON formatting, so compare parsed values.
        # Exit status 2 means the current file could not be read.
        compare_config() {
          ${lib.getExe pkgs.python3} -c ${lib.escapeShellArg ''
            import json, sys
            try:
                with open(sys.argv[1]) as file:
                    actual = json.load(file)
            except FileNotFoundError:
                sys.exit(1)
            except OSError:
                sys.exit(2)
            except ValueError:
                sys.exit(1)
            with open(sys.argv[2]) as file:
                sys.exit(actual != json.load(file))
          ''} "$config_file" ${./linearmouse.json}
        }

        config_status=0
        compare_config || config_status=$?
        if [[ "$config_status" -eq 0 ]]; then
          exit 0
        elif [[ "$config_status" -ne 1 ]]; then
          echo "Could not read LinearMouse settings: $config_file" >&2
          exit 1
        fi

        if ! ${
          quitApp {
            processName = "LinearMouse";
            bundleId = "com.lujjjh.LinearMouse";
            user = config.home.username;
          }
        }; then
          exit 0
        fi

        # LinearMouse may save its settings while quitting.
        config_status=0
        compare_config || config_status=$?
        if [[ "$config_status" -eq 0 ]]; then
          exit 0
        elif [[ "$config_status" -ne 1 ]]; then
          echo "Could not read LinearMouse settings: $config_file" >&2
          exit 1
        fi

        mkdir -p "$config_dir"
        staged="$(/usr/bin/mktemp "$config_dir/.linearmouse.XXXXXX")"
        install -m 0644 ${./linearmouse.json} "$staged"
        mv -f "$staged" "$config_file"
      '';
    in
    {
      home.activation.configureLinearMouse = config.lib.dag.entryAfter [ "linkGeneration" ] ''
        if ! run ${applyLinearMouseConfig}; then
          echo 'Warning: could not update LinearMouse settings. Fix the error and run `just switch` again to apply them.' >&2
        fi
      '';
    };
}
