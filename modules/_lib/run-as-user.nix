{ lib }:
{
  # Shell command prefix that runs `command` as `user` in that user's launchd
  # session.
  runAsUser =
    {
      user,
      setHome ? true,
    }:
    command:
    ''launchctl asuser "$(id -u -- ${lib.escapeShellArg user})" sudo --user=${lib.escapeShellArg user} ${lib.optionalString setHome "--set-home "}-- ${command}'';
}
