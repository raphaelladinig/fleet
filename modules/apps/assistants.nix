{ den, ... }:
{
  den.aspects.apps.assistants.includes = [ den.aspects.homebrew ];

  den.aspects.apps.assistants.darwin.homebrew.casks = [
    "chatgpt"
    "claude"
    "wispr-flow"
  ];
}
