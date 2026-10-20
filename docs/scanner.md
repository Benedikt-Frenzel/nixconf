# Brother ADS-1300 Scanner auf geeky

`nixos/features/scanner.nix` richtet SANE mit dem Brother brscan5-Treiber ein.
Der Scanner ist ein ADS-1300 (USB-ID `04f9:0706`), angeschlossen per USB.
Als Scan-Frontend dient `simple-scan` (GNOME Document Scanner).

## Warum ein Overlay

nixpkgs liefert brscan5 nur in Version 1.3.1-0, die den ADS-1300 noch nicht
kennt. Das Modul legt deshalb `_brscan5-1.7.nix` als Overlay an — die direkt
von Brother heruntergeladene Treiberversion 1.7.0-0 (deb-Paket, 64bit). Das
Overlay ersetzt das nixpkgs-Paket, bevor `hardware.sane.brscan5` es aktiviert.

## Erste Aktivierung

Nach dem üblichen Systemwechsel:

```sh
# Gerät erkannt?
lsusb | grep Brother
scanimage -L
```

`scanimage -L` sollte etwa liefern:

```
device `brother5:bus1;dev1' is a Brother ADS-1300 USB scanner
```

Falls nicht: USB-Kabel prüfen, `systemctl restart udev` auslösen oder den
Scanner kurz aus- und wieder einstecken.

## Scannen

`simple-scan` über den App-Launcher starten. Der Scanner erscheint automatisch.
Scan-Ziele (Datei, PDF, Drucken) sind in der Oberfläche wählbar.

Kommandozeile geht auch:

```sh
scanimage --format=png > scan.png
simple-scan &
```

## Brother-Dienstprogramme

brscan5 installiert zusätzlich `brscan-skey` (Scan-to-Button am Gerät). Der
Dienst ist eingerichtet, aber nicht gestartet:

```sh
systemctl --user status brscan-skey.service   # prüfen
systemctl --user start brscan-skey.service    # bei Bedarf starten
```

## fwupd

`nixos/features/fwupd.nix` aktiviert `services.fwupd` für Firmware-Updates
über LVFS (z. B. Dell WD19 Dock). Lanzaboote signiert das fwupd-EFI-Binary,
damit Kapsel-Updates unter Secure Boot funktionieren.

```sh
fwupdmgr refresh
fwupdmgr get-devices
fwupdmgr get-updates
fwupdmgr update
```

Der Zustand liegt unter `/var/lib/fwupd` (persistiert über Impermanence).
