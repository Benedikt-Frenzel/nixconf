{
  flake.nixosModules.syncthing = {config, ...}: let
    user = config.preferences.user.name;
    home = config.users.users.${user}.home;
  in {
    services.syncthing = {
      enable = true;
      inherit user;
      group = config.users.users.${user}.group;
      dataDir = home;
      configDir = "${home}/.local/state/syncthing";
      guiAddress = "127.0.0.1:8384";
      openDefaultPorts = true;

      # Keep the restored identity, peers and receive-only Music folder.
      # Keys and config.xml are restored locally, never through the Nix store.
      overrideDevices = false;
      overrideFolders = false;
      settings.folders = {
        private = {
          id = "obsidian-private";
          label = "Private";
          path = "${home}/Documents/Private";
          # Add peers here once selected; do not share private notes with every
          # device from the old Music configuration.
          devices = [];
          ignorePatterns = [
            ".obsidian/workspace.json"
            ".obsidian/workspace-mobile.json"
          ];
        };
        genealogy = {
          id = "obsidian-genealogy";
          label = "Genealogy";
          path = "${home}/Documents/Genealogy";
          devices = [];
          ignorePatterns = [
            ".obsidian/workspace.json"
            ".obsidian/workspace-mobile.json"
          ];
        };
        hochzeit = {
          id = "hochzeit";
          label = "Hochzeit";
          path = "${home}/Documents/Hochzeit";
          # Add peers here once selected; the rclone module bisyncs this
          # folder with Proton Drive and Google Drive on top.
          devices = [];
        };
      };
    };

    persistance.data.directories = [
      ".local/state/syncthing"
      "Music"
    ];
  };
}
