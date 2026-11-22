# Sicherheit

## Sicherheitslücken melden

Bitte **nicht** öffentlich im Kanal oder als Fehlermeldung, sondern vertraulich als **Direktnachricht an die Betreiber** im Discord: https://discord.gg/7AQRAQAp4C.
Nenne die Version (steht am Ende jeder Seite der Verwaltung) und eine Beschreibung.

## Was geschützt ist

- Zugangsdaten nur als Hash, Schlüssel als Hash und verschlüsselte Kopie; der Schlüssel dazu liegt außerhalb des Datenvolumens.
- Anmeldesperre in der Anwendung und `fail2ban` (SSH, Weboberfläche, Wochensperre), eingerichtet durch `install.sh`.
- Das Sicherheitsprotokoll speichert keine IP-Adressen und keine eingetippten Namen.

## Hinweise für den Betrieb

- Die Verwaltung nur über HTTPS (`install.sh --caddy DOMAIN`) oder per SSH-Tunnel erreichbar machen.
- SSH nur mit Schlüssel (`install.sh --ssh-haerten`).
- Den Ordner `secrets/` zusammen mit den Sicherungen aufbewahren, aber nicht weitergeben.
- Der Update-Hinweis fragt einmal am Tag eine öffentliche Adresse ab (Programmname und Version). Abschalten: `IRL4YOU_UPDATE_CHECK=0`.
