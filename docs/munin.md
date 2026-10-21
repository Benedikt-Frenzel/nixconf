# munin — Hostinger VPS

- IPv4: `187.127.73.243/24`, gateway `187.127.73.254`.
- IPv6: `2a02:4780:79:ab5e::1/48`, gateway `2a02:4780:79::1`.
- NIC matched by MAC `64:e8:d4:c1:64:45`, not interface name.
  The installed system names it `ens18` (recovery used `eth0`).
- 4 vCPUs, 16 GiB RAM, 200 GiB system disk; BIOS/GRUB.
- Stable system disk: `/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0`.

## Storage and recovery

GPT partitions: 1 MiB BIOS boot, 1 GiB ext4 `/boot` (label `munin-boot`),
remaining space LUKS2/Argon2id (PARTLABEL `munin-cryptroot`). The encrypted
mapping `/dev/mapper/cryptroot` contains ext4 root and a 4 GiB swap file.
Discard passthrough is disabled.

**In Hostinger recovery, `/dev/sda` is the disposable Ubuntu recovery disk,
not the VPS system disk.** The system disk was `/dev/sdb` during installation.
Its kernel name may change after leaving recovery; use the stable ID above.
Do not format a disk based on its `/dev/sdX` name alone.

1Password vault `munin#system` contains:

- `recovery`: existing Hostinger recovery root credentials.
- `Original NixOS configuration`: verified pre-install configuration archive.
- `LUKS root`: disk passphrase.
- `root`: new installed-system console/recovery password.
- `SSH host key (initrd)` and `SSH host key (system)`: dedicated private
  host keys in their password fields.
- `LUKS root header backup`: binary header, read-back verified after upload.
- `System runbook`: copy of this document.

Vault `munin#ben` contains `ben` (login password) and `SSH ben@munin`.
Enable the latter in the 1Password SSH agent if using the dedicated key.
The workstation's existing `geeky` SSH key is also authorized.
Root and ben use SSH keys only; ben has passwordless sudo via `wheel`.
Future service credentials belong in `munin#system`.

Hashes live in root-only `/var/lib/secrets/*-password-hash` files. The
regular host private key is under `/etc/ssh`; the initrd key is under
`/etc/secrets/initrd`. No private keys/passphrases are embedded in Nix
expressions or the Nix store. The **separate initrd private host key is
necessarily included on unencrypted `/boot`**. Do not reuse it for other
purposes. LUKS protects at-rest data, not a running VM from its provider or
against boot-file tampering. Header backups are not filesystem backups;
refresh them after changing LUKS key slots.

## Firewall and unlock

`nixos/hosts/_server-firewall.nix` is shared with hacky. Both boot stages
use nftables with default-deny inbound IPv4/IPv6. Only `89.57.115.113/32`
may connect to normal SSH (22) or initrd SSH (2222). No IPv6 SSH source is
authorized. Loopback, established/related traffic and network-control ICMP
remain available. Outbound traffic is unrestricted. Fail2ban is not enabled.

**A change of your home public IPv4 locks out both SSH and remote unlock.**
Update `adminIPv4` in the shared module beforehand, or use Hostinger's console.

After each reboot:

```sh
ssh -t -p 2222 root@187.127.73.243
# Enter munin#system → LUKS root; connection closes as boot proceeds.
ssh ben@187.127.73.243
```

Installed Ed25519 fingerprints:

- Initrd: `SHA256:wliO0GesgBpTd0LdPh1eKVeP65wmvvzrAruVcKGCeB0`
- System: `SHA256:YFjMs4kUuFgvzYRsp5SuYrKNUv0kn4RIn6MKUAXTBkM`

These differ from Hostinger's recovery host key. Verify before accepting
changes. Console keymap is German; direct VNC clients may send US physical
key positions, and clipboard paste generally does not work at the unlock
prompt. Prefer SSH unlocking.

## WireGuard

Site-to-Site-Tunnel zum VyOS-Router, siehe `docs/vyos.md`.

- Interface `wg0`: `10.254.101.2/30` und `fd00:254:101::2/64`.
- Peer: VyOS-Interface `wg101`, Endpunkt `home.okt.bfr.sh:51911`.
- Lauscht auf UDP `51911`; die Firewall lässt nur `89.57.115.113` (Router)
  an diesen Port, damit der Router den Tunnel auch aufbauen kann.
- Über den Tunnel erreichbar: hacky (`10.254.100.0/30`, `fd00:254:100::/64`),
  das Home-LAN (`10.12.0.0/16`, `2a03:7845:3371:100::/56`) sowie die
  WireGuard-Bereiche `10.254.0.0/16` und `10.255.0.0/16`.
- Private Key und PSK liegen in `/var/lib/secrets/wireguard-private-key` und
  `/var/lib/secrets/wireguard-preshared-key`, root-only und nicht im
  Nix-Store. Sie stehen in `munin#system` → `WireGuard wg0`, der PSK ist
  identisch mit `vyos#system` → `WireGuard wg101`.
- Die Dateien müssen vor dem ersten Start des Tunnels existieren, sonst
  generiert der Key-Generator einen Schlüssel, der nicht zum Router passt.
- Die Firewall erlaubt ICMP-Echo nur auf `wg0`; sonst wäre der Tunnel
  nicht pingbar.
- Der Endpoint ist ein DDNS-Name und wird alle fünf Minuten neu aufgelöst.

## Deploy and rescue

```sh
nixos-rebuild switch --flake path:.#munin --target-host root@187.127.73.243
```

The repository is the source of truth; `/etc/nixos` on the VPS contains
an installation-time snapshot.

From Hostinger recovery, unlock and mount without depending on disk names:

```sh
cryptsetup open /dev/disk/by-partlabel/munin-cryptroot cryptroot
mkdir -p /mnt/target
mount /dev/mapper/cryptroot /mnt/target
mount /dev/disk/by-label/munin-boot /mnt/target/boot
```

Do not restore a header unless recovering the correct disk: restoration
overwrites key slots and can re-enable old passphrases.

## Validation (2026-10-21)

- Normal disk boot after leaving Hostinger recovery and SSH LUKS unlock tested.
- Root is `/dev/mapper/cryptroot`; 4 GiB encrypted swap active.
- System reports `running`, no failed units or debug-shell boot argument.
- ben SSH and passwordless sudo verified; Kitty terminfo available.
- Outbound HTTPS works over IPv4 and IPv6.
- Fresh SSH from the authorized home IPv4 works; isolated untrusted IPv4
  and IPv6 source tests time out as expected.
- Initrd firewall started successfully and was removed during switch-root;
  only the normal `inet nixos-fw` table remains after boot.
