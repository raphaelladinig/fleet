{ inputs, ... }:
{
  # Leave nixpkgs unfollowed so packages match numtide's binary cache.
  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  den.aspects.apps.llm-agents = {
    darwin.nix.settings = {
      substituters = [ "https://cache.numtide.com" ];
      trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
    };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
          claude-code
          codex
        ];
      };
  };
}
