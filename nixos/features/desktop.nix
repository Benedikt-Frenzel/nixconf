{self, ...}: {
  flake.nixosModules.desktop = {
    pkgs,
    config,
    lib,
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

    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session.command = lib.escapeShellArgs [
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--asterisks"
        "--remember"
        "--user-menu"
        "--greeting"
        "geeky"
        "--cmd"
        (lib.getExe' config.programs.niri.package "niri-session")
        "--sessions"
        "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
        "--theme"
        "border=${self.theme.base0B};text=${self.theme.base06};prompt=${self.theme.base0B};time=${self.theme.base0A};action=${self.theme.base09};button=${self.theme.base0B};container=${self.theme.base00};input=${self.theme.base07}"
      ];
    };

    # tuigreet's power menu runs systemctl as the greeter user.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.user == "greeter" && (
          action.id == "org.freedesktop.login1.reboot" ||
          action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
          action.id == "org.freedesktop.login1.power-off" ||
          action.id == "org.freedesktop.login1.power-off-multiple-sessions"
        )) {
          return polkit.Result.YES;
        }
      });
    '';

    security.polkit.enable = true;

    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [user];
    };

    environment.sessionVariables.SSH_AUTH_SOCK = "/home/${user}/.1password/agent.sock";

    hjem.users.${user}.files = {
      ".config/opencode/opencode.json".text = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        mcp = {
          "1password" = {
            type = "local";
            command = ["1password-mcp"];
            enabled = true;
          };
        };
      };

      # 1Password ignores a symlinked agent.toml, so this has to be a real file.
      # Vault is $HOSTNAME#$USER, for example geeky#ben.
      ".config/1Password/ssh/agent.toml" = {
        type = "copy";
        text = ''
          [[ssh-keys]]
          vault = "${config.networking.hostName}#${user}"
        '';
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
