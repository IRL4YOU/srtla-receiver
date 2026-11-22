# IRL4YOU SRTLA Receiver

Empfänger für IRL-Streaming: nimmt gebündelte Mobilfunk-Übertragungen (SRTLA) und reines SRT an, gibt den Stream per SRT an OBS weiter und zeigt Statistiken an (auch für NOALBS). Mit Benutzer- und Schlüsselverwaltung im Browser, automatischen Sicherungen und Schutz gegen Passwort-Raten.

**Installation (empfohlen):** Das Paket mit `install.sh` richtet Empfänger, `fail2ban`, auf Wunsch HTTPS und SSH-Absicherung ein:

    git clone https://github.com/IRL4YOU/srtla-receiver.git
    cd srtla-receiver && bash install.sh --caddy meine.domain.de --ssh-haerten

Anleitung und Quelltext der geänderten Open-Source-Teile: https://github.com/IRL4YOU/srtla-receiver

**Tags:** `1.0.0` (feste Version), `latest` (neueste Version, wird von `update.sh` verwendet). Das Image ist für `amd64` gebaut.

**Nur das Image ohne Paket:** läuft ohne `fail2ban` und ohne die Trennung des Schlüssels vom Datenvolumen. Das Paket ist der empfohlene Weg.

**Lizenzen:** SRTLA-Empfänger AGPL-3.0, SRT-Bibliothek MPL-2.0, SRT-Server MIT. Die Lizenztexte liegen im Image unter `/usr/share/licenses/irl4you/`.

**Wünsche und Anregungen:** Fehler und Ideen bitte auf GitHub melden: https://github.com/IRL4YOU/srtla-receiver/issues. Fragen und Austausch im Discord: https://discord.gg/7AQRAQAp4C
