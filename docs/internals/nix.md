# Nix and flake inputs

## Checking the flake

`nix flake check` does not evaluate `darwinConfigurations`, so a mistyped
`darwin` or `homeManager` option passes it. `just check` therefore also
evaluates `darwinConfigurations.<host>.system.drvPath` for every host. That
evaluates each full system, Home Manager included, without building it. A
flake check would not fit here, because `nix flake check` builds checks and
`systems` covers every system in `lib.systems.flakeExposed`.

## Agent tools and skills

Claude Code and Codex come from numtide's `llm-agents` flake in
`modules/apps/llm-agents.nix`. It leaves its nixpkgs unfollowed so numtide's
binary cache matches. Run `nix flake update llm-agents` to pick up new releases.

Agent skills come from t3dotgg's `tstack` flake input. `modules/ai/skills.nix`
links every directory under its `skills/` into `~/.claude/skills` and
`~/.codex/skills`. Run `nix flake update tstack` to pick up new releases.

## nixpkgs

Keep shared nixpkgs settings in `modules/nixpkgs.nix`. Its `perSystem` package
set and Darwin aspect use the same configuration and overlays.

## Home Manager backups

Tools such as `git config --global` replace a managed symlink with a regular
file. On the next activation Home Manager moves that file to `<name>.backup`.
`modules/home-manager.nix` sets `overwriteBackup`, so an existing `.backup` is
deleted and replaced by the newer file. Only the latest backup survives.
Without that option, an existing `.backup` aborts activation.

## Garbage collection

`modules/nix-settings.nix` schedules Nix garbage collection daily at 04:00 local
time. It deletes generations older than 30 days and collects unreferenced store
paths. The current generation remains protected. The same job runs store
optimisation after garbage collection succeeds to deduplicate identical files.

## Nix base template

The reusable Nix base lives in `modules/templates/_nix-base` and is exposed
through `modules/templates/default.nix`. Keep the template under `_nix-base/` so
import-tree excludes its modules from the parent flake.

- Keep it general, without host, user, or OS-specific declarations.
- Define template Nix settings through `flake-file.nixConfig` and package
  configuration through `perSystem`.
- Run its `just write-flake` from that directory when changing its dependency
  declarations.
- The template is its own flake with its own `flake.lock`. Updating all of its
  inputs at once is fine. The scoped-update rule in `AGENTS.md` covers only the
  root lock.
- After updating its inputs, run its `just write-flake` too. Newer flake-file
  revisions change the generated header and default input URLs, and its
  `check-flake-file` check fails until `flake.nix` is regenerated. Run
  `nix flake lock` afterwards when a generated input URL changed.
- Keep its `flake-file.url` the same as the root's in `modules/bootstrap.nix`.
- The root `just check` runs
  `nix flake check path:./modules/templates/_nix-base`.
