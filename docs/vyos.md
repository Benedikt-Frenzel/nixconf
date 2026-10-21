# VyOS — Router und Site-to-Site-Tunnel

- Gerät: `vyos`, LAN `eth1` (10.12.1.1) mit VLANs, WAN `pppoe0`, LTE-Backup `eth3`.
- Öffentliche IPv4 des PPPoE: `89.57.115.113`, DDNS `home.okt.bfr.sh`.
  Die Server bauen den Tunnel zum Router auf, weil die Adresse dynamisch ist.
- VyOS-Version: 2026.09 rolling.
- Zugang: `ssh vyos@10.12.10.1` (SSH-Key `geeky`).
  `configure`, `commit` und `save` funktionieren nur interaktiv, also mit TTY:
  `script -qec "ssh vyos@10.12.10.1" /dev/null < cmds.txt`.
- Der Router ist der Hub: die beiden Server hängen an getrennten Tunneln und
  erreichen sich über ihn.

## Tunnel

| Tunnel | Interface | VyOS IPv4 | Peer IPv4 | VyOS IPv6 | Peer IPv6 | UDP | Peer |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `wg100` | 10.254.100.1/30 | 10.254.100.2/30 | fd00:254:100::1/64 | fd00:254:100::2/64 | 51910 | hacky |
| 2 | `wg101` | 10.254.101.1/30 | 10.254.101.2/30 | fd00:254:101::1/64 | fd00:254:101::2/64 | 51911 | munin |

- IPv4-Range `10.254.0.0/16` ist neu und für diese Tunnel reserviert.
- IPv6 nutzt ULA `fd00:254:$Interface::/64`, spiegelbildlich zum IPv4-Range.
  Die bestehenden Tunnel verwenden `fd82:4b99:d88a:$N::/64`.
- Jeder Tunnel hat einen eigenen UDP-Port, weil zwei WireGuard-Interfaces
  nicht denselben Port auf derselben Adresse binden können.
- Beide Seiten kennen den jeweils anderen Endpunkt: Die Server haben
  `home.okt.bfr.sh:51910` bzw. `:51911`, der Router die statischen
  öffentlichen IPs der Server. Beide Richtungen können den Tunnel aufbauen.
  Auf dem Server lauscht WireGuard auf demselben Port wie das Interface des
  Routers (51910 bzw. 51911), wie bei den bestehenden s2s-Tunneln.
- Ein Peer ohne `address`/`port` ist auf dem Router ein reiner Dial-in-Peer,
  mit `address`/`port` ein Dial-out-Peer wie `wg23` oder `wg24`.

## VyOS-Konfiguration

```vyos
set interfaces wireguard wg100 address '10.254.100.1/30'
set interfaces wireguard wg100 address 'fd00:254:100::1/64'
set interfaces wireguard wg100 description 'hacky-site2site'
set interfaces wireguard wg100 peer hacky address '149.154.159.86'
set interfaces wireguard wg100 peer hacky allowed-ips '10.254.100.2/32'
set interfaces wireguard wg100 peer hacky allowed-ips 'fd00:254:100::2/128'
set interfaces wireguard wg100 peer hacky persistent-keepalive '25'
set interfaces wireguard wg100 peer hacky port '51910'
set interfaces wireguard wg100 peer hacky preshared-key '<PSK wg100>'
set interfaces wireguard wg100 peer hacky public-key '<public key hacky>'
set interfaces wireguard wg100 port '51910'
set interfaces wireguard wg100 private-key '<private key wg100>'

set interfaces wireguard wg101 address '10.254.101.1/30'
set interfaces wireguard wg101 address 'fd00:254:101::1/64'
set interfaces wireguard wg101 description 'munin-site2site'
set interfaces wireguard wg101 peer munin address '187.127.73.243'
set interfaces wireguard wg101 peer munin allowed-ips '10.254.101.2/32'
set interfaces wireguard wg101 peer munin allowed-ips 'fd00:254:101::2/128'
set interfaces wireguard wg101 peer munin persistent-keepalive '25'
set interfaces wireguard wg101 peer munin port '51911'
set interfaces wireguard wg101 peer munin preshared-key '<PSK wg101>'
set interfaces wireguard wg101 peer munin public-key '<public key munin>'
set interfaces wireguard wg101 port '51911'
set interfaces wireguard wg101 private-key '<private key wg101>'

set firewall ipv4 input filter rule 47 action 'accept'
set firewall ipv4 input filter rule 47 description 'Allow hacky s2s WireGuard'
set firewall ipv4 input filter rule 47 destination port '51910'
set firewall ipv4 input filter rule 47 inbound-interface group 'WAN_UPLINKS'
set firewall ipv4 input filter rule 47 protocol 'udp'

set firewall ipv4 input filter rule 48 action 'accept'
set firewall ipv4 input filter rule 48 description 'Allow munin s2s WireGuard'
set firewall ipv4 input filter rule 48 destination port '51911'
set firewall ipv4 input filter rule 48 inbound-interface group 'WAN_UPLINKS'
set firewall ipv4 input filter rule 48 protocol 'udp'

commit
save
```

