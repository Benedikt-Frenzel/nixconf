{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.geeky = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.hostGeeky
    ];
  };

  flake.nixosModules.hostGeeky = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.base
      self.nixosModules.general
      self.nixosModules.desktop

      self.nixosModules.discord
      self.nixosModules.gimp
      self.nixosModules.telegram
      self.nixosModules.youtube-music
      self.nixosModules.obsidian
      self.nixosModules.gramps
      self.nixosModules.syncthing
      self.nixosModules.rclone
      self.nixosModules.ausweisapp
      # OpenSnitch nervt zu sehr, das Modul bleibt vorerst im Repo.
      # Reaktivieren: self.nixosModules.opensnitch
      self.nixosModules.secureboot
      self.nixosModules.nitrokey
      self.nixosModules.scanner
      self.nixosModules.fwupd

      self.nixosModules.gaming
    ];

    preferences.user.name = "ben";

    users.users.${config.preferences.user.name} = {
      description = lib.mkForce "Benedikt";
      hashedPasswordFile = lib.mkForce null;
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.binfmt.emulatedSystems = ["aarch64-linux"];

    # TEST: kernel 7.2.11 with the i915 driver. The xe driver does not
    # support the Meteor Lake iGPU (device 7d55), so the iGPU stays on
    # i915. This only tests whether kernel 7 works on this machine at all.
    # Drop the override to go back to the default kernel (6.18).
    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking = {
      hostName = "geeky";
      networkmanager.enable = true;
    };

    time.timeZone = lib.mkForce "Europe/Berlin";
    i18n.extraLocaleSettings = lib.mkForce {
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

    services.xserver.xkb = {
      layout = "de,us";
      options = "grp:alt_shift_toggle";
    };
    console.keyMap = "de";

    programs.niri.package = lib.mkForce (
      inputs.wrapper-modules.wrappers.niri.wrap {
        inherit pkgs;
        imports = [self.wrappersModules.niri];
        xkbLayout = "de,us";
      }
    );

    services.printing.enable = true;

    environment.systemPackages = with pkgs; [
      winetricks
      glib
      android-tools
      orca-slicer
    ];

    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
    xdg.portal.enable = true;

    programs.appimage.enable = true;
    programs.appimage.binfmt = true;

    system.stateVersion = "26.05";
  };
}
