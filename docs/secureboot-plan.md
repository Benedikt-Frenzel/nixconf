# Secure Boot für geeky – aktiviert und bootgetestet

Status: Secure Boot ist seit dem manuellen UEFI-Import aktiviert (`enabled
(user)`), der Setup Mode ist deaktiviert. Generation 21 ist mit lanzastub 1.2.0
unter aktivem Secure Boot erfolgreich gestartet und als Standard eingetragen.
Lanzaboote v1.2.0 ist gepinnt und in geeky eingebunden. `sbctl verify`
bestätigt signierte Generationen 11–21 sowie die aktiven Bootloader-Pfade
`EFI/systemd/systemd-bootx64.efi` und `EFI/BOOT/BOOTX64.EFI`. OpenSnitch und
Syncthing sind nach dem Testboot aktiv. Lokale sbctl-Schlüssel sind im neuen
age-Backup geprüft. Microsoft-/Firmware-Zertifikate werden weiterhin angezeigt.
LUKS-Änderungen wurden nicht durchgeführt. OpenSnitch-Daemon und UI sowie
Syncthing sind auch nach dem Secure-Boot-Start aktiv; im geprüften OpenSnitch-Log
erscheinen UI-Verbindung und neue Regeln, keine eBPF-Startfehler. Eine Warnung
über die fehlende optionale `tasks.json` wurde beobachtet.

Die folgenden Checklisten und Kommandos dokumentieren die Durchführung; bereits
erledigte Schlüsselgenerierung oder Enrollment nicht unbesehen wiederholen.

Die unsignierte Datei `EFI/nixos/kernel-6.18.56-….efi` ist bei Lanzaboote
erwartet: Der signierte Stub enthält und prüft den Kernel-Hash. Die ebenfalls
unsignierte `EFI/systemd/systemd-boot-fallbackx64.efi` ist nicht der aktuell
verwendete oder in den bisher gelesenen UEFI-Booteinträgen referenzierte Pfad;
sie ist nicht mit dem signierten `EFI/BOOT/BOOTX64.EFI` zu verwechseln. Nicht
ungeprüft löschen. Der Benutzer bestätigt die Ausführung von
`bootctl set-default @current`.

Achtung für spätere Updates: `set-default @current` hinterlegt die konkrete
Generation 21 als UEFI-Standard. Vor einem späteren Neustart nach Systemwechsel
mit `sudo bootctl list` prüfen, dass die neue gewünschte Generation Standard ist.
Für den Dauerbetrieb den expliziten UEFI-Override nach Prüfung der von Lanzaboote
verwalteten `loader.conf` entfernen, statt dauerhaft Generation 21 zu pinnen.

## Geprüfter Stand

- Gerät: GEEKOM NX16AM, Mainboard NX16A
- UEFI 2.90, American Megatrends
- Aktueller Bootloader: systemd-boot 261.3
- Secure Boot: aktiviert (user), Setup Mode deaktiviert
- TPM2: laut `bootctl status` vorhanden
- Root und Swap sind per LUKS verschlüsselt
- Beide gesicherten LUKS-Header wurden als LUKS2 erkannt
- Impermanence ist auf geeky derzeit deaktiviert; `/persist` existiert nicht.
  `/var/lib/sbctl` wird auf der normalen persistenten Root-Partition liegen.
- EFI-Systempartition: `/boot`, circa 1 GiB, davon circa 892 MiB frei
- NixOS Generation 21 ist aktuell und Standard; ausschließlich NixOS installiert,
  kein Dual Boot

Aktualisierung aus der privilegierten Bestandsaufnahme: `bootctl list` zeigt
inzwischen NixOS Generation 20 als Standard, Generation 15 als beim aktuellen
Boot ausgewählt. Kein openSUSE-Eintrag in der ausgegebenen Liste. `sbctl status`
meldet Secure Boot deaktiviert, Setup Mode deaktiviert und vorhandene
Microsoft-/Firmware-Zertifikate. „sbctl is not installed“ bezeichnet hier den
noch nicht initialisierten lokalen sbctl-Schlüsselbestand, nicht ein fehlendes
ausführbares Programm.

