{ den, ... }:
{
  den.aspects.hosts.Raphaels-MacBook = {
    includes = [ den.aspects.macos ];

    darwin =
      { config, ... }:
      {
        networking = {
          computerName = "Raphael’s MacBook";
          hostName = "Raphaels-MacBook";
          localHostName = "Raphaels-MacBook";
        };

        # The uid must match the existing account, or nix-darwin skips the user.
        users.users.${config.system.primaryUser}.uid = 501;
      };
  };
}
