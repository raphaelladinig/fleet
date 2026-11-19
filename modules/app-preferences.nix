{ ... }:
{
  den.aspects.app-preferences.darwin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ./_lib/quit-app.nix { inherit lib; }) quitApp reopenApps;
      user = config.system.primaryUser;
      runAsUser =
        command:
        ''launchctl asuser "$(id -u -- ${lib.escapeShellArg user})" sudo --user=${lib.escapeShellArg user} --set-home -- ${command}'';
      applyPreferences =
        {
          prefix,
          domain,
          bundleId,
          processName,
          preferences,
        }:
        let
          run =
            command:
            ''launchctl asuser "''$${prefix}_user_id" sudo --user="''$${prefix}_user" --set-home -- ${command}'';
          valueString = value: if builtins.isBool value then if value then "1" else "0" else toString value;
          writeValueString = value: if builtins.isBool value then lib.boolToString value else toString value;
          valueType =
            value:
            if builtins.isBool value then
              "-bool"
            else if builtins.isInt value then
              "-int"
            else if builtins.isFloat value then
              "-float"
            else if builtins.isString value then
              "-string"
            else
              throw "App preferences support only boolean, integer, float, and string values.";
          readType =
            value:
            "Type is "
            + {
              "-bool" = "boolean";
              "-int" = "integer";
              "-float" = "float";
              "-string" = "string";
            }
            .${valueType value};
        in
        ''
          ${prefix}_user=${lib.escapeShellArg user}
          ${prefix}_user_id="$(id -u -- "''$${prefix}_user")"
          ${prefix}_preferences_changed=false

          ${prefix}_default_matches() {
            local actual actual_type
            actual_type="$(
              ${run "/usr/bin/defaults read-type ${lib.escapeShellArg domain}"} "$1" 2>/dev/null
            )" || return 1
            [[ "$actual_type" == "$3" ]] || return 1
            if [[ "$3" == "Type is string" || "$3" == "Type is float" ]]; then
              # defaults read escapes strings differently across macOS versions
              # and prints floats in a different format than Nix.
              ${run "/usr/bin/defaults export ${lib.escapeShellArg domain} -"} 2>/dev/null |
                ${lib.getExe pkgs.python3} -c ${lib.escapeShellArg ''
                  import plistlib, sys
                  actual = plistlib.loads(sys.stdin.buffer.read()).get(sys.argv[1])
                  if sys.argv[3] == "Type is float":
                      sys.exit(not (type(actual) is float and actual == float(sys.argv[2])))
                  sys.exit(not (type(actual) is str and actual == sys.argv[2]))
                ''} "$1" "$2" "$3" 2>/dev/null
            else
              actual="$(
                ${run "/usr/bin/defaults read ${lib.escapeShellArg domain}"} "$1" 2>/dev/null
              )" || return 1
              [[ "$actual" == "$2" ]]
            fi
          }

          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: value: ''
              if ! ${prefix}_default_matches ${lib.escapeShellArg name} ${lib.escapeShellArg (valueString value)} ${lib.escapeShellArg (readType value)}; then
                ${prefix}_preferences_changed=true
              fi
            '') preferences
          )}

          if [[ "''$${prefix}_preferences_changed" == true ]]; then
            if ${
              quitApp {
                inherit processName bundleId;
                uid = "''$${prefix}_user_id";
                run = runAsUser;
              }
            }; then
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (name: value: ''
                  if ! (
                    actual_type="$(${run "/usr/bin/defaults read-type ${lib.escapeShellArg domain} ${lib.escapeShellArg name}"} 2>/dev/null)" || actual_type=
                    if [[ -n "$actual_type" && "$actual_type" != ${lib.escapeShellArg (readType value)} ]]; then
                      # defaults preserves equal numeric values even when their types differ.
                      ${run "/usr/bin/defaults delete ${lib.escapeShellArg domain} ${lib.escapeShellArg name}"} || exit 1
                    fi
                    ${run "/usr/bin/defaults write ${lib.escapeShellArg domain} ${lib.escapeShellArg name} ${valueType value} ${lib.escapeShellArg (writeValueString value)}"}
                  ); then
                    printf '%s\n' ${lib.escapeShellArg "Could not apply ${domain}.${name}. Check preference permissions; protected apps may require Full Disk Access for your terminal. Run `just switch` again after fixing access."} >&2
                  fi
                '') preferences
              )}
            fi
          fi
        '';
    in
    {
      options.dotfiles.appPreferences = lib.mkOption {
        default = { };
        description = "Application preferences applied after quitting the application if it is running.";
        type = lib.types.attrsOf (
          lib.types.submodule (
            { config, ... }:
            {
              options = {
                domain = lib.mkOption {
                  type = lib.types.str;
                  description = "macOS preferences domain.";
                };
                bundleId = lib.mkOption {
                  type = lib.types.str;
                  default = config.domain;
                  defaultText = lib.literalExpression "domain";
                  description = "Bundle identifier used to quit and reopen the application.";
                };
                processName = lib.mkOption {
                  type = lib.types.str;
                  description = "Exact process name used to detect whether the application is running.";
                };
                preferences = lib.mkOption {
                  type = lib.types.attrsOf (
                    lib.types.oneOf [
                      lib.types.bool
                      lib.types.int
                      lib.types.float
                      lib.types.str
                    ]
                  );
                  default = { };
                  description = "Preference keys and scalar values to apply.";
                };
              };
            }
          )
        );
      };

      config.system.activationScripts.postActivation.text = lib.mkMerge [
        (lib.mkBefore "app_preferences_reopen=()")
        (lib.mkAfter (
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              name: settings:
              applyPreferences {
                prefix = "app_preferences_${builtins.hashString "sha256" name}";
                inherit (settings)
                  domain
                  bundleId
                  processName
                  preferences
                  ;
              }
            ) config.dotfiles.appPreferences
          )
        ))
        # Reopen apps after every module's writers have run.
        (lib.mkOrder 2000 (reopenApps {
          run = runAsUser;
        }))
      ];
    };
}
