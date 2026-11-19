# Project instructions

Personal macOS dotfiles using Nix flakes, nix-darwin, Home Manager, and Den aspects.
Keep project instructions here.

Use Conventional Commits for commit messages: `type(scope): description`.
The scope is optional. Examples: `feat(neovim): add Python support` and
`docs: update project instructions`.

Follow these conventions when changing configuration:

- Edit `flake-file.inputs` and other flake declarations in `modules/`, then run
  `just write-flake` to regenerate `flake.nix`. The generated file is not the
  source of truth. Keep dependency updates scoped to the task.
- `import-tree` discovers Nix modules recursively under `modules/`. Put helper
  functions in `_lib/`, which it excludes, and import those helpers explicitly.
  New files must be tracked by Git to participate in the Git-backed flake.
- Use `<name>.nix` for standalone modules. For modules with supporting files,
  keep the entry point at `<name>/default.nix` and the supporting files in that
  directory, as in `modules/ai/skills/default.nix`. When adding supporting files
  to an existing module, move its entry point and update its relative paths.
- Define features under `den.aspects` and compose them with `includes`.
  Discovery makes an aspect available; a host, user, or included aspect must
  select it. Follow `modules/hosts/` and `modules/users/` for that wiring.
- Put system settings in an aspect's `darwin` module and user configuration in
  its `homeManager` module. Request `config`, `pkgs`, and other class-specific
  arguments inside that module's function.
- Keep app packages and configuration together under `modules/apps/`.
  Declare shared dependencies through the app aspect's `includes`.
- Install macOS GUI apps as Homebrew casks and CLI tools from Nix. Claude Code
  and Codex come from numtide's `llm-agents` flake in `modules/apps/llm-agents.nix`,
  which leaves its nixpkgs unfollowed so numtide's binary cache matches. Run
  `nix flake update llm-agents` to pick up new releases.
- Keep shared nixpkgs settings in `modules/nixpkgs.nix`; its `perSystem` package
  set and Darwin aspect use the same configuration and overlays.
- Declare cross-aspect `dotfiles.*` flags in `modules/defaults.nix` so consumers
  can read them when the providing aspect is absent. Follow the KeePassXC flag
  pattern. Keep feature-local options in their owning module.
- Fish, Neovim, AI skills, and agent instructions use Nix-managed files through
  `home.file` with relative source paths. Edits require a rebuild and activation.

`modules/nix-settings.nix` schedules Nix garbage collection daily at 04:00
local time. It deletes generations older than 30 days and collects unreferenced
store paths. The current generation remains protected. The same job runs store
optimisation after garbage collection succeeds to deduplicate identical files.

Apps with managed preferences are quit before writing and reopened in the
background afterwards. `modules/_lib/quit-app.nix` provides `quitApp`, which
quits a running app through its bundle ID, waits up to 30 seconds, and queues it
in `app_preferences_reopen`. `reopenApps` reopens the queue. Quit an app only
after checking that its settings differ, so unchanged apps keep running. If an
app does not quit, the helper warns once per app and the writers skip it.
macOS may ask the terminal for Automation permission the first time.

For macOS app preferences, use `dotfiles.appPreferences` from
`modules/app-preferences.nix` for scalar defaults. Preserve its behavior of
checking both value and scalar type and quitting the app only when a value
differs. `bundleId` defaults to `domain`. The Darwin activation reopens quit apps
after all preference writers have run. Compare strings through `defaults export` and the declared
Python's plist parser, using literal dictionary keys. `defaults read` display
escaping varies by macOS version and shell command substitution strips trailing
newlines. Mistyped keys are removed before rewriting because `defaults`
can preserve the old numeric type for equal values. For app-owned
configuration files, follow
`modules/apps/keepassxc.nix`: merge managed keys while preserving other settings,
quit the app only when the merge changes the file, and merge again after quitting
because the app may save its settings on exit.
KeePassXC merges settings in a separate script so failures stop the merge even
when Home Manager catches its exit status. The script reopens KeePassXC on exit. Failed updates warn and continue
activation. Stage replacements beside the destination before renaming them to
preserve existing settings on failure. Home Manager dry runs skip the script.

