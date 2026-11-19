# App preferences

## Quitting and reopening apps

Apps with managed preferences are quit before writing and reopened in the
background afterwards.

- `modules/_lib/quit-app.nix` provides `quitApp`, which quits a running app
  through its bundle ID, waits up to 30 seconds, and queues it in
  `app_preferences_reopen`. `reopenApps` reopens the queue.
- Quit an app only after checking that its settings differ, so unchanged apps
  keep running.
- If an app does not quit, the helper warns once per app and the writers skip
  it.
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
