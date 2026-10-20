# System-Updates mit nh und update-check

## Übersicht

`nh` (Yet Another Nix Helper) ist als Systempaket installiert
(`nixos/features/nix.nix`). Das Script `scripts/update-check.sh` baut den
Update-Workflow drumherum: erst anzeigen, was sich ändert, dann entscheiden.

Warum nicht einfach `nh os switch`? geeky läuft mit niri (kein GDM/GNOME).
Ein `switch` auf dem laufenden System würde die Session sofort beenden.
Deshalb: **immer `nh os boot`**, danach neu starten (siehe `TODO.md`).

## Update-Workflow

```console
$ scripts/update-check.sh
```

Das Script durchläuft folgende Schritte:

1. **Alter der aktuellen Generation** — zeigt, wie viele Tage das laufende
   System schon alt ist. Ab 14 Tagen gibt es eine Warnung.
2. **Flake-Inputs aktualisieren** — `nix flake update`, zeigt die Diff-Stat
   von `flake.lock`.
3. **Neue Generation bauen** — `nh os build`, baut ohne zu aktivieren.
4. **Paket-Diff** — `nix store diff-closures` vergleicht das laufende System
   mit der neuen Generation. Ausgabe: `+neu`, `-entfernt`, `~geändert`.
5. **Security-Flags** — markiert sicherheitskritische Pakete:
   - `linux` (Kernel — Neustart nötig, lanzaboote signiert neu)
   - `systemd`, `sudo`, `polkit` (Privilege Escalation)
   - `openssh` (Remote Access)
   - `cryptsetup` (LUKS)
   - `lanzaboote`, `sbctl` (Secure Boot)
   - `firefox`, `chromium` (Browser — meist Security-Fixes)
   - `fwupd` (Firmware)
   - `glibc`, `openssl` (Base Libraries)
   - `networkmanager`, `pipewire`, `gnupg`
6. **Zusammenfassung + Prompt** — zeigt die Anzahl der Änderungen und fragt,
   ob `nh os boot` ausgeführt werden soll.

Bei **Nein** wird `flake.lock` zurückgesetzt (`git checkout`) und das
`result`-Symlink entfernt — keine Spuren.

## Nach dem Update

```console
$ sudo reboot
# nach dem Neustart:
$ cd /home/ben/Projects/nixconf
$ git add flake.lock
$ git commit -m "flake: update inputs"
```

## Optionen

```console
$ scripts/update-check.sh --yes              # ohne Prompt (Scripting)
$ scripts/update-check.sh --flake /path/to/flake
$ scripts/update-check.sh --host geeky      # default
```

Umgebungsvariablen: `NH_FLAKE` (default: `/home/ben/Projects/nixconf`),
`NH_HOSTNAME` (default: `geeky`).

## Manuell mit nh

Wenn das Script nicht gebraucht wird:

```console
$ nh os build /home/ben/Projects/nixconf#geeky   # nur bauen
$ nh os boot  /home/ben/Projects/nixconf#geeky   # bauen + Boot-Default setzen
$ nh os info                                      # Generationen anzeigen
$ nh os rollback                                  # zur vorherigen Generation
```

Mit `-u` werden die Flake-Inputs vorher aktualisiert:

```console
$ nh os boot -u /home/ben/Projects/nixconf#geeky
```

**Nie `nh os switch` auf geeky** — niri startet keinen Display-Manager,
die Session würde sofort wegfallen.

## Sicherheitsrelevante Pakete

Das Script erkennt diese Paketnamen im Diff und markiert sie:

| Paket | Grund |
|---|---|
| `linux` | Kernel — Neustart nötig, Secure-Boot-Pfad neu signiert |
| `systemd` | Init-System, Kern-Angriffsfläche |
| `sudo`, `polkit` | Privilege Escalation |
| `openssh` | Remote Access |
| `cryptsetup` | LUKS-Verschlüsselung |
| `lanzaboote`, `sbctl` | Secure Boot |
| `firefox`, `chromium` | Browser — enthalten meist Security-Fixes |
| `fwupd` | Firmware-Updates |
| `glibc`, `openssl` | Base Libraries, alles betroffen |
| `networkmanager` | Netzwerk-Stack |
| `pipewire` | Audio-Server (User-Session) |
| `gnupg` | Signieren/Verschlüsseln |

## Delay-Risiko

Wenn das Script security-relevante Pakete meldet, steht im Summary:

> Delaying exposes the system to known vulnerabilities fixed in these versions.

Bei Kernel- oder Browser-Updates ist ein zeitnahes Update empfohlen. Bei
reinen Paket-Pflege-Updates (z. B. `ripgrep`, `jq`) kann man warten.
