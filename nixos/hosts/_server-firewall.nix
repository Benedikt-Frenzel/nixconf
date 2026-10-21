{
  config,
  pkgs,
  ...
}: let
  adminIPv4 = "89.57.115.113/32";
  host = config.networking.hostName;
  initrdRules = pkgs.writeText "${host}-initrd-firewall.nft" ''
    table inet ${host}-initrd {
      chain input {
        type filter hook input priority filter; policy drop;
        iifname "lo" accept
        ct state invalid drop
        ct state established,related accept
        ip saddr ${adminIPv4} tcp dport ${toString config.boot.initrd.network.ssh.port} accept
        icmp type { destination-unreachable, time-exceeded, parameter-problem } accept
        icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
      }
      chain forward {
        type filter hook forward priority filter; policy drop;
      }
    }
  '';
in {
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    filterForward = true;
    allowPing = false;
    # No global SSH port opening: this IPv4 source is the only exception.
    extraInputRules = ''
      ip saddr ${adminIPv4} tcp dport 22 accept comment "SSH from home"
    '';
  };
  services.openssh.openFirewall = false;

  # The regular NixOS firewall does not run in the initrd. Protect the
  # remote-unlock listener before bringing up its network, for both families.
  boot.initrd.kernelModules = ["nf_tables" "nf_conntrack" "nft_ct"];
  boot.initrd.systemd = {
    storePaths = ["${pkgs.nftables}/bin/nft" initrdRules];
    services."${host}-firewall" = {
      description = "Restrict remote unlock to the admin IPv4 address";
      wantedBy = ["initrd.target"];
      requiredBy = ["systemd-networkd.service" "sshd.service"];
      after = ["systemd-modules-load.service"];
      before = ["systemd-networkd.service" "sshd.service" "initrd-switch-root.target" "shutdown.target"];
      conflicts = ["initrd-switch-root.target" "shutdown.target"];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.nftables}/bin/nft -f ${initrdRules}";
        # Do not leave the initrd's port-2222-only rules active in stage 2.
        ExecStop = "${pkgs.nftables}/bin/nft delete table inet ${host}-initrd";
      };
    };
  };
}
