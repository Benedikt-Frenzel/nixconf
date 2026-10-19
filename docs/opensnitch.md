# OpenSnitch auf geeky

`nixos/features/opensnitch.nix` aktiviert den Systemdienst `opensnitchd` und
installiert `opensnitch-ui`. Die UI startet als systemd-Benutzerdienst mit der
grafischen Sitzung. Die vorhandene NixOS-Firewall bleibt unverändert aktiv,
einschließlich UDP 24727 für AusweisApp und der Syncthing-Ports.

## Erste Aktivierung

Nach dem üblichen Systemwechsel für die bereits laufende Sitzung:

```sh
systemctl --user start opensnitch-ui.service
systemctl status opensnitchd.service
systemctl --user status opensnitch-ui.service
```

Bei späteren Anmeldungen startet die UI automatisch. Sie ist auch über den
App-Launcher bzw. das Tray erreichbar. In der UI Verbindung zum lokalen Daemon
und auftauchende Anfragen prüfen. Nicht pauschal alle Programme freigeben.

Unbedingt testen:

- DNS und Webbrowser, auch mit 1Password-Integration
- Nix-Downloads und Updates
- Syncthing, insbesondere den bestehenden Musik-Sync
- AusweisApp: Smartphone-Erkennung, Pairing und Verbindung
- Steam und andere tatsächlich verwendete Netzwerkanwendungen

Die Freigabe eingehender Ports allein ersetzt keine OpenSnitch-Regel für
ausgehende Verbindungen. Regeln auf konkrete Programme und bei Bedarf Ziele
begrenzen. Nix-Store-Pfade ändern sich bei Updates; pfadgebundene Regeln können
dann neue Rückfragen auslösen. Keine pauschale Freigabe für `/nix/store` setzen.

## Verhalten und Persistenz

Für den Einstieg gelten die Upstream-Werte `DefaultAction = "allow"`,
`DefaultDuration = "once"` und `InterceptUnknown = false`: Ohne erreichbare UI
soll das Netzwerk nicht pauschal blockiert werden. Mit verbundener UI werden neue
Anwendungen abgefragt. Das ist bewusst kein lückenloses Fail-closed-Setup;
unbeantwortete UI-Popups haben eigene Timeout-Einstellungen. Eine strengere
Policy erst nach erfolgreichem Test und mit Regeln für benötigte Systemdienste
einführen.

Regeln unter `/var/lib/opensnitch` und UI-Einstellungen unter
`~/.config/opensnitch` sind für Persistenz vorgesehen. Die UI verwendet zunächst
ihre Standard-Datenbankeinstellung; dauerhafte Verbindungsprotokolle sind nicht
gesondert eingerichtet.

Bei Problemen:

```sh
journalctl -u opensnitchd.service -b
journalctl --user -u opensnitch-ui.service -b
```

Zum zeitweisen Abschalten der zusätzlichen Anwendungsfilterung:

```sh
sudo systemctl stop opensnitchd.service
```

Die NixOS-Firewall bleibt dabei aktiv. Der Dienst wird damit nicht dauerhaft aus
der Konfiguration entfernt.
