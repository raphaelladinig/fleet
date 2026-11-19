{
  den.aspects.apps.rex.homeManager =
    { pkgs, ... }:
    let
      rex = pkgs.stdenvNoCC.mkDerivation {
        pname = "rex";
        version = "0.1.0-preview.32";

        src = pkgs.fetchurl {
          url = "https://blob.superlogical.com/download/rex-app/preview/latest.dmg";
          name = "Rex.dmg";
          hash = "sha256-Pw+ZqxjvH4p4BYmW/M+pD1XOZZDmjhV5ckQaoahJ0ik=";
        };

        nativeBuildInputs = [ pkgs.undmg ];
        sourceRoot = ".";
        dontFixup = true;

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/Applications"
          cp -R Rex.app "$out/Applications/"
          runHook postInstall
        '';

        meta.platforms = pkgs.lib.platforms.darwin;
      };
    in
    {
      home.packages = [ rex ];
    };
}
