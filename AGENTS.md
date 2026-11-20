# Dotfiles

Personal macOS dotfiles built with Nix flakes, nix-darwin, Home Manager, and Den
aspects. The flake declares one host, `Raphaels-MacBook`, with one user,
`raphaelladinig`.

This file holds the rules that apply to every change, the commands, and an index
of `docs/internals/`, where the detailed rules for each area live. Read the
internals file for an area before changing it.

## Ways to cause damage

1. **Applying without being asked.** `just switch` changes the live system. It
   runs Homebrew upgrades and cleanup, which removes packages absent from the
   declared configuration, and it can quit and reopen apps. Run it only when the
   task includes applying the configuration.
2. **Editing generated files.** `flake.nix` is generated. Edit
   `flake-file.inputs` and other flake declarations in `modules/`, then run
   `just write-flake`.
3. **Leaving new files untracked.** The flake is Git-backed. A file Git does not
   track is invisible to it, so its module silently does nothing.
4. **Broad dependency updates.** Keep dependency updates scoped to the task.
   Update a single input with `nix flake update <input>`.

## Where code lives

- `modules/` holds every Nix module. `import-tree` discovers them recursively
  and skips paths under a `_`-prefixed directory.
- `modules/hosts/` and `modules/users/` select the aspects each host and user
  gets.
- `modules/apps/` keeps each app's packages and configuration together. Apps
  without configuration go in a group aspect by purpose, such as `apps.media`
  or `apps.utilities`. Give an app its own aspect once it gains configuration.
- `modules/macos/` holds macOS system settings.
- `modules/ai/` installs agent instructions and skills.
  `modules/ai/agents-md/AGENTS.md` is the global instruction file it links into
  `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. It does not apply to this
  repository.
- `modules/_lib/` holds helper functions. Import them explicitly.
- `modules/templates/` exposes the reusable Nix base from
  `modules/templates/_nix-base/`.

## Conventions

- Define features under `den.aspects` and compose them with `includes`.
  Discovery makes an aspect available; a host, user, or included aspect must
  select it. Follow `modules/hosts/` and `modules/users/` for that wiring.
- Put system settings in an aspect's `darwin` module and user configuration in
  its `homeManager` module. Request `config`, `pkgs`, and other class-specific
  arguments inside that module's function.
- Use `<name>.nix` for standalone modules. For modules with supporting files,
  keep the entry point at `<name>/default.nix` and the supporting files in that
  directory, as in `modules/ai/agents-md/default.nix`. When adding supporting
  files to an existing module, move its entry point and update its relative
  paths.
- Declare an app's shared dependencies through its aspect's `includes`.
- Install macOS GUI apps as Homebrew casks and CLI tools from Nix. Rex has no
  cask, so `modules/apps/rex.nix` pins a versioned DMG and turns off Sparkle
  updates.
- Declare cross-aspect `dotfiles.*` flags in `modules/defaults.nix` so consumers
  can read them when the providing aspect is absent. Follow the KeePassXC flag
  pattern. Keep feature-local options in their owning module.
- Fish, Neovim, and agent instructions use Nix-managed files through
  `home.file` with relative source paths. Edits require a rebuild and
  activation.

## Verifying

Enter `nix develop` when repository tools are missing from the shell.

| Change | Command |
| --- | --- |
| Any code or configuration | `just check` checks Nix formatting, Fish, JavaScript, and Python syntax, Lua linting and formatting, the flake, the Nix base template, and every host's system configuration, evaluated without building |
| Host configuration | `just check`, then `just build Raphaels-MacBook` to build without activating |
| Applying the configuration, when the task asks | `just switch Raphaels-MacBook` |
| Documentation only | Review the diff and verify referenced paths and commands. A rebuild is unnecessary |

The flake host key matches the Unix and Bonjour local hostnames, so plain
`nh darwin` and `darwin-rebuild` find it without a host argument. Omitting the
host in `just` uses `Raphaels-MacBook`; name the intended host when working on
another machine.

## Commits

Use Conventional Commits: `type(scope): description`, with an optional scope.
Examples: `feat(neovim): add Python support` and `docs: update project
instructions`.

Git signs commits and tags with the SSH public key in `modules/apps/git.nix`.
KeePassXC must load the matching private key into the SSH agent before
committing.

## Documentation

- Keep this file short. It loads into every agent session. A rule that applies
  to one area goes in that area's internals file, linked from the index below.
- Write internals for what a maintainer would get wrong without them, such as
  constraints, their reasons, and traps the code does not show.
- Update the affected internals file in the same change as the code. When a
  rule changes, rewrite or remove the old text instead of appending another
  account.

## Internals index

| File | Read it when you change |
| --- | --- |
| [Nix and flake inputs](docs/internals/nix.md) | Flake inputs, the `just check` recipe, `llm-agents`, `tstack` skills, nixpkgs settings, Home Manager backups, garbage collection, or the Nix base template |
| [App preferences](docs/internals/app-preferences.md) | macOS defaults, app-owned settings files, the quit and reopen helpers, KeePassXC settings, or Safari AutoFill |
| [Helium](docs/internals/helium.md) | Helium preferences, extensions and the device management profile, or Dark Reader settings |
| [Neovim](docs/internals/neovim.md) | Anything under `modules/apps/neovim/` |
