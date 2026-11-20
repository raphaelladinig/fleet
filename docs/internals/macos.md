# macOS

macOS system settings live in `modules/macos/`. Settings that quit an app
before writing use the helpers in [App preferences](app-preferences.md).

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

`modules/macos/default.nix` sets display sleep and power modes with `pmset` in
the `power` activation script, once for battery and once for the power adapter.
The script reads `pmset -g custom` and changes only the values that differ.

The screen lock delay is not set by activation. `sysadminctl -screenLock`
refuses to change it without the user's password and still exits 0. Activation
reads the status as the user and prints the fix command when the delay is not
immediate.

## Colemak-DH and input sources

`modules/macos/colemak-dh.nix` installs the `colemak-dh` cask and selects the
layout through `com.apple.HIToolbox` and `com.apple.inputsources`. The setting
names a layout that only the cask provides, so both stay in one aspect.

`den.aspects.macos.colemak-dh` is a separate aspect. `den.aspects.macos` does
not include it. The user aspect in `modules/users/` selects it.

macOS may only pick up a changed input source list after logging out and back
in.
