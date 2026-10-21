{
  config,
  lib,
  ...
}: {
  options.wireguardS2S = {
    enable = lib.mkEnableOption "site-to-site WireGuard tunnel to the VyOS router";

    ips = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [
        "10.254.100.2/30"
        "fd00:254:100::2/64"
      ];
      description = "Tunnel addresses of this host (IPv4 and IPv6).";
    };

    vyosPublicKey = lib.mkOption {
      type = lib.types.singleLineStr;
      description = "Public key of the matching WireGuard interface on the VyOS router.";
    };

    endpoint = lib.mkOption {
      type = lib.types.str;
      example = "home.okt.bfr.sh:51910";
      description = ''
        VyOS endpoint as host:port. The router sits behind a dynamic IP, so
        use the DDNS name; it is re-resolved every five minutes.
      '';
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      example = 51910;
      description = ''
        UDP port the tunnel listens on. The router dials this port with the
        static public IPv4 of this host, so the firewall has to allow it.
      '';
    };

    routerIPv4 = lib.mkOption {
      type = lib.types.str;
      example = "89.57.115.113";
      description = ''
        Public IPv4 of the router. Only this address may reach the tunnel
        port.
      '';
    };

    allowedIPs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Networks reachable through the tunnel, in addition to the shared ones.";
    };
  };

  config = lib.mkIf config.wireguardS2S.enable {
    # IPv4 ping is blocked by the server firewall, ICMPv6 is not. Without this
    # rule the peers cannot answer a ping over the tunnel.
    networking.firewall.extraInputRules = ''
      iifname "wg0" icmp type echo-request accept comment "ICMP ping over the tunnel"
      ip saddr ${config.wireguardS2S.routerIPv4} udp dport ${toString config.wireguardS2S.listenPort} accept comment "WireGuard from the router"
    '';

    # The private key and the preshared key live in root-only files below
    # /var/lib/secrets, so that no secret ends up in the Nix store. Both files
    # have to exist before the tunnel is started, otherwise the key generator
    # service creates a random key that does not match the router.
    networking.wireguard.interfaces.wg0 = {
      privateKeyFile = "/var/lib/secrets/wireguard-private-key";
      ips = config.wireguardS2S.ips;
      listenPort = config.wireguardS2S.listenPort;
      # The endpoint is a DDNS name and has to be resolved again from time to
      # time. With the networkd backend this is a timer that reloads networkd.
      dynamicEndpointRefreshSeconds = 300;
      peers = [
        {
          name = "vyos";
          publicKey = config.wireguardS2S.vyosPublicKey;
          presharedKeyFile = "/var/lib/secrets/wireguard-preshared-key";
          endpoint = config.wireguardS2S.endpoint;
          allowedIPs =
            config.wireguardS2S.allowedIPs
            ++ [
              # WireGuard ranges that the router reaches for everyone.
              "10.254.0.0/16"
              "10.255.0.0/16"
              # Home LAN, IPv4 and the prefix delegated over PPPoE.
              "10.12.0.0/16"
              "2a03:7845:3371:100::/56"
            ];
          # Keep the NAT mapping of the uplink alive, the router answers from
          # behind a dynamic IP.
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
