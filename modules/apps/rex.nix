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
      # Sparkle would update the Home Manager copy in place, and the next switch
      # restores the pinned build. Update by bumping the pin below.
      SUAutomaticallyUpdate = false;
      SUEnableAutomaticChecks = false;
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
      # Rex has no Homebrew cask. To update, take the newest enclosure URL from
      # https://blob.superlogical.com/public/rex-app/preview/appcast.xml and set
      # the URL, version, and hash. The latest.dmg URL changes with each release.
      rex = pkgs.stdenvNoCC.mkDerivation {
        pname = "rex";
        version = "0.1.0-2042";

        src = pkgs.fetchurl {
          url = "https://blob.superlogical.com/public/rex-app/preview/Rex-0.1.0-2042.dmg";
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
