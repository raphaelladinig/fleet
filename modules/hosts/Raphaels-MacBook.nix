{ den, ... }:
{
  den.aspects.hosts.Raphaels-MacBook = {
    includes = [
      den.aspects.home-manager
      den.aspects.macos
    ];

    darwin =
      { config, ... }:
      {
        networking = {
          computerName = "Raphael’s MacBook";
          hostName = "Raphaels-MacBook";
          localHostName = "Raphaels-MacBook";
        };

        # nix-darwin applies `users.users.<name>.shell` only to known users.
        # The uid must match the existing account, or nix-darwin skips it.
        users.knownUsers = [ config.system.primaryUser ];
        users.users.${config.system.primaryUser}.uid = 501;
      };
  };
}
