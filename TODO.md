# geeky

- Nicht `nixos-rebuild switch` auf dem laufenden System. GDM/GNOME fällt sofort weg, nixconf startet keinen Display-Manager.
- Erst bauen, dann booten: `sudo nixos-rebuild boot --flake /home/ben/Projects/nixconf#geeky`, danach neu starten.
- Nach dem Boot: tuigreet auf tty1, einloggen als `ben`. Die Session ist `niri-session`.
- Andere TTYs bleiben erreichbar mit Ctrl+Alt+F2.
- Bestehendes Passwort von `ben` bleibt. `12345` aus `general.nix` gilt nur, wenn der User neu angelegt wird.

# Eval-Warnungen / Build-Hinweise

- Erledigt: `hardware.opengl` durch `hardware.graphics` ersetzt.
- Erledigt: `youtube-music` durch `pear-desktop` ersetzt.
- Erledigt: Paket-Systemzugriffe verwenden `stdenv.hostPlatform.system`.
- Erledigt: Nix-Download-Buffer auf 256 MiB gesetzt.
- Hinweis: Es existiert nur noch der Host `geeky`; main und mini wurden entfernt.