Die Bootloader-Dateien unter `/boot` sind ohne root nicht vollständig lesbar;
entsprechende Berechtigungsfehler von `bootctl status` sind kein Secure-Boot-
Fehler. Die privilegierte Signaturprüfung wurde vom Benutzer ausgeführt. Keine
EFI-Dateien oder Firmware-Einträge allein anhand ihres Namens löschen.

## Ziel

Signierter NixOS-Bootpfad mit Lanzaboote und eigenen Secure-Boot-Schlüsseln.
LUKS-Passworteingabe bleibt zunächst erhalten. Danach ist FIDO2-Entsperrung mit
einem Nitrokey 3A und einem Nitrokey 3C vorgesehen, jeweils unabhängig nutzbar.
TPM-Auto-Unlock ist nicht Teil dieser Umstellung.

## Vorbedingungen: erst abhaken, dann den Bootpfad ändern

Anleitung und Skript für die verschlüsselte Sicherung:
[secureboot-backup.md](secureboot-backup.md). Die Passphrase ist bereits in
1Password angelegt. Das erste Recovery-Backup
`20261019T160517Z-pre-secureboot.tar.age` wurde geprüft. Das zweite Archiv
`20261019T172615Z-pre-secureboot.tar.age` ist ebenfalls vollständig entschlüsselt
und geprüft: SHA-256, tar-Struktur, Recovery-Dateien und alle drei privaten
sbctl-Schlüssel samt Zertifikaten (PK, KEK, db). Der Benutzer hat die angefragten
Backup-/Recovery-Voraussetzungen als erledigt bestätigt.

- [ ] Aktuelles Datenbackup vorhanden und lesbar; Syncthing ist kein Backup.
- [ ] Rettungsmedium tatsächlich auf geeky gebootet und Zugriff auf die
      verschlüsselte Installation erprobt. Unter später aktivem Secure Boot muss
      es entweder vertrauenswürdig starten oder Secure Boot dafür gezielt
      abgeschaltet werden können.
- [ ] Beide bestehenden LUKS-Passphrasen für Root und Swap bekannt und getestet.
- [x] LUKS-Header beider Volumes gesichert, verschlüsselt extern aufbewahrt.
      Header-Backups sind sensibel: Alte Backups können widerrufene Schlüssel-
      Slots wiederherstellen. Sicherung und Aufbewahrung entsprechend planen.
- [x] EFI-Partition und vorhandene Firmware-Schlüsselvariablen gesichert; Dateisicherung
      allein sichert keine UEFI-Variablen.
- [ ] Firmware-Zugang und Wiederherstellung der bisherigen Bootkonfiguration
      geklärt; kein Firmware-Update gleichzeitig mit der Umstellung.
- [ ] GEEKOM-NX16AM-spezifischen Weg in den Setup Mode geprüft. Die allgemeinen
      AMI-/ThinkPad-Anleitungen sind kein gerätespezifischer Nachweis.
- [x] NixOS als Standard bestätigt (`bootctl list`: Generation 20); keine
      manuelle Löschung oder Korrektur von EFI-Einträgen erforderlich.

Bestandsaufnahme vor der Umsetzung erneut durchführen (nur lesend):

```sh
bootctl status --no-pager
findmnt /boot
df -h /boot
lsblk -o NAME,PATH,FSTYPE,UUID,MOUNTPOINTS
sudo efibootmgr -v
sudo cryptsetup luksDump /dev/disk/by-uuid/d5607473-66c6-4336-b908-76c88228c592
sudo cryptsetup luksDump /dev/disk/by-uuid/bdfb9b4b-cbce-42df-9d5b-2a283804122e
```

Kein `--dump-volume-key` verwenden. Ausgaben nicht unbesehen veröffentlichen;
sie enthalten Geräte- und Verschlüsselungsmetadaten. LUKS2 für die spätere
FIDO2-Phase prüfen, nicht ungefragt konvertieren.

## Vorgehen in Etappen

