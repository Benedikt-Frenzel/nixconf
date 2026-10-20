# rclone: Proton Drive, Google Drive und der Hochzeit-Sync

## Übersicht

`~/Documents/Hochzeit` ist der lokale Dreh- und Angelpunkt:

- **Syncthing** verteilt den Ordner auf die eigenen Geräte
  (Ordner-ID `hochzeit`, deklariert in `nixos/features/syncthing.nix`).
- **rclone bisync** hält den Ordner zusätzlich mit zwei Clouds im Takt:
  - Proton Drive: `protondrive:Hochzeit`
  - Google Drive: `gdrive:wir/Hochzeit` (Shared Drive „wir")
- **rclone mount** hängt das komplette Google Drive unter `~/GDrive` ein
  (Shared Drives wie „wir" liegen dort als Unterordner).

rclone 1.75 bringt den `protondrive`-Backend mit — ein separates
Proton-CLI ist nicht nötig. Der Sync läuft stündlich über den
systemd-Timer `hochzeit-sync`, zusätzlich gibt es das Kommando
`hochzeit-sync` für manuelle Läufe.

## Remotes einrichten (einmalig, interaktiv)

Beide Remotes liegen nach `~/.config/rclone/rclone.conf` (persistiert).
Solange die Datei fehlt, bleiben `rclone-mount-gdrive` und `hochzeit-sync`
inaktiv (ConditionPathExists).

### Google Drive

```console
$ rclone config
```

- New remote → Name: `gdrive`
- Typ: `drive`
- client_id / client_secret: leer lassen (rclone-Standard-OAuth)
- scope: `1` (full access)
- root_folder_id / service_account: leer
- Auto config: `y` — Browser-OAuth öffnet sich, einmal bei Google anmelden
- Shared Drives müssen nicht extra konfiguriert werden; `wir` erscheint
  automatisch als Verzeichnis unter `gdrive:`.

Prüfen:

```console
$ rclone lsd gdrive:
$ rclone lsd gdrive:wir
```

### Proton Drive

Ebenfalls `rclone config`, Remote-Name `protondrive`, Typ `protondrive`:

- Username: Proton-Adresse
- Password: Proton-Passwort (rclone verschleiert es selbst)
- 2FA: einmaligen Code eingeben oder den TOTP-Secret hinterlegen
  (`--protondrive-otp-secret-key`, damit der headless Sync mit 2FA läuft)
- Falls das Konto im Two-Password-Modus ist: Mailbox-Password

Prüfen:

```console
$ rclone lsd protondrive:
```

**opensnitch** fragt beim ersten Zugriff nach ausgehenden Verbindungen von
`rclone` — einmal erlauben (auch für den systemd-Dienst).

## Erster Sync (einmalig)

bisync braucht einen einmaligen `--resync`, sonst bricht jeder Lauf ab.
Erst trocken üben, dann echt:

```console
$ hochzeit-sync --resync --dry-run
$ hochzeit-sync --resync
```

Voreinstellung ist `--resync-mode path1` — **lokal gewinnt** auf beiden
Remotes. Hat `gdrive:wir/Hochzeit` schon Inhalte (z. B. vom Partner),
stattdessen pro Remote resyncen und die neuere Version gewinnen lassen:

```console
$ rclone bisync ~/Documents/Hochzeit protondrive:Hochzeit \
    --resync-mode newer -v
$ rclone bisync ~/Documents/Hochzeit "gdrive:wir/Hochzeit" \
    --resync-mode newer --drive-skip-gdocs -v
```

Danach läuft alles über den Timer; `--resync` nie dauerhaft mitgeben.

## Betrieb

```console
$ systemctl list-timers hochzeit-sync        # nächster Lauf
$ journalctl -u hochzeit-sync -f            # Live-Log
$ hochzeit-sync                              # manueller Lauf
$ hochzeit-sync --dry-run                    # nur anzeigen
$ systemctl status rclone-mount-gdrive       # ~/GDrive Mount
$ rclone lsd gdrive:wir/Hochzeit             # Remote direkt ansehen
```

## Verhalten im Detail

- **Konflikte** (Datei auf beiden Seiten geändert): `--conflict-resolve newer`
  — die neuere Datei gewinnt, die unterlegene bleibt als `datei.conflict1`
  erhalten und wird überall hin synchronisiert. Solche Dateien manuell
  auflösen und die `.conflict*`-Kopie danach löschen.
- **Google Docs**: `--drive-skip-gdocs` — native Google Docs überspringt
  bisync (Export-Checksummen ändern sich bei jedem Lauf). Docs sind über
  den `~/GDrive`-Mount oder drive.google.com erreichbar, aber der Partner
  sollte normale Dateien (z. B. `.docx`, `.odt`) in `wir/Hochzeit` legen,
  wenn sie bis zu Proton Drive synchronisiert werden sollen.
- **Syncthing-Reste**: `.stfolder`, `~syncthing~*`-Tempdateien und Office-
  Lockfiles (`~$*`) filtert die bisync-Filterdatei aus. Sie liegt unter
  `~/.config/rclone/hochzeit-bisync-filters.txt` und wird von `hochzeit-sync`
  vor jedem Lauf aus dem Nix Store aktualisiert. Wird ihr Inhalt geändert,
  verlangt bisync beim nächsten Lauf `--resync` (MD5-Prüfung).
- **Sicherungen**: `--resilient --recover --max-lock 2m` lassen bisync nach
  Fehlversuchen/Abstürzen selbst weitermachen, statt dauerhaft
  `--resync` zu verlangen. Löschen ist durch `--max-delete 50%` gekappt.
- **Timer**: stündlich (`OnCalendar=hourly`, `Persistent=true` — versäumte
  Läufe laufen nach dem Boot nach).
- Der Mount-Dienst startet erst mit `~/.config/rclone/rclone.conf` und
  holt sich `fusermount3` aus `/run/wrappers/bin` (setuid).

## Was bewusst nicht synchronisiert wird

- Der Proton-Drive-Mount ist bewusst nicht eingerichtet; bisync reicht für
  den Abgleich. Bei Bedarf: `rclone mount protondrive: ~/PDrive`.
- Syncthing-Geräte für den Ordner `hochzeit` sind noch leer
  (`nixos/features/syncthing.nix`) — Geräte-IDs aufnehmen, sobald die
  Peers stehen. Freigaben nur in der Weboberfläche zu ändern verfällt bei
  der nächsten Aktivierung (deklarative Konfiguration ersetzt sie).
