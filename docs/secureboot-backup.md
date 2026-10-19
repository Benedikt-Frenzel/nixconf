# age-verschlüsseltes Recovery-Backup

## Vorbereitet

- Externe SSD: `/dev/sda1`, Label `Ventoy`, eingehängt unter
  `/run/media/ben/Ventoy`. Bestehende Dateien, insbesondere `home.tar`, bleiben
  unverändert; das Laufwerk wird nicht formatiert.
- 1Password-Vault: `geeky#ben`
- Passwort-Eintrag: `geeky Secure Boot recovery backup (age)`
- Item-ID: `em6hppzghpxzlmezdeabuccmyu`
- Zufällige Passphrase mit 64 Zeichen, von 1Password generiert. Sie liegt weder
  im Repository noch in einem Klartext-Passwortfile.

## Verifiziertes Backup

`Backups/geeky/secureboot/20261019T160517Z-pre-secureboot.tar.age` ist vorhanden.
SHA-256, vollständige Entschlüsselung und tar-Struktur wurden nachträglich geprüft;
EFI-Dateien, beide LUKS2-Header und die Nix-Konfiguration sind enthalten.
Das Archiv enthält noch keine später erzeugten Secure-Boot-Signierschlüssel.

Nach der Schlüsselerzeugung wurde
`20261019T172615Z-pre-secureboot.tar.age` erstellt und ebenfalls geprüft:
SHA-256, vollständige Entschlüsselung, tar-Struktur, Recovery-Dateien und die
privaten Schlüssel samt Zertifikaten für PK, KEK und db sind enthalten.

## Erstellen und prüfen

Im Repository als normaler Desktop-Benutzer ausführen, **nicht** das gesamte
Kommando mit sudo starten:

```sh
nix shell --inputs-from . nixpkgs#age nixpkgs#python3 nixpkgs#efibootmgr nixpkgs#cryptsetup \
  -c python3 scripts/backup-secureboot.py
```

Das Skript fragt sudo an und liest die Passphrase aus der laufenden
1Password-Sitzung. Es sammelt:

- beide LUKS-Header von Root und Swap;
- die komplette EFI-Partition unter `/boot`;
- den aktuellen Repository-Inhalt einschließlich uncommitteter Änderungen und
  Git-Historie;
- `bootctl status`, `efibootmgr -v` und vorhandene EFI-Schlüssel-/Bootvariablen;
- `/var/lib/sbctl`, falls bei einer späteren Sicherung bereits vorhanden.

Die LUKS-Header werden nur vorübergehend in einem root-exklusiven Verzeichnis
unter `/run` abgelegt. Das tar-Archiv wird direkt an age gestreamt. Die
Passphrase wird über ein privates Terminal übergeben, nicht über Argumente,
Umgebungsvariablen oder Logausgaben.

Anschließend wird das Archiv vollständig entschlüsselt durch einen tar-Lesetest
geschickt, ohne es im Klartext auf die SSD zu schreiben. Beide Header und die
Boot-Metadaten müssen vorhanden sein. Erst nach erfolgreicher Prüfung erhält
die Datei ihren endgültigen Namen:

```text
Ventoy/Backups/geeky/secureboot/<UTC-Zeit>-pre-secureboot.tar.age
Ventoy/Backups/geeky/secureboot/<UTC-Zeit>-pre-secureboot.tar.age.sha256
```

Unvollständige Sicherungen behalten die Endung `.partial`. Vorhandene Backups
werden nicht überschrieben. Bei geänderten Laufwerksnamen stoppt das Skript,
statt stillschweigend auf ein anderes Laufwerk zu schreiben.

Die Verschlüsselungs-/Entschlüsselungspipeline kann ohne sudo und ohne echte
Daten mit `--self-test` getestet werden.

## Recovery

Vor Beginn der Secure-Boot-Umstellung sicherstellen, dass der Passwort-Eintrag
auch von einem anderen Gerät erreichbar ist. Der einzige Weg zur Passphrase
darf nicht die verschlüsselte Installation auf geeky sein. Gegebenenfalls eine
zusätzliche, getrennt sicher verwahrte Recovery-Kopie vorsehen.

Auf einem vertrauenswürdigen Rettungssystem age installieren, Passphrase aus
1Password holen und zuerst nur den Inhalt anzeigen:

```sh
set -o pipefail
age --decrypt /pfad/zum/backup.tar.age | tar -tf -
```

age fragt interaktiv nach der Passphrase. Zur Extraktion ein privates Verzeichnis
auf einem verschlüsselten Datenträger oder einem ausreichend großen tmpfs
verwenden, nicht die unverschlüsselte exFAT-SSD. Keine automatisierte
Wiederherstellung von LUKS-Headern oder EFI-Variablen: Dabei Zielgeräte und
Auswirkungen vorher separat prüfen.

**Grenze:** Dies ist ein Recovery-Backup für die Boot-Umstellung. Persönliche
Dateien, Vaults, Musik und die vollständige Root-Installation sind damit nicht
gesichert. Das alte `home.tar` wird hier weder neu verschlüsselt noch gelöscht.