1. **Recovery vorbereiten:** Funktionierendes Rettungsmedium, bekannte
   LUKS-Passphrasen, Datensicherung und Sicherung der aktuellen EFI-Partition.
   Zugang zur Firmware und die Möglichkeit, Secure Boot im Notfall wieder
   abzuschalten, sicherstellen. Firmware-Einstellungen und bestehende
    Schlüsselbelegung dokumentieren. Es wird nur NixOS benötigt.
2. **Schlüsselverwaltung planen:** Schlüssel später mit `sbctl` lokal erzeugen,
   unter `/var/lib/sbctl` nur für root zugänglich halten, für Persistenz vorsehen
   und verschlüsselt extern sichern. Niemals private Schlüssel über Nix-Dateien,
   Git oder den Nix-Store verteilen.
3. **NixOS vorbereiten:** Eine geprüfte stabile Lanzaboote-Version als gepinnten
   Flake-Input hinzufügen und in einem eigenen Modul nur für geeky importieren.
   `boot.loader.systemd-boot.enable = lib.mkForce false` setzen und
   `boot.lanzaboote.enable = true` mit `pkiBundle = "/var/lib/sbctl"` konfigurieren.
   Das ersetzt die Verwaltung durch das normale systemd-boot-Modul, nicht das
   grundlegende systemd-boot-Bootmenü.
4. **Noch ohne Secure-Boot-Erzwingung testen:** System bauen und signierte
   Bootdateien installieren, Signaturen mit `sbctl verify` prüfen. Neue Generation
   bei weiterhin deaktiviertem Secure Boot booten. EFI-Platz und mindestens eine
   ebenfalls signierte Rückfallgeneration kontrollieren.
5. **Firmware gemeinsam umstellen:** Den herstellerspezifischen Weg in den Setup
   Mode prüfen. Nicht blind „Clear all keys“ verwenden; insbesondere die
   Sperrliste dbx erhalten. Eigene Schlüssel einschreiben und nötige
   Microsoft-/Hersteller-Zertifikate bewusst berücksichtigen, damit Option-ROMs,
    Firmware-Updates nicht ausgesperrt werden. Vor dem Enrollment stoppen und
    die konkret benötigten Zertifikate und Firmware-Einstellungen bestätigen.
6. **Verifizieren:** Erst dann Secure Boot erzwingen, neu starten und
   `bootctl status` sowie `sbctl status` prüfen. Aktuelle und Rückfallgeneration
    testen. Danach OpenSnitch, Hardware und benötigte Kernelmodule testen.

## Geplante Änderungen an der Nix-Konfiguration

Input und Modul sind vorbereitet; die Host-Aktivierung erfolgt erst nach den
Vorprüfungen und der Schlüsselerzeugung:

- `flake.nix` / `flake.lock`: stabile Lanzaboote-Version festlegen,
  `inputs.nixpkgs.follows = "nixpkgs"`, Kompatibilität mit dem gepinnten Nixpkgs-
  Stand prüfen; keine anderen Inputs nebenbei aktualisieren.
- Neues `nixos/features/secureboot.nix`: Lanzaboote-Modul importieren, `sbctl`
  installieren, normales systemd-boot-Modul deaktivieren und Lanzaboote auf
  `/var/lib/sbctl` konfigurieren.
- Dasselbe Modul: `/var/lib/sbctl` über `persistance.directories` als sensible
  Systemdaten erhalten. Vor Aktivierung sicherstellen, dass die Schlüssel am
  tatsächlich verwendeten persistenten Ort liegen; keinen leeren Mount darüber
  legen.
- `nixos/hosts/geeky/configuration.nix`: nur hier das neue Modul aktivieren.
- Neue Moduldatei vor einem Git-Flake-Build in den Git-Index aufnehmen.

**Kontrollpunkt A – erledigt:** Reiner Build erfolgreich; noch keine Firmware-Änderung.

**Kontrollpunkt B – Testboot und Signaturprüfung erledigt:** Signierte Bootdateien installiert und geprüft, eine neue
Generation bei ausgeschaltetem Secure Boot erfolgreich gebootet. Mindestens
eine weitere signierte, getestete Generation für den Rückfall vorhanden.

