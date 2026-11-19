{ den, ... }:
{
  den.hosts.aarch64-darwin.Raphaels-MacBook = {
    aspect = den.aspects.hosts.Raphaels-MacBook;
    users.raphaelladinig.aspect = den.aspects.users.raphaelladinig;
  };
}
