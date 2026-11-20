# Helium

Helium's configuration lives in `modules/apps/helium/`. It builds on the quit
and reopen helpers in [App preferences](app-preferences.md).

## Preferences

`preferences.json` and `local-state.json` contain curated settings, not profile
exports. Keep account data, history, identifiers, and extension state out of
these files.

- Quitting Helium loses its open tabs, because no session restore is
  configured. Only declare keys that the browser does not change in normal use.
- Put UI state that Helium changes as you use it, such as the sidebar width,
  collapsed sidebar, zen mode, and new tab page shortcuts, in
  `preferences-seed.json`. The writer adds seed keys only when they are absent,
  and `--check` ignores them, so changing them never quits Helium.
- Declared lists, such as `browser.enabled_labs_experiments` and
  `spellcheck.dictionaries`, list required members. The writer appends missing
  items and keeps extra items and their order. Chromium reads lab flags as a
  set. On macOS it resets the dictionary list when its first entry differs from
  the system spellchecker language, so the writer never reorders it.
- Darwin activation runs each writer with `--check` first. A check exits 0 when
  the file matches, 1 when it differs, and 2 when it could not read the file.
  When any check exits 1, activation quits Helium and runs the writers as the
  primary user. A file whose check exited 2 gets a warning and no writer, and
  never causes a quit.
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
  the LevelDB lock. A copy can fail while Helium compacts a store, so read
  errors exit 2. A missing store directory reads as empty, and the writer
  creates it.
- It migrates legacy site lists using their original mode before setting the
  new mode and schema version.
- It preserves existing modern lists, sync list chunks, legacy entries, and
  unrelated settings.
- Chromium limits each sync item to 8,192 bytes, counting the key plus the
  value as Chromium's JSON writer encodes it. Chunks are JSON strings, so
  escaping grows them. The script sizes each chunk by its encoded form and
  splits between characters, never inside one.
- Chromium also caps the whole sync store at 102,400 bytes and 512 items,
  counting every item already there. When the store would pass either limit
  after the pending writes, including a store that is already over a limit
  with nothing pending, the script does what Dark Reader does when sync
  rejects a write. It leaves the sync store alone, copies the sync settings
  with full lists into the local store, and sets the local `syncSettings` to
  `false`. While local `syncSettings` is `false`, Dark Reader reads only the
  local store, so the script skips the sync store.
- Otherwise each store migrates independently, so mixed versions and fresh
  stores keep the declared mode after Dark Reader starts.