The macOS "AutoFill Passwords and Passkeys" toggle is managed in
`modules/macos/default.nix` through `com.apple.Safari.AutoFillPasswords`.
It uses the app-preferences helper, which quits Safari when the value differs.
Writing Safari's protected preferences may require Full Disk Access for the
terminal running activation.
Failed preference writes print a warning and allow activation to continue. Fix
access and reapply to enforce any settings that could not be written.

Helium's `preferences.json` and `local-state.json` contain curated settings, not
profile exports. Keep account data, history, identifiers, and extension state out
of these files. Darwin activation runs each writer with `--check` first. When any
reports a difference, it quits Helium and merges them as the primary user. All
Helium preference writers run in the same activation shell so the quit helper
quits Helium at most once and emits one warning per app. Search uses
macOS recommended policies to avoid editing protected search preferences.
Each Python preference writer warns on failure and lets the remaining writers
and activation continue. Fix the reported access, file contents, or database
lock issue and run `just switch` again. Failed writes leave
invalid JSON and locked databases intact.

Helium's `extensions.csv` is the source for its macOS `ExtensionInstallForcelist`
and `ExtensionSettings` toolbar pins. Blank pin values leave pinning unmanaged.
Home Manager builds a user configuration profile at
`~/.config/helium/extensions.mobileconfig`. Open it and install it in System Settings
> General > Device Management after activation and whenever the CSV changes.
Stable profile identifiers allow an updated profile to replace the installed one.
Do not write directly to `/Library/Managed Preferences`; macOS regenerates it.
Keep the CSV updated when adding or removing forced extensions. Removing the Nix
configuration does not uninstall the profile; remove it through Device Management.

Helium's `apply-dark-reader.py` sets Dark Reader to "Invert listed only" in
the Default profile's local and sync extension stores. Its `--check` mode reads
copies of the stores because a running Helium holds the LevelDB lock.
It migrates legacy site lists using their original mode before setting the new
mode and schema version. It preserves existing modern lists, sync list chunks,
legacy entries, and unrelated settings. Each store migrates independently so
mixed versions and fresh stores keep the declared mode after Dark Reader starts.

Git signs commits and tags with the SSH public key in `modules/apps/git.nix`.
KeePassXC must load the matching private key into the SSH agent before committing.

For Neovim changes, read `modules/apps/neovim/default.nix` and `init.lua` before
adding a feature. Feature modules contribute files through
`dotfiles.neovim.configFiles`; `init.lua` discovers the linked Lua modules.
Language modules return `{ filetypes, setup }` and initialize on the first
matching filetype. Keep packages and plugins in Nix and runtime behavior in Lua.
Keep lazy triggers aligned with bundled server filetypes and formatter mappings.
Luacheck captures each buffer's filename and project config directory when lint
starts.

Use the recipes in `justfile` for validation and activation:

- Enter `nix develop` when repository tools are missing from the shell.
- For code or configuration changes, run `just check`. It checks Nix formatting,
  Fish, JavaScript, and Python syntax, Lua linting and formatting, and the flake.
  Python is compiled in memory without writing bytecode to the source tree.
- For changes to the host configuration, also run `just build macbook` to
  build without activation. Specify the intended host when working on another
  machine; omitting it uses `macbook`. The flake host key matches the Unix
  hostname, `macbook`. `modules/hosts/macbook.nix` sets the computer name to
  `Raphael’s MacBook` and the Bonjour local hostname to `Raphaels-MacBook`.
- Run `just switch macbook` when the task includes applying the configuration.
  Activation changes the live system and runs Homebrew upgrades and cleanup,
  including removal of packages absent from the declared configuration.
- For documentation-only edits, review the diff and verify referenced paths and
  commands. A Nix rebuild is unnecessary.

The reusable Nix base lives in `modules/templates/_nix-base` and is exposed
through `modules/templates/default.nix`. Keep the template under `_nix-base/` so
import-tree excludes its modules from the parent flake. Keep it general, without
host, user, or OS-specific declarations. Define template Nix settings through
`flake-file.nixConfig` and package configuration through `perSystem`. Run its `just write-flake`
from that directory when changing its dependency declarations. Validate it with
`nix flake check path:./modules/templates/_nix-base`.
