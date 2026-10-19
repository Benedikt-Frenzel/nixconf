# Obsidian und Syncthing

## Vaults

- `~/Documents/Private`
- `~/Documents/Genealogy`

Beide Vaults sind in Obsidian registriert. Neue Notizen landen in `Inbox`,
Dateianhänge in `Anhänge`. Die Syncthing-Ordner-IDs sind `obsidian-private`
und `obsidian-genealogy`. Die gerätespezifischen Dateien
`.obsidian/workspace.json` und `.obsidian/workspace-mobile.json` werden nicht
synchronisiert.

Die Vaults haben zunächst keine Remote-Geräte. Gewünschte Geräte später in
`services.syncthing.settings.devices` aufnehmen und in den jeweiligen
`settings.folders.<name>.devices` referenzieren. Die deklarative Konfiguration
ersetzt die Vault-Freigaben bei jeder Aktivierung; diese daher nicht nur in der
Weboberfläche ändern. Private und Genealogy können unterschiedliche Peers haben.

## Charted Roots

Im Genealogy-Vault ist das Community-Plugin **Charted Roots 0.22.76** installiert
und in `.obsidian/community-plugins.json` aktiviert. Die Dateien `main.js`,
`manifest.json` und `styles.css` stammen aus dem offiziellen
[Release](https://github.com/banisterious/obsidian-charted-roots/releases/tag/0.22.76);
ihre SHA-256-Prüfsummen wurden gegen die GitHub-Release-Metadaten geprüft.
Das Plugin liegt lokal unter `.obsidian/plugins/charted-roots`, nicht im
Nix-Store. Updates sind über Obsidian → Einstellungen → Community-Plugins möglich.
Falls Obsidian nachfragt, Community-Plugins für diesen Vault erlauben.
Der Private-Vault hat dieses Plugin nicht.

## Gramps

Gramps ist zusätzlich als eigenständige Genealogie-Anwendung eingerichtet.
Seine Daten und Einstellungen unter `~/.gramps` sind für Persistenz vorgesehen.
Die Gramps-Datenbank bleibt lokal und wird nicht mit Syncthing synchronisiert.
Zwischen Gramps und Charted Roots ist kein automatischer Datenabgleich
eingerichtet; ein Austausch ist bei Bedarf über GEDCOM möglich.

## Wiederhergestellte Installation

Die bestehende Identität und Konfiguration wurden aus `home.tar` von der externen
SSD nach `~/.local/state/syncthing` wiederhergestellt. Die privaten Schlüssel
liegen ausschließlich dort, nicht im Repository oder Nix-Store. Die ursprüngliche
Konfiguration liegt daneben als `config.xml.before-restore`; die alte Datenbank
wurde nicht übernommen. Das Archiv auf der SSD bleibt unverändert.

Die NixOS-Konfiguration betreibt Syncthing als Systemdienst unter dem normalen
Benutzer. Die Weboberfläche ist nur auf `http://127.0.0.1:8384` erreichbar.
Die üblichen Sync- und Discovery-Ports sind in der Firewall freigegeben.

Bestehende Geräte und Ordner bleiben erhalten (`overrideDevices = false`,
`overrideFolders = false`). Der wiederhergestellte Musikordner bleibt bewusst
außerhalb der deklarativen Ordnerliste:

- Pfad: `~/Music`
- ID: `wnkld-4s59j`
- Modus: `receiveonly` (nur empfangen)
- Zustand nach Wiederherstellung: pausiert

Nach dem Systemwechsel in der Weboberfläche die Gegenstellen und deren
Musikbestand prüfen, dann den Musikordner fortsetzen. Das lokale Musikverzeichnis
war bei der Wiederherstellung leer. Syncthing baut die lokale Datenbank neu auf.
Nicht versehentlich „Lokale Änderungen zurücksetzen“ oder einen anderen
Sync-Modus auswählen, ohne die Auswirkungen auf vorhandene Dateien zu prüfen.

## Aktivierung

```sh
sudo nixos-rebuild switch --flake path:.#geeky
systemctl status syncthing.service
```

Danach Obsidian starten und die beiden registrierten Vaults öffnen. Auf weiteren
Geräten dieselben Syncthing-Ordner-IDs verwenden und die Ordner jeweils als Vault
öffnen. Es gibt derzeit keine konfigurierte Backup-Lösung: Persistenz und
Synchronisation ersetzen kein unabhängiges Backup.
