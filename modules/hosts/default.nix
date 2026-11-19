{ den, ... }:
{
  den.hosts.aarch64-darwin.macbook = {
    aspect = den.aspects.hosts.macbook;
    users.raphaelladinig.aspect = den.aspects.users.raphaelladinig;
  };
}
