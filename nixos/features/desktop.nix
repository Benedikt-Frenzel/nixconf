{self, ...}: {
  flake.nixosModules.desktop = {
    pkgs,
    config,
    ...
  }: let
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
    user = config.preferences.user.name;
    pcmanfm = pkgs.pcmanfm.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -f $out/share/applications/pcmanfm-desktop-pref.desktop
      '';
    });
  in {
    imports = [
      self.nixosModules.gtk

      self.nixosModules.pipewire
      self.nixosModules.firefox
      self.nixosModules.chromium
    ];

    programs.niri.enable = true;
    programs.niri.package = selfpkgs.niri;

    # preferences.autostart = [selfpkgs.quickshellWrapped];
    preferences.autostart = [selfpkgs.noctalia-shell];

    environment.systemPackages = [
      selfpkgs.terminal
      pcmanfm
      selfpkgs.noctalia-shell
    ];

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      ubuntu-sans
      cm_unicode
      corefonts
      unifont
    ];

    fonts.fontconfig.defaultFonts = {
      serif = ["Ubuntu Sans"];
      sansSerif = ["Ubuntu Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
    };

    time.timeZone = "Europe/Berlin";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "de_DE.UTF-8";
      LC_IDENTIFICATION = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NAME = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TELEPHONE = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
    };

    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;

    # USB, trash and phone mounts for pcmanfm. Also pulls in udisks2.
    services.gvfs.enable = true;

    security.polkit.enable = true;

    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [user];
    };

    environment.sessionVariables.SSH_AUTH_SOCK = "/home/${user}/.1password/agent.sock";

    hjem.users.${user}.files.".config/opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      mcp = {
        "1password" = {
          type = "local";
          command = ["1password-mcp"];
          enabled = true;
        };
      };
    };

    persistance.data.directories = [
      ".config/1Password"
      ".local/share/1Password"
    ];

    hardware = {
      enableAllFirmware = true;

      bluetooth.enable = true;
      bluetooth.powerOnBoot = true;

      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
