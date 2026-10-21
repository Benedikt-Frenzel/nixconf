# hacky — EDIS Global VPS

- Instance: `kvm_140854_784778`
- Primary IPv4: `149.154.159.86/24`, gateway `149.154.159.1`
- NIC: `ens3`, MAC `52:54:00:0b:f9:8b`
- Additional IPv4s: `158.255.214.250/24`, `45.151.74.182/24`, using the
  primary IPv4 gateway. EDIS explicitly documents `/24`, not `/32`, for
  [additional IPv4 addresses](https://docs.edisglobal.com/faq/ip-addresses/configuring-additional-ip-address-linux).
- IPv6 allocation: `2a03:f80:49:965e::/64`; configured address:
  `2a03:f80:49:965e::1/48`, gateway `2a03:f80:49::1`.
  EDIS uses a shared on-link `/48`, not a separately routed `/64`; only
  addresses from the assigned `/64` may be used (maximum 20 active addresses).
  See [EDIS IPv6 configuration](https://docs.edisglobal.com/vps-management/ipv6-configuration).
- DNS: Quad9 (`9.9.9.9`, `149.112.112.112`); systemd-resolved's built-in
  fallback DNS servers are disabled.
- The uplink configuration is shared with the initrd.
- 2 vCPUs, 4 GiB RAM, 45 GiB disk; BIOS/GRUB, no UEFI required.

## Storage

GPT on `/dev/vda`:

| Partition | Purpose |
| --- | --- |
| `/dev/vda1` | 1 MiB BIOS boot partition |
| `/dev/vda2` | 1 GiB ext4, label `hacky-boot`, unencrypted `/boot` |
| `/dev/vda3` | Remaining space, PARTLABEL `hacky-cryptroot`, LUKS2/Argon2id |

LUKS opens as `/dev/mapper/cryptroot`, with ext4 root and an encrypted
2 GiB swap file at `/var/lib/swapfile`. Discard passthrough is not enabled.

## Credentials

1Password vault `hacky#system` contains:

- `LUKS root`: disk passphrase.
- `root`: console/recovery password; SSH passwords are disabled.
- `SSH host key (initrd)`: dedicated private host key in the password field.
- `SSH host key (system)`: regular private host key in the password field.
- `LUKS root header backup`: binary LUKS2 header, verified after upload.
- `EDIS VNC`: provider console password and endpoint.
- `System runbook`: copy of this document.
- Future service credentials belong here as well.

Vault `hacky#ben` contains:

- `ben`: login password.
- `SSH ben@hacky`: dedicated SSH key (enable it in the 1Password SSH agent).

The existing `geeky` SSH public key is also authorized for ben, root and
initrd, so the current workstation retains access.

Password hashes live in root-only files under `/var/lib/secrets`, not in
the repository or Nix store. The regular host private key lives under
`/etc/ssh`; the separate initrd key under `/etc/secrets/initrd`.
The initrd key must also be included on **unencrypted `/boot`** to allow
remote unlocking. Never reuse it as a normal SSH host or user key.
LUKS protects data at rest, not against a malicious hypervisor or modified
boot files. A header backup is not a data backup; refresh it after key changes.

Vault names contain `#`. For `op read`, use the vault's ID rather than
embedding the literal vault name in an `op://` URI.

## Reboot and unlock

After every reboot, connect to the initrd:

```sh
ssh -t -p 2222 root@149.154.159.86
```

Enter the passphrase from `hacky#system` → `LUKS root` at the prompt.
The unlock account runs only the systemd password agent. The connection
closes when boot proceeds. Then connect normally:

```sh
ssh ben@149.154.159.86
```

Port 22 permits SSH keys only; wheel members (ben) can use sudo without a password. Port 2222
exists only in the initrd, not in the running system. The initrd and
normal system have different host keys; verify their fingerprints against
the saved keys before accepting them. The installer's old SSH host key
is not the installed system's key.

Installed Ed25519 fingerprints:

- Initrd: `SHA256:rbtzgJrpAEG1p+vIfo2JsKp78CwH9nhnC1wrRJKec7w`
- System: `SHA256:arvQ00XVAB4P4PQBqoajbvk0rJgxUV3iua+8nXZsm+w`

If SSH unlock is unavailable, use the EDIS console to enter the same
LUKS passphrase. Keep the provider's console access available.
The initrd console uses a German keyboard layout; direct VNC clients may
send US physical key positions (notably Y/Z). Clipboard paste is not
generally supported at the console password prompt. SSH unlock avoids
this keyboard-layout translation.

## Firewall

`nixos/hosts/_server-firewall.nix` configures nftables for both boot stages.

- Incoming connections are denied by default for **IPv4 and IPv6**.
- Normal SSH (TCP 22) is allowed only from **`89.57.115.113/32`**.
- Initrd SSH (TCP 2222) has the same source restriction, enforced before
  the initrd network and SSH services start.
- No IPv6 source is authorized for SSH, including link-local IPv6 sources.
- Loopback and established/related traffic remain allowed. Network-control
  ICMP/ICMPv6 remains allowed; ordinary IPv4 ping requests are blocked.
- Forwarding is filtered; outbound traffic is unrestricted.
- OpenSSH's automatic global firewall opening is disabled.

If the home public IPv4 changes, **both SSH and remote unlock become
unreachable** from the new address. Update `adminIPv4` in `_server-firewall.nix`
before changing networks, or recover through the EDIS console.
The initrd rules are removed before stage 2 takes over.

Fail2ban is not enabled yet; the IP allowlist already excludes SSH login
attempts from all other sources at the firewall.

## WireGuard

Site-to-Site-Tunnel zum VyOS-Router, siehe `docs/vyos.md`.

- Interface `wg0`: `10.254.100.2/30` und `fd00:254:100::2/64`.
- Peer: VyOS-Interface `wg100`, Endpunkt `home.okt.bfr.sh:51910`.
- Lauscht auf UDP `51910`; die Firewall lässt nur `89.57.115.113` (Router)
  an diesen Port, damit der Router den Tunnel auch aufbauen kann.
- Über den Tunnel erreichbar: munin (`10.254.101.0/30`, `fd00:254:101::/64`),
  das Home-LAN (`10.12.0.0/16`, `2a03:7845:3371:100::/56`) sowie die
  WireGuard-Bereiche `10.254.0.0/16` und `10.255.0.0/16`.
- Private Key und PSK liegen in `/var/lib/secrets/wireguard-private-key` und
  `/var/lib/secrets/wireguard-preshared-key`, root-only und nicht im
  Nix-Store. Sie stehen in `hacky#system` → `WireGuard wg0`, der PSK ist
  identisch mit `vyos#system` → `WireGuard wg100`.
- Die Dateien müssen vor dem ersten Start des Tunnels existieren, sonst
  generiert der Key-Generator einen Schlüssel, der nicht zum Router passt.
- Die Firewall erlaubt ICMP-Echo nur auf `wg0`; sonst wäre der Tunnel
  nicht pingbar.
- Der Endpoint ist ein DDNS-Name und wird alle fünf Minuten neu aufgelöst.

## Deploy

From this repository (`path:.` also includes newly added, untracked host files):

```sh
nixos-rebuild switch --flake path:.#hacky --target-host root@149.154.159.86
```

No desktop/general module is imported: that module currently includes desktop
dependencies and workstation-specific user/password defaults.

An installation-time configuration snapshot is available at `/etc/nixos`
on the VPS. This repository remains the source of truth for later changes.

## Installation validation (2026-10-21)

- BIOS/GRUB disk boot and SSH initrd unlock tested after a normal reboot.
- Running system reports `running`, with no failed units.
- Root filesystem uses `/dev/mapper/cryptroot`; swap is inside LUKS.
- ben SSH login and passwordless sudo verified.
- No recovery/debug-shell kernel argument remains in the regular boot.
- LUKS passphrase independently verified against the vault's header backup.
- LUKS passphrase and private host keys are not included in the Nix store.

## Network validation (2026-10-21)

- Deployed with `nixos-rebuild switch`; no failed systemd units.
- SSH verified through all three public IPv4 addresses.
- Outbound IPv4 verified with each address as source; both additional
  addresses also verified using HTTPS to an external IP-echo service.
- Public IPv6 and the WireGuard peer's IPv4/IPv6 addresses answer pings.
- Quad9 name resolution verified. Initial connectivity delays cleared after
  contacting the additional IPv4 subnet gateways / IPv6 neighbor discovery.
- No reboot performed for this network update; the new initrd was built
  and installed, but its network configuration has not been boot-tested.

## Rescue

Boot the NixOS ISO in BIOS mode and unlock/mount the installed filesystem:

```sh
sudo cryptsetup open /dev/disk/by-partlabel/hacky-cryptroot cryptroot
sudo mount /dev/mapper/cryptroot /mnt
sudo mount /dev/disk/by-label/hacky-boot /mnt/boot
sudo nixos-enter --root /mnt
```

Only restore a LUKS header as a recovery operation against the correct disk;
it can overwrite current key slots and re-enable old passphrases.
