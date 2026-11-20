# App preferences

## Quitting and reopening apps

Apps with managed preferences are quit before writing and reopened in the
background afterwards.

- `modules/_lib/quit-app.nix` provides `quitApp`, which quits a running app
  through its bundle ID, waits up to 30 seconds, and queues it in
  `app_preferences_reopen`. `reopenApps` reopens the queue.
- `quitApp` takes the user name and looks up the UID itself. Pass a Nix string,
  not a shell fragment. A double-quoted Nix string that held a shell variable
  once reached `pgrep` as literal text, so the helper never saw a running app.
- Quit an app only after checking that its settings differ, so unchanged apps
  keep running.
- If an app does not quit, the helper warns once per app and the writers skip
  it.
- If the app's process is an ancestor of the activation, such as the terminal
  running `just switch`, the helper skips the quit with a warning and treats it
  as a failed quit. Quitting it would end activation partway through. The
  helper calls `pgrep -a`, because macOS `pgrep` otherwise hides its own
  ancestors. A terminal whose shells run under a detached server outside the
  app's process tree, as Rex's do, is not detected this way.
- macOS may ask the terminal for Automation permission the first time.
- `modules/_lib/run-as-user.nix` provides `runAsUser`, which prefixes a command
  so that it runs as the given user in that user's launchd session. Darwin
  activation runs as root, so user defaults and files under the user's home
  need it. It passes `--set-home` to `sudo` by default, so scripts that read
  `HOME` find the user's files. The user defaults step in
  `modules/macos/default.nix` passes `setHome = false`. It only runs
  `defaults`, which finds the user's preferences whatever `HOME` holds.

## Restarting upgraded casks

`modules/homebrew/restart-casks.py` restarts apps that `brew bundle` upgrades
during activation. Without it, an upgraded app keeps running its old version,
or stays closed when its cask quits it before replacing it.

- Before `brew bundle`, the script records installed cask versions and the
  PID and executable path of every process. Afterwards it handles only casks
  whose version changed and whose app's `CFBundleExecutable` was running at
  that first snapshot. Match that exact path. Bundles such as KeePassXC and
  Vicinae keep other executables in `Contents/MacOS`, and KeePassXC's
  `keepassxc-proxy` runs for browser integration while the app is closed.
- If a recorded PID still runs, the app is quit through its bundle ID and
  reopened in the background. If the app runs under a new PID, it already
  relaunched on the new version and is left alone. If it is not running,
  Homebrew quit it, and it is reopened. Apps that were not running stay
  closed.
- An app that runs the activation is skipped with a warning, like `quitApp`.
- An EXIT trap runs the restart when `brew bundle` fails, because failure ends
  activation after Homebrew may have quit an app.
- Only `app` artifacts under `/Applications` or an absolute target are handled.
  Casks that install through `pkg`, such as `tailscale-app`, are skipped.
- `brew bundle` does not upgrade `auto_updates` casks unless they are greedy,
  so most casks here update themselves and never reach this step.

## Scalar defaults

Use `dotfiles.appPreferences` from `modules/app-preferences.nix` for scalar
defaults. `bundleId` defaults to `domain`. The Darwin activation reopens quit
apps after all preference writers have run.

- Preserve its behavior of checking both value and scalar type and quitting the
  app only when a value differs.
- Compare strings and floats through `defaults export` and the declared
  Python's plist parser, using literal dictionary keys. `defaults read` display
  escaping varies by macOS version, shell command substitution strips trailing
  newlines, and `defaults read` prints `15` where Nix renders `15.000000`.
- Remove mistyped keys before rewriting, because `defaults` can preserve the old
  numeric type for equal values.

## App-owned configuration files

Follow `modules/apps/keepassxc.nix`. Merge managed keys while preserving other
settings, quit the app only when the merge changes the file, and merge again
after quitting because the app may save its settings on exit.

KeePassXC merges settings in a separate script, so failures stop the merge even
when Home Manager catches its exit status.

- The script reopens KeePassXC on exit.
- Failed updates warn and continue activation.
- Stage replacements beside the destination before renaming them, to preserve
  existing settings on failure.
- Home Manager dry runs skip the script.

## Safari AutoFill

The macOS "AutoFill Passwords and Passkeys" toggle is managed in
`modules/macos/default.nix` through `com.apple.Safari.AutoFillPasswords`. It
uses the app-preferences helper, which quits Safari when the value differs.
Writing Safari's protected preferences may require Full Disk Access for the
terminal running activation.

## Failed writes

Failed preference writes print a warning and allow activation to continue. Fix
access and reapply to enforce any settings that could not be written.

A check that cannot read a settings file must not count as a difference, or
every switch quits the app. Give the check a separate exit status for that case,
warn, and skip that file's writer, as the Helium writers do.

## LinearMouse

LinearMouse settings live in `modules/apps/linearmouse/linearmouse.json` and
replace `~/.config/linearmouse/linearmouse.json` as a copy, because LinearMouse
writes the file when its settings change. The activation compares parsed JSON,
since LinearMouse rewrites the file in its own formatting, and quits LinearMouse
only when the content differs.
