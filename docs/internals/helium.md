# Helium

Helium's configuration lives in `modules/apps/helium/`. It builds on the quit
and reopen helpers in [App preferences](app-preferences.md).

## Preferences

`preferences.json` and `local-state.json` contain curated settings, not profile
exports. Keep account data, history, identifiers, and extension state out of
these files.

- Darwin activation runs each writer with `--check` first. When any reports a
  difference, it quits Helium and merges them as the primary user.
- All Helium preference writers run in the same activation shell, so the quit
  helper quits Helium at most once and emits one warning per app.
- Search uses macOS recommended policies to avoid editing protected search
  preferences.
- Each Python preference writer warns on failure and lets the remaining writers
  and activation continue. Failed writes leave invalid JSON and locked databases
  intact. Fix the reported access, file contents, or database lock issue and run
  `just switch` again.

## Extensions

`extensions.csv` is the source for Helium's macOS `ExtensionInstallForcelist`
and the `ExtensionSettings` toolbar pins. Blank pin values leave pinning
unmanaged. Keep the CSV updated when adding or removing forced extensions.

Home Manager builds a user configuration profile at
`~/.config/helium/extensions.mobileconfig`. Open it and install it in System
Settings > General > Device Management after activation and whenever the CSV
changes. Stable profile identifiers allow an updated profile to replace the
installed one.

- Do not write directly to `/Library/Managed Preferences`; macOS regenerates it.
- Removing the Nix configuration does not uninstall the profile. Remove it
  through Device Management.

## Dark Reader

`apply-dark-reader.py` sets Dark Reader to "Invert listed only" in the Default
profile's local and sync extension stores.

- Its `--check` mode reads copies of the stores, because a running Helium holds
  the LevelDB lock.
- It migrates legacy site lists using their original mode before setting the
  new mode and schema version.
- It preserves existing modern lists, sync list chunks, legacy entries, and
  unrelated settings.
- Each store migrates independently, so mixed versions and fresh stores keep the
  declared mode after Dark Reader starts.