**Kontrollpunkt C – erledigt:** Manueller Firmware-Import und erfolgreicher Boot
mit aktiviertem Secure Boot bestätigt. Kein erneutes Enrollment nötig.

## Lokale Schlüssel – erledigt

Die folgenden Schritte wurden vom Benutzer durchgeführt; die Sicherung der
Schlüssel ist geprüft. Nicht erneut erzeugen oder ersetzen:

```sh
sudo nix run --inputs-from . nixpkgs#sbctl -- status
sudo bootctl list --no-pager
```

Nach Prüfung des Status können die lokalen Signierschlüssel erzeugt werden:

```sh
sudo nix run --inputs-from . nixpkgs#sbctl -- create-keys
```

Dieser Schritt schreibt noch keine Firmware-Schlüssel ein und aktiviert Secure
Boot nicht. Die erzeugten privaten Schlüssel nicht ausgeben oder ins Repository
kopieren. Danach das Recovery-Backup-Skript erneut ausführen: Es nimmt nun auch
`/var/lib/sbctl` in ein neues verschlüsseltes Archiv auf.

Die Host-Einbindung ist nach Bestätigung der Voraussetzungen und Prüfung der
Schlüsselsicherung erfolgt. Der isolierte Kandidat lässt sich weiterhin so bauen:

```sh
nix build --impure --expr 'let f = builtins.getFlake (toString ./.); in (f.nixosConfigurations.geeky.extendModules { modules = [f.nixosModules.secureboot]; }).config.system.build.toplevel' --out-link /tmp/opencode/secureboot-system
```

Das spätere Enrollment wurde manuell im UEFI durchgeführt, nicht über `enroll-keys`.

## Durchgeführt: signierte Bootdateien installieren und prüfen

Den üblichen `nh`-Systemwechsel ausführen oder im Repository:

```sh
sudo nixos-rebuild switch --flake .#geeky
sudo sbctl verify
sudo bootctl list --no-pager
```

Die Ausgabe vor dem Neustart prüfen: signierter systemd-boot und signierte
Lanzaboote-Einträge müssen vorhanden sein. Alte Type-1-Dateien und alte
unsignierte Dateien können noch auftauchen; diese nicht pauschal löschen. Bei
Fehlern stoppen und unterscheiden, ob neue Bootartefakte oder nur historische
Dateien betroffen sind.

Nach erfolgreicher Prüfung eine neue Lanzaboote-Generation mit weiterhin
deaktiviertem Secure Boot starten und danach Bootzustand und OpenSnitch prüfen.
Erst anschließend das Firmware-Enrollment vorbereiten.

## Manueller Zertifikatsimport per USB

Der Benutzer benötigt auf dieser Firmware den manuellen UEFI-Import statt
`sbctl enroll-keys`. Dafür wurden ausschließlich die öffentlichen Zertifikate
aus dem geprüften Backup `20261019T172615Z-pre-secureboot.tar.age` exportiert.

- Stick: SanDisk 3.2Gen1, circa 58,4 GiB, bei der Vorbereitung `/dev/sdc1`
- Dateisystem: FAT, UUID `13EB-116E`; nicht neu formatiert
- Ordner auf dem Stick: `SecureBoot-geeky`
- Format: X.509 DER (`.cer`), keine privaten Schlüssel
- Zusätzlich: `README.txt` mit Zertifikatsdetails und `SHA256SUMS`
- Dateien wurden nach dem Schreiben zurückgelesen und geprüft

Zuordnung im UEFI:

| Datei | Datenbank |
| --- | --- |
| `db.cer` | db (erlaubte Signaturen) |
| `KEK.cer` | KEK (Key Exchange Keys) |
| `PK.cer` | PK (Platform Key) |

Voraussetzung bleibt die erfolgreiche Prüfung und der Testboot der signierten
Lanzaboote-Generation. Beim Import vorhandene db-/KEK-Zertifikate von Microsoft
und Hersteller erhalten, neue Zertifikate hinzufügen statt die Datenbanken
pauschal zu ersetzen. dbx unverändert lassen. Bei unklaren Firmware-Optionen
zuerst deren genaue Bezeichnungen klären. Den Platform Key zuletzt einschreiben;
dies kann den Setup Mode beenden und Secure Boot unmittelbar erzwingen.

