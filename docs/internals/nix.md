# Nix and flake inputs

## Flake declarations

`flake.nix` is generated and is not the source of truth. Edit
`flake-file.inputs` and other flake declarations in `modules/`, then run
`just write-flake`.

`import-tree` discovers Nix modules recursively under `modules/` and skips
`_`-prefixed directories such as `modules/_lib/`. Put helper functions there and
import them explicitly.

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
- Validate it with `nix flake check path:./modules/templates/_nix-base`.
