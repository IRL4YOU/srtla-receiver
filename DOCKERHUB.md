# IRL4YOU SRTLA Receiver

Empfänger für IRL-Streaming: nimmt gebündelte Mobilfunk-Übertragungen (SRTLA) und reines SRT an, gibt den Stream per SRT an OBS weiter und zeigt Statistiken an (auch für NOALBS). Mit Benutzer- und Schlüsselverwaltung im Browser, automatischen Sicherungen und Schutz gegen Passwort-Raten.

**Installation (empfohlen):** Ein Befehl auf einem frischen Ubuntu- oder Debian-Server aktualisiert das System, richtet Git, Docker, `fail2ban`, auf Wunsch HTTPS und SSH-Absicherung ein und installiert den Empfänger:

    wget -qO get.sh https://raw.githubusercontent.com/IRL4YOU/srtla-receiver/main/get.sh && bash get.sh --caddy meine.domain.de --ssh-haerten

Anleitung und Quelltext der geänderten Open-Source-Teile: https://github.com/IRL4YOU/srtla-receiver

**Tags:** `1.0.1` (feste Version, zweisprachige Oberfläche), `1.0.0`, `latest` (neueste Version, wird von `update.sh` verwendet). Das Image ist für `amd64` gebaut.

**Nur das Image ohne Paket:** läuft ohne `fail2ban` und ohne die Trennung des Schlüssels vom Datenvolumen. Das Paket ist der empfohlene Weg.

**Lizenz:** Der Receiver ist kostenlos nutzbar, auch gewerblich für den eigenen Betrieb. Nicht erlaubt ohne unsere Erlaubnis: verkaufen, als Dienst anbieten, weitergeben. Name und Hinweise bleiben stehen (Text: https://github.com/IRL4YOU/srtla-receiver/blob/main/LICENSE). Die enthaltenen Open-Source-Teile behalten ihre Lizenzen: SRTLA-Empfänger AGPL-3.0, SRT-Bibliothek MPL-2.0, SRT-Server MIT. Deren Lizenztexte liegen im Image unter `/usr/share/licenses/irl4you/`.

**Wünsche und Anregungen:** Fehler und Ideen bitte auf GitHub melden: https://github.com/IRL4YOU/srtla-receiver/issues. Fragen und Austausch im Discord: https://discord.gg/7AQRAQAp4C