Falls die Firmware statt DER-Zertifikaten ausdrücklich `.esl` oder `.auth`
verlangt, passende Formate gesondert erzeugen; Dateien nicht einfach umbenennen.
Die Vorbereitung des Sticks selbst hat keine Firmware-Einstellung verändert.

## Rückfallstrategie

- Bei Problemen vor dem Enrollment bleibt Secure Boot aus; bisherige
  funktionierende Generation über das Bootmenü starten.
- Bei Problemen nach dem Enrollment zuerst Secure Boot im Firmware-Menü
  deaktivieren, dann eine bekannte funktionierende Generation starten. Nicht
  wahllos Firmware-Schlüssel löschen oder Factory Keys zurücksetzen.
- Falls das Bootmenü nicht erreichbar ist: vorbereitetes Rettungsmedium nutzen,
  Root mit der bestehenden Passphrase öffnen, Root und EFI-Partition korrekt
  mounten und die Bootkonfiguration aus der Installation heraus reparieren.
- Signierte Generationen und Backups erst nach Abschluss aller Tests bereinigen.
  Keine Nix-Garbage-Collection während der Umstellung.

## Phase 2: Nitrokey 3A und 3C für LUKS

Diese Phase beginnt erst nach stabil funktionierendem Secure Boot:

1. Firmwareversionen, FIDO2-/`hmac-secret`-Unterstützung und bestehenden Einsatz
   beider Nitrokeys prüfen. Bestehende PINs/Registrierungen erhalten; kein Reset,
   keine ungefragte Firmware-Aktualisierung.
2. LUKS2, verfügbare Slots und systemd-initrd/FIDO2-Unterstützung in der konkreten
   NixOS-Konfiguration prüfen. Root und separat verschlüsselten Swap gemeinsam
   berücksichtigen, damit nicht unerwartet ein zweiter Passwortdialog bleibt.
3. Jeden Nitrokey einzeln über `systemd-cryptenroll` registrieren; nur den gerade
   gemeinten Token anstecken. PIN und Berührung verlangen. Die beiden Token sind
   alternative Entsperrwege, keine notwendige Kombination und keine geklonten
   Schlüssel.
4. Jeden Token beim Booten separat testen, ebenso die Passphrase ohne Token und
   den Fall eines fehlenden Tokens. Bestehende Passphrase-Slots nicht löschen.
5. Einen Token für den Alltag wählen, den anderen getrennt sicher aufbewahren.
   Header-Backups nach der Registrierung erneut erstellen und sicher verwalten.

Die Nitrokeys ersetzen nicht die lokalen Lanzaboote-/sbctl-Signierschlüssel.
Ein eigener TPM-Entsperrslot wäre ein weiterer alternativer Zugang, nicht
automatisch ein zusätzlicher Faktor zum Nitrokey; deshalb bleibt er zunächst aus.

## Grenzen und Wechselwirkungen

- Secure Boot schützt den Bootpfad, nicht automatisch alle Dateien des laufenden
  Systems. Es ersetzt weder Updates noch Backups oder Zugriffsschutz.
- Firmware-Einstellungen gegen unbefugtes Abschalten von Secure Boot absichern.
- Beibehaltene Fremdzertifikate verbessern Kompatibilität, erweitern aber die
  Menge vertrauenswürdiger Bootsoftware. Firmware und dbx aktuell halten.
- Kernel-Lockdown kann BPF-Funktionen oder unsignierte externe Kernelmodule
  einschränken. OpenSnitch verwendet zunächst das eBPF-Monitoring; falls dieses
  unter Secure Boot nicht funktioniert, gezielt `ProcMonitorMethod = "proc"`
  prüfen, statt Secure Boot pauschal abzuschalten.
- Automatische TPM-Entsperrung erst danach planen, inklusive Recovery-Key,
  Update-tauglicher PCR-Policy und gegebenenfalls PIN.

## Quellen

- https://nix-community.github.io/lanzaboote/
- https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html
- https://nix-community.github.io/lanzaboote/getting-started/enable-secure-boot.html
- https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html
