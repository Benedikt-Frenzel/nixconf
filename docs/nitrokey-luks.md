# Nitrokey 3C für LUKS auf geeky

## Status: 3C registriert und bootgetestet

Der Nitrokey 3C ist auf beiden LUKS2-Volumes registriert (je Slot 0 Passphrase,
Slot 1 fido2). Der erste Boot-Test mit Generation 22 war erfolgreich: Root und
Swap wurden per FIDO2-PIN und Berührung entschlüsselt, Secure Boot blieb aktiv,
und Generation 22 ist aktueller und Standard-Eintrag. Das dritte age-Backup
(`20261019T175933Z-pre-secureboot.tar.age`) enthält die neuen LUKS2-Header mit
den `systemd-fido2`-Tokens und ist verifiziert.

Noch offen: der Test-Boot ohne Token muss den Rückfall auf die Passphrase
zeigen. Danach kann der Nitrokey 3A als weiterer alternativer Entsperrweg
registriert werden.

## Stand und Sicherheitsgrenzen

Der angeschlossene Nitrokey 3 wird als FIDO2-kompatibel erkannt und unterstützt
`hmac-secret`, Client-PIN und Berührung. Beim Prüfen war er das einzige gelistete
FIDO2-Gerät (`/dev/hidraw7`; dieser Pfad ist nicht dauerhaft stabil). Der Benutzer
hat den Nitrokey 3C für die erste Registrierung gewählt; die USB-Identifikation
allein unterscheidet nicht zwischen 3A und 3C.

Die FIDO2-PIN ist bereits gesetzt. Keine PIN erraten, zurücksetzen oder ändern:
Eine falsche PIN kann den Token nach mehreren Versuchen sperren. Bestehende
Passkeys und andere Registrierungen bleiben unverändert. Ein FIDO2-Reset würde
auch die LUKS-Nutzung zerstören und ist kein Reparaturschritt.

Root und Swap sind separate LUKS2-Volumes. Beide benötigen eine eigene
Registrierung. Die bestehenden Passphrase-Slots bleiben erhalten. TPM-Unlock
wird nicht eingerichtet. Der Nitrokey 3A kommt später als eigener alternativer
Entsperrweg hinzu; FIDO2-Geheimnisse werden nicht zwischen Token geklont.

## Konfiguration vorbereitet, noch keine Registrierung durchgeführt

`nixos/features/nitrokey.nix` aktiviert FIDO2-Unterstützung im systemd-initrd und
setzt für beide Volumes `fido2-device=auto` sowie `token-timeout=15s`. Letzteres
begrenzt das Warten auf einen fehlenden Token, nicht die Anzahl erlaubter
PIN-Versuche. Die PIN-/Berührungsanforderung wird bei der Registrierung in den
LUKS-Metadaten festgelegt. Ohne Token bleibt die bestehende Passphrase nutzbar.

Die Konfiguration registriert keine Schlüssel selbst und enthält weder PINs
noch Passphrasen. Noch nicht neu starten: erst Registrierung, neues Header-
Backup und Systemwechsel abschließen.

## Interaktive Registrierung

Nur den 3C anstecken, den 3A und andere FIDO2-Token abziehen. Die vorhandene
FIDO2-PIN und die bestehenden LUKS-Passphrasen müssen bekannt sein. Vorherige
verschlüsselte Header-Backups sind vorhanden; die Backup-SSD für die Sicherung
nach der Registrierung wieder anschließen.

Zuerst nur lesend die aktuellen Slot-Typen ansehen:

```sh
sudo systemd-cryptenroll /dev/disk/by-uuid/d5607473-66c6-4336-b908-76c88228c592
sudo systemd-cryptenroll /dev/disk/by-uuid/bdfb9b4b-cbce-42df-9d5b-2a283804122e
```

Falls bereits FIDO2-Slots vorhanden sind, zuerst klären, zu welchem Token sie
gehören. Keine Slots löschen oder unnötig doppelt registrieren.

Dann Root registrieren:

```sh
sudo systemd-cryptenroll /dev/disk/by-uuid/d5607473-66c6-4336-b908-76c88228c592 \
  --fido2-device=auto \
  --fido2-with-client-pin=yes \
  --fido2-with-user-presence=yes \
  --fido2-with-user-verification=no
```

Nach erfolgreicher Root-Registrierung Swap registrieren:

```sh
sudo systemd-cryptenroll /dev/disk/by-uuid/bdfb9b4b-cbce-42df-9d5b-2a283804122e \
  --fido2-device=auto \
  --fido2-with-client-pin=yes \
  --fido2-with-user-presence=yes \
  --fido2-with-user-verification=no
```

Die Abfragen für LUKS-Passphrase und FIDO2-PIN sind verschieden. PIN und
Passphrasen nur am lokalen Terminal eingeben, nicht in den Chat oder in
Kommandoargumente. `user-verification=no` betrifft beispielsweise biometrische
Verifikation; die explizite Client-PIN und Berührung sind dennoch erforderlich.

Kein `--wipe-slot` verwenden. Bei Fehlern stoppen, bevor weitere Slots erzeugt
oder PIN-Versuche verbraucht werden. Erfolgreiche neue Slot-Nummern notieren.

## Danach: sichern, aktivieren, testen

1. Beide Slot-Listen erneut prüfen: bisherige Passwort-Slots plus neue
   FIDO2-Slots müssen vorhanden sein.
2. Mit dem age-Backup-Skript ein neues Archiv mit den aktualisierten Root- und
   Swap-Headern erzeugen und prüfen lassen (siehe `secureboot-backup.md`).
3. Systemwechsel mit der neuen initrd-Konfiguration durchführen; Lanzaboote
   signiert die neue Generation. Mit `sudo sbctl verify` und
   `sudo bootctl list --no-pager` kontrollieren.
4. Den Bootstandard prüfen: Ein früheres `bootctl set-default @current` kann noch
   Generation 21 pinnen. Für den Test explizit die neu gebaute Generation wählen,
   nicht unbemerkt die alte initrd starten.
5. Mit dem 3C neu starten, PIN und Berührung testen. Wegen der zwei Volumes sind
   mehrere Abfragen/Berührungen möglich. Danach Root, Swap und Secure Boot prüfen:

   ```sh
   findmnt /
   swapon --show
   bootctl status
   ```

6. Bei einem weiteren Boot ohne Token den Rückfall auf die bekannten
   Passphrasen testen. Diese nicht löschen, auch wenn der Token funktioniert.

Die LUKS-Daten werden nicht neu verschlüsselt. Die neuen Token-Metadaten liegen
im LUKS-Header; ein altes Header-Backup von vor der Registrierung enthält den
neuen Entsperrweg noch nicht. Ein verlorener Token lässt sich später gezielt
über den zugehörigen Slot widerrufen, ohne andere Token zurückzusetzen.
