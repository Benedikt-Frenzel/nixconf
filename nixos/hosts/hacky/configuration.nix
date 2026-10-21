{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.hacky = inputs.nixpkgs.lib.nixosSystem {
    modules = [self.nixosModules.hostHacky];
  };

  flake.nixosModules.hostHacky = {
    config,
    pkgs,
    ...
  }: let
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9tV5OCfsjlyLiPOwQZsx6NmK6D9KCD8iGmUnQF9/Bz geeky"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEL3NtSts+8/pinDJvYomly274c/8EHCFPCkdMLbxOxt ben@hacky"
    ];
  in {
    imports = [
      ../_server-firewall.nix
      ../_wireguard.nix
    ];

    # EDIS Global instance kvm_140854_784778, BIOS boot.
    nixpkgs.hostPlatform = "x86_64-linux";
    boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "virtio_blk" "virtio_net" "sd_mod" "sr_mod"];
    boot.kernelModules = ["kvm-intel"];
    boot.loader.grub = {
      enable = true;
      device = "/dev/vda";
    };

    fileSystems."/" = {
      device = "/dev/mapper/cryptroot";
      fsType = "ext4";
    };
    fileSystems."/boot" = {
      device = "/dev/disk/by-label/hacky-boot";
      fsType = "ext4";
      options = ["nodev" "nosuid" "noexec"];
    };
    swapDevices = [
      {
        device = "/var/lib/swapfile";
        size = 2048;
      }
    ];

    boot.initrd = {
      luks.devices.cryptroot.device = "/dev/disk/by-partlabel/hacky-cryptroot";
      systemd = {
        enable = true;
        network = {
          enable = true;
          networks = config.systemd.network.networks;
        };
        users.root.shell = pkgs.writeShellScript "unlock-root" ''
          exec /bin/systemd-tty-ask-password-agent --query --watch
        '';
        # Custom login shells are not automatically copied into the initrd.
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
      hostName = "hacky";
      useDHCP = false;
      useNetworkd = true;
      nameservers = ["9.9.9.9" "149.112.112.112"];
    };
    services.resolved.settings.Resolve.FallbackDNS = "";
    systemd.network.networks."10-uplink" = {
      matchConfig.MACAddress = "52:54:00:0b:f9:8b";
      address = [
        "149.154.159.86/24"
        # EDIS documents /24 for additional IPv4 addresses, too.
        "158.255.214.250/24"
        "45.151.74.182/24"
        # The assigned /64 is part of EDIS's shared on-link /48.
        "2a03:f80:49:965e::1/48"
      ];
      routes = [
        {Gateway = "149.154.159.1";}
        {Gateway = "2a03:f80:49::1";}
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
        "10.254.100.2/30"
        "fd00:254:100::2/64"
      ];
      vyosPublicKey = "BtWRADnhnaycbt16+t026KH9mAyY3GNqSj9rMeDAQhw=";
      endpoint = "home.okt.bfr.sh:51910";
      listenPort = 51910;
      routerIPv4 = "89.57.115.113";
      allowedIPs = [
        # Router and the other server.
        "10.254.100.1/32"
        "10.254.101.0/30"
        "fd00:254:100::1/128"
        "fd00:254:101::/64"
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
