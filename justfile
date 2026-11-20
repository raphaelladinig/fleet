host := "Raphaels-MacBook"

default:
    @just --list

alias c := check
alias b := build
alias s := switch
alias u := update
alias uc := update-commit
alias w := write-flake

# Run all checks, including evaluating each host's system, which `nix flake check` skips
check:
    nix fmt -- --check $(find . -name '*.nix' -type f -print)
    nix develop --command bash -euo pipefail -c 'fish -n modules/apps/fish/config.fish; luacheck modules/apps/neovim .nvim; stylua --check modules/apps/neovim .nvim; node --check modules/macos/apply-wallpaper.js'
    nix develop --command python3 -B -c 'import sys; [compile(open(path, "rb").read(), path, "exec") for path in sys.argv[1:]]' $(find modules -name '*.py' -type f -print)
    nix flake check
    nix eval --json .#darwinConfigurations --apply 'builtins.mapAttrs (_: host: host.system.drvPath)'
    nix flake check path:./modules/templates/_nix-base

build hostname=host:
    nh darwin build . -H {{ hostname }}

switch hostname=host:
    nh darwin switch . -H {{ hostname }} --show-activation-logs

# Without names, this updates every input.
# just joins variadic arguments with spaces, so quote each name separately.
# `--` keeps nix from reading a name such as `--flake` as an option.

update *inputs:
    nix flake update {{ if inputs == "" { "" } else { "-- " + replace(quote(inputs), ' ', "' '") } }}

# Update every input, regenerate flake.nix, check, and commit only the flake files
update-commit:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! git diff --quiet HEAD -- flake.lock flake.nix; then
        echo "flake.lock or flake.nix has uncommitted changes" >&2
        exit 1
    fi
    just update
    just write-flake
    if git diff --quiet HEAD -- flake.lock flake.nix; then
        echo "Inputs are already up to date"
        exit 0
    fi
    just check
    git commit -m "chore(deps): update flake inputs" -- flake.lock flake.nix

write-flake:
    nix run .#write-flake
