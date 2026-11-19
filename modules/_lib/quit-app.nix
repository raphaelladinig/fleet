{ lib }:
{
  # Shell condition that succeeds once the app is closed. A running app is asked
  # to quit and queued in app_preferences_reopen for reopenApps.
  quitApp =
    {
      processName,
      bundleId,
      uid,
      run ? command: command,
    }:
    let
      failed = "app_quit_failed_${builtins.hashString "sha256" processName}";
      isRunning = ''/usr/bin/pgrep -x -u "${uid}" ${lib.escapeShellArg processName} >/dev/null'';
      quitScript = ''if application id "${bundleId}" is running then tell application id "${bundleId}" to quit'';
    in
    ''
      {
        app_quit_status=0
        if [[ "''${${failed}:-}" == true ]]; then
          app_quit_status=1
        elif ${isRunning}; then
          printf '%s\n' ${lib.escapeShellArg "Quitting ${processName} to apply its settings."}
          # Some apps, such as KeePassXC, report -128 while quitting, so wait regardless.
          ${run "/usr/bin/osascript -e ${lib.escapeShellArg quitScript}"} >/dev/null 2>&1 || true
          app_quit_attempts=0
          while ${isRunning} && [[ "$app_quit_attempts" -lt 60 ]]; do
            /bin/sleep 0.5
            app_quit_attempts=$((app_quit_attempts + 1))
          done
          if ${isRunning}; then
            ${failed}=true
            app_quit_status=1
            printf '\033[1;33m%s\033[0m\n' ${lib.escapeShellArg "Could not quit ${processName}. Quit it, or allow your terminal to control it under System Settings > Privacy & Security > Automation, and run `just switch` again to apply its settings."}
          else
            app_preferences_reopen+=(${lib.escapeShellArg bundleId})
          fi
        fi
        [[ "$app_quit_status" -eq 0 ]]
      }'';

  reopenApps =
    {
      run ? command: command,
    }:
    ''
      for app_bundle_id in ''${app_preferences_reopen[@]+"''${app_preferences_reopen[@]}"}; do
        if ! ${run ''/usr/bin/open -g -b "$app_bundle_id"''}; then
          printf '%s\n' "Could not reopen $app_bundle_id after applying its settings." >&2
        fi
      done
      app_preferences_reopen=()
    '';
}
