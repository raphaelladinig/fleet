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

## Dock apps

`modules/macos/default.nix` sets the Dock's `persistent-apps` in its own step
of the user defaults activation, not through `CustomUserPreferences`. Dock adds
keys such as GUIDs to every tile it stores. Rewriting the list on each switch
would change the Dock domain every time, and the restart check would then
restart Dock on every switch. The step compares only the app paths and writes
the list when they differ.

## Menu bar items

nix-darwin's `controlcenter` options write 18 for a shown item and 24 for a
hidden one. This macOS version stores 2 for shown items, so
`modules/macos/default.nix` writes the values directly to the ByHost
`com.apple.controlcenter` domain through `CustomUserPreferences`.

## Power settings

Display sleep and power modes are set with `pmset` in the `power` activation
script, once for battery and once for the power adapter. The script reads
`pmset -g custom` and changes only the values that differ.

## Input sources and LinearMouse

`modules/apps/input/default.nix` selects the Colemak-DH layout through
`com.apple.HIToolbox` and `com.apple.inputsources`. macOS may only pick up a
changed input source list after logging out and back in.

LinearMouse settings live in `modules/apps/input/linearmouse.json` and replace
`~/.config/linearmouse/linearmouse.json` as a copy, because LinearMouse writes
the file when its settings change. The activation compares parsed JSON, since
LinearMouse rewrites the file in its own formatting, and quits LinearMouse
only when the content differs.
