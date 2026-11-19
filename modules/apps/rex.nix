{ den, ... }:
{
  den.aspects.apps.rex.includes = [
    den.aspects.app-preferences
    den.aspects.fonts
  ];

  den.aspects.apps.rex.darwin.dotfiles.appPreferences.rex = {
    domain = "com.superlogical.rex";
    processName = "Rex";
    preferences = {
      SUAutomaticallyUpdate = true;
      SUEnableAutomaticChecks = true;
      "Workspace.activityGrouping" = "priority";
      "Workspace.appIcon" = "default";
      "Workspace.appearance" = "system";
      "Workspace.darkThemeID" = "roasted-umber";
      "Workspace.inactivePaneFadeMode" = "both";
      "Workspace.interfaceStyle" = "blendTheme";
      "Workspace.lightThemeID" = "peach-veranda";
      "Workspace.sidebarPosition" = "right";
      "Workspace.sidebarShowsActivity" = false;
      "Workspace.sidebarShowsOnlyOnlineHosts" = false;
      "Workspace.tabIconTintMode" = "off";
      "Workspace.tabStyle" = "vertical";
      "Workspace.terminalFontName" = "CaskaydiaCove Nerd Font Mono";
      "Workspace.terminalFontPointSize" = 15.0;
      "Workspace.usesGestures" = true;
      "Workspace.usesPaneGlass" = false;
      "Workspace.usesStandardInactiveWindowPaneStyles" = true;
      "rex.server.automatic-restart-enabled" = true;
      "rex.server.block-plugin-reload-enabled" = false;
      "rex.server.run-mode" = "bundled";
    };
  };

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
