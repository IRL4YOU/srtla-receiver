# Details

## Optionen von `install.sh`

| Option | Wirkung |
|---|---|
| `--caddy DOMAIN` | HTTPS für die Verwaltung (Caddy mit automatischem Zertifikat). Die Domain muss auf den Server zeigen, Ports 80 und 443 müssen offen sein. |
| (ohne `--caddy`) | Das Skript fragt, wo der Server steht. **1** (Enter): Verwaltung direkt über IP und Port, `http://IP:8181/schluessel`, unverschlüsselt, nur für das eigene Netz. **2**: Rechenzentrum, eigene Domain oder automatische Adresse aus der IP (`…sslip.io`), HTTPS mit Let's Encrypt. |
| `--https-ip` | Stattdessen HTTPS über die IP mit selbst signiertem Zertifikat (Caddy, Port 443). Der Browser warnt einmal. |
| `--ohne-https` | Verwaltung nur lokal auf dem Server, Zugriff per SSH-Tunnel (`ssh -L 8181:127.0.0.1:8181 benutzer@server`, dann `http://localhost:8181/schluessel`). |
| `--ausfuehrlich` | Alle Meldungen zeigen. Sonst erscheint nur ein Fortschrittsbalken und am Ende eine Zusammenfassung (Protokoll in `/tmp/irl4you-install-*.log`). |
| `--ssh-haerten` | SSH nur noch mit Schlüssel (Passwort-Anmeldung aus). Nur wenn ein Schlüssel hinterlegt ist, nach Rückfrage. Danach in einem zweiten Fenster prüfen, ob die Anmeldung klappt. |
| `--nur-schutz` | Nur `fail2ban` (und auf Wunsch SSH/Caddy) einrichten, der Empfänger läuft schon. |
| `--ohne-fail2ban` | Schutz weglassen (nicht empfohlen). |
| `--ja` | Rückfragen automatisch mit Ja beantworten. |

Umgebungsvariablen: `IRL4YOU_IGNORE_NETS="192.168.1.0/24"` (eigene Netze, die nie gesperrt werden), `IRL4YOU_BANTIME=1h` (Sperrzeit).
Das Image kommt von Docker Hub. Liegt im Ordner eine Datei `srtla-*.tar.gz` (mit `.sha256`), wird sie stattdessen geladen (ohne Internet).

## Schutz

- **Zugangsdaten** liegen nur als Hash vor. Schlüssel liegen als Hash und verschlüsselte Kopie vor; der Schlüssel dazu liegt in `secrets/enc.key` **außerhalb** des Datenvolumens. Geht er verloren, laufen alle Streams weiter, nur die Anzeige der gespeicherten Schlüssel fällt aus.
- **Anmeldesperre in der Anwendung:** 10 Fehlversuche je Name und Adresse, 20 je Adresse, in 5 Minuten.
- **`fail2ban`:** SSH (5 Fehlversuche in 10 Minuten, 1 Stunde Sperre), Weboberfläche (10 Fehlversuche) und **Wochensperre** für Wiederholungstäter (10 Sperren in 7 Tagen, 1 Woche, nur SSH und Web). Die Sender-Ports bleiben frei, weil sich Mobilfunknetze Adressen teilen. Die Adresse der Sitzung, über die installiert wurde, wird nie gesperrt.
- Gesperrte Adressen ansehen: `sudo fail2ban-client status sshd` (ebenso `irl4you-web`, `irl4you-recidive`). Aufheben: `sudo fail2ban-client set sshd unbanip ADRESSE`.
- **Sicherheitsprotokoll** in der Verwaltung: Art und Zeit von Fehlversuchen, Sperren und wichtigen Aktionen, **ohne IP-Adressen und ohne eingetippte Namen**.
- Sieht die Verwaltung `fail2ban` nicht, zeigt sie oben einen Hinweis (ausblenden: `IRL4YOU_NO_F2B_HINT=1` in der `compose.yaml`).
- Läuft nur das Image ohne unser Paket, gibt es kein `fail2ban` und der Schlüssel liegt im Datenvolumen. Das Paket mit `install.sh` ist der empfohlene Weg.

## Sicherungen

Der Server sichert die Datenbank selbst: 3 Stunden nach der letzten Änderung, vor dem Löschen eines Benutzers oder Streams und vor jeder Wiederherstellung. Es bleiben höchstens 10 (die 6 neuesten und 4 ältere im größeren Abstand). Sie liegen auf demselben Server und schützen vor Bedienfehlern, nicht vor dem Verlust des Servers: Dafür eine Sicherung herunterladen.

## Updates

- Jede Version ist ein vollständiges Image. `update.sh` richtet sich nach dem Zustand der Installation, nicht nach der Nummer: Man kann von jeder älteren Version direkt auf die neueste wechseln, Zwischenversionen müssen nicht einzeln eingespielt werden.
- **Update-Hinweis:** Einmal am Tag fragt der Server eine öffentliche Adresse nach der neuesten Version ab (mitgeschickt werden nur Programmname und Version; der Zielserver sieht die Adresse deines Servers). Die Karte **Updates und Hilfe** zeigt das Ergebnis, hat den Knopf **Jetzt prüfen** und Links zur Anleitung, zum Melden von Fehlern und Wünschen (GitHub) und zum Discord. Abschalten: `IRL4YOU_UPDATE_CHECK=0`, eigene Adresse: `IRL4YOU_UPDATE_URL` (in der `compose.yaml` unter `environment`). Eingespielt wird nie automatisch.
- Ohne Internet: neue Image-Datei `srtla-*.tar.gz` (mit `.sha256`) und `update.sh` in den Ordner legen, `bash update.sh` ausführen.

## Betriebssystem-Updates

```bash
sudo apt update && sudo apt dist-upgrade
```

Ein Neustart ist nur nötig, wenn die Datei `/var/run/reboot-required` existiert. Der Container startet danach von selbst.

## Hinweise

- In der Grundeinstellung (`compose.yaml`) ist `8181` (Verwaltung) auf `127.0.0.1` beschränkt; `install.sh` öffnet `8181` ohne `--caddy` für das eigene Netz (Datei `compose.override.yaml`). `8282/udp` (OBS) ist offen, der Zugriff ist durch den OBS-Schlüssel geschützt. Läuft OBS immer auf dem Server selbst, kann man in der `compose.yaml` bei `8282` ein `127.0.0.1:` davorsetzen.
- Die Log-Grenzen (`max-size`, `max-file`) in der `compose.yaml` nicht entfernen.
- Quelltext der geänderten Open-Source-Teile: Ordner `quellen/` und `NOTICE.md`.
