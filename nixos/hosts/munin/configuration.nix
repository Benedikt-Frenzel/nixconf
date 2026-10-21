{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.munin = inputs.nixpkgs.lib.nixosSystem {
    modules = [self.nixosModules.hostMunin];
  };

  flake.nixosModules.hostMunin = {
    config,
    pkgs,
    ...
  }: let
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9tV5OCfsjlyLiPOwQZsx6NmK6D9KCD8iGmUnQF9/Bz geeky"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIGA0k82RpXiZGwR1X7LcVv63NfsGyfPE1X3Ag7ipOC+ ben@munin"
    ];
  in {
    imports = [
      ../_server-firewall.nix
      ../_wireguard.nix
    ];

    nixpkgs.hostPlatform = "x86_64-linux";
    boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "virtio_net"];
    boot.loader.grub = {
      enable = true;
      # Stable across attaching/detaching Hostinger's recovery disk.
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
    };
    fileSystems."/" = {
      device = "/dev/mapper/cryptroot";
      fsType = "ext4";
    };
    fileSystems."/boot" = {
      device = "/dev/disk/by-label/munin-boot";
      fsType = "ext4";
      options = ["nodev" "nosuid" "noexec"];
    };
    swapDevices = [
      {
        device = "/var/lib/swapfile";
        size = 4096;
      }
    ];

    boot.initrd = {
      luks.devices.cryptroot.device = "/dev/disk/by-partlabel/munin-cryptroot";
      systemd = {
        enable = true;
        network = {
          enable = true;
          networks = config.systemd.network.networks;
        };
        users.root.shell = pkgs.writeShellScript "unlock-root" ''
          exec /bin/systemd-tty-ask-password-agent --query --watch
        '';
        storePaths = [config.boot.initrd.systemd.users.root.shell];
      };
      network.ssh = {
        enable = true;
        port = 2222;
        hostKeys = ["/etc/secrets/initrd/ssh_host_ed25519_key"];
        inherit authorizedKeys;
      };
    };

    networking = {
      hostName = "munin";
      useDHCP = false;
      useNetworkd = true;
      nameservers = ["9.9.9.9" "149.112.112.112"];
    };
    systemd.network.networks."10-uplink" = {
      matchConfig.MACAddress = "64:e8:d4:c1:64:45";
      address = ["187.127.73.243/24" "2a02:4780:79:ab5e::1/48"];
      routes = [
        {Gateway = "187.127.73.254";}
        {Gateway = "2a02:4780:79::1";}
      ];
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "ipv6";
      };
    };

    # Site-to-site tunnel to the VyOS router, see docs/vyos.md.
    wireguardS2S = {
      enable = true;
      ips = [
        "10.254.101.2/30"
        "fd00:254:101::2/64"
      ];
      vyosPublicKey = "qE30WRklLLjQG2W+viXEVx9IMjTO+0ECZHKjm9FxUE4=";
      endpoint = "home.okt.bfr.sh:51911";
      listenPort = 51911;
      routerIPv4 = "89.57.115.113";
      allowedIPs = [
        # Router and the other server.
        "10.254.101.1/32"
        "10.254.100.0/30"
        "fd00:254:101::1/128"
        "fd00:254:100::/64"
      ];
    };

    users.mutableUsers = false;
    users.users.root = {
      hashedPasswordFile = "/var/lib/secrets/root-password-hash";
      openssh.authorizedKeys.keys = authorizedKeys;
    };
    users.users.ben = {
      isNormalUser = true;
      description = "Benedikt";
      extraGroups = ["wheel"];
      hashedPasswordFile = "/var/lib/secrets/ben-password-hash";
      openssh.authorizedKeys.keys = authorizedKeys;
    };
    security.sudo.wheelNeedsPassword = false;
    services.openssh = {
      enable = true;
      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
        X11Forwarding = false;
      };
    };
    nix.settings.experimental-features = ["nix-command" "flakes"];
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    nix.optimise.automatic = true;
    environment.systemPackages = with pkgs; [git vim curl htop kitty.terminfo];
    time.timeZone = "Europe/Berlin";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "de";
    system.stateVersion = "26.05";
  };
}
