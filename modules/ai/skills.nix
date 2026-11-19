{ inputs, ... }:
{
  flake-file.inputs.tstack = {
    url = "github:t3dotgg/tstack";
    flake = false;
  };

  den.aspects.ai.skills.homeManager =
    { lib, ... }:
    let
      skillsDirectory = "${inputs.tstack}/skills";
      skills = lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDirectory);
    in
    {
      home.file = lib.mergeAttrsList (
        map
          (
            directory:
            lib.mapAttrs' (
              name: _: lib.nameValuePair "${directory}/${name}" { source = "${skillsDirectory}/${name}"; }
            ) skills
          )
          [
            ".claude/skills"
            ".codex/skills"
          ]
      );
    };
}