Weitergehende Firewall-Regeln sind nicht nötig:

- `ipv4 forward filter` Regel 100 erlaubt Forwarding von allen Interfaces, die
  nicht in `WAN_UPLINKS` sind — damit ist der Verkehr zwischen `wg100` und
  `wg101` und ins LAN erlaubt.
- `ipv6 forward filter` hat dieselbe Regel.
- Die Antwortpakete der Server laufen über die bestehende `established`-Regel.
- Für IPv6-Eingang vom WAN gibt es keine WireGuard-Regel; die Server nutzen
  IPv4 als Endpunkt.

## Schlüssel

1Password-Vault `vyos#system` (ID `5nokkbkwxasnnqvxzyru6znn74`):

- `WireGuard wg100`: `vyos_private`, `vyos_public`, `preshared_key`
- `WireGuard wg101`: `vyos_private`, `vyos_public`, `preshared_key`

Der PSK eines Tunnels ist auf beiden Seiten identisch: der PSK aus
`vyos#system` / `WireGuard wg100` steht auch in `hacky#system` /
`WireGuard wg0`, der aus `WireGuard wg101` in `munin#system` / `WireGuard wg0`.

## NixOS-Seite

Modul `nixos/hosts/_wireguard.nix`, benutzt von `hacky` und `munin`.
Private Key und PSK liegen als root-only Dateien auf dem Server:

- `/var/lib/secrets/wireguard-private-key`
- `/var/lib/secrets/wireguard-preshared-key`

Beide Dateien müssen existieren, bevor der Tunnel startet. Das Netzwerk läuft
auf `systemd-networkd`, die Dateien werden als systemd-Credentials an
`systemd-networkd` durchgereicht.

Jeder Server lauscht mit einem festen Port (hacky 51910, munin 51911) und
lässt in der Firewall nur die öffentliche IPv4 des Routers `89.57.115.113`
an diesen Port:

```
ip saddr 89.57.115.113 udp dport 51910 accept comment "WireGuard from the router"
```

Deploy:

```sh
nixos-rebuild switch --flake path:.#hacky --target-host root@149.154.159.86
nixos-rebuild switch --flake path:.#munin --target-host root@187.127.73.243
```

## Betrieb

- **Wer baut den Tunnel auf:** Beide Seiten kennen den jeweils anderen
  Endpunkt, also kann jede Seite den Tunnel aufbauen. Der Server initiiert
  über `home.okt.bfr.sh`, der Router über die statische Server-IP. Fällt eine
  Seite aus, merkt die andere das erst, wenn die WireGuard-Sitzung abläuft
  (180 s), danach handshake der jeweils anderen Seite beim nächsten Keepalive
  (25 s).
- **PSK oder Key ändern:** Datei auf dem Server ersetzen und danach
  `systemctl restart systemd-networkd` — die Credentials werden nur beim
  Start von `systemd-networkd` gelesen. Ein Neustart trennt kurz die
  Verbindung, deshalb `systemd-run --on-active=2 systemctl restart
  systemd-networkd` aus der Ferne nutzen.
- **DDNS:** `home.okt.bfr.sh` wird von den Servern alle fünf Minuten neu
  aufgelöst (`dynamicEndpointRefreshSeconds`). Der Router braucht das nicht,
  er hat die statische IP der Server.
- **IPv6-Prefix des LANs:** Der Router bekommt per PPPoE ein /56-Prefix
  (`2a03:7845:3371:100::/56`), daraus entstehen die VLAN-/64er. Wechselt das
  Prefix, muss `2a03:7845:3371:100::/56` in `nixos/hosts/_wireguard.nix`
  angepasst und die Server neu deployed werden. Aktuelles Prefix abfragen:
  `ssh vyos@10.12.10.1 'ip -6 addr show eth1.10'`.
- **Commit per CLI:** `/opt/vyatta/etc/config/archive` war auf `2700
  root:vyattacfg` und damit für den Benutzer `vyos` nicht schreibbar; der
  Modus wurde auf `2775` gesetzt, wie ihn das VyOS-Paket anlegt.
- **Firewall-Regeln für weitere Tunnel:** Ports im Bereich `51950-51959`
  sind für Site-to-Site reserviert, `51910`/`51911` für hacky/munin.

## Prüfen

```sh
# Router
ssh vyos@10.12.10.1 'sudo -n wg show wg100'
ssh vyos@10.12.10.1 'sudo -n wg show wg101'

# Server
ssh root@149.154.159.86 'wg show wg0'
ssh root@187.127.73.243 'wg show wg0'

# Durch den Tunnel
ssh root@149.154.159.86 'ping -c3 10.254.101.2'      # hacky -> munin, IPv4
ssh root@149.154.159.86 'ping -6 -c3 fd00:254:101::2' # hacky -> munin, IPv6
ssh root@187.127.73.243 'ping -c3 10.12.10.117'       # munin -> LAN, IPv4
```
