# geeky

- Nicht `nixos-rebuild switch` auf dem laufenden System. GDM/GNOME fällt sofort weg, nixconf startet keinen Display-Manager.
- Erst bauen, dann booten: `sudo nixos-rebuild boot --flake /home/ben/Projects/nixconf#geeky`, danach neu starten.
- Nach dem Boot: TTY-Login als `ben`, Session mit `niri-session`.
- Bestehendes Passwort von `ben` bleibt. `12345` aus `general.nix` gilt nur, wenn der User neu angelegt wird.

# Eval-Warnungen / Build-Hinweise

- Erledigt: `hardware.opengl` durch `hardware.graphics` ersetzt.
- Erledigt: `youtube-music` durch `pear-desktop` ersetzt.
- Erledigt: Paket-Systemzugriffe verwenden `stdenv.hostPlatform.system`.
- Erledigt: Nix-Download-Buffer auf 256 MiB gesetzt.
- Erledigt: veraltete WiVRn-Option `defaultRuntime` entfernt; WiVRn verwaltet den Runtime-Eintrag selbst.
- Hinweis: Es existiert nur noch der Host `geeky`; main und mini wurden entfernt.
