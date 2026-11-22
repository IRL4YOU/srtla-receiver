# IRL4YOU SRTLA Receiver

Empfänger für IRL-Streaming: nimmt gebündelte Mobilfunk-Übertragungen (SRTLA) und reines SRT an, gibt den Stream per SRT an OBS weiter und zeigt Statistiken an (auch für NOALBS). Mit Benutzer- und Schlüsselverwaltung, Sicherungen und Schutz gegen Passwort-Raten, als Docker-Image.

*English in short:* SRTLA/SRT ingest with per-stream keys, web admin, backups and fail2ban hardening, packaged as a Docker image. Documentation is in German.

## Schnellstart

Ein Befehl auf einem frischen Ubuntu- oder Debian-Server (aktualisiert das System, richtet Git und Docker ein, installiert alles):

```bash
wget -qO get.sh https://raw.githubusercontent.com/IRL4YOU/srtla-receiver/main/get.sh && bash get.sh --caddy meine.domain.de --ssh-haerten
```

Ohne Domain: `bash get.sh` ohne Optionen (Verwaltung im eigenen Netz über `http://IP:8181/schluessel`). Am Ende zeigt eine Zusammenfassung Adresse, Einmalcode und Ports. Im Rechenzentrum immer mit `--caddy DOMAIN`.

Die ganze Anleitung steht in [ANLEITUNG.md](ANLEITUNG.md), Optionen und Hintergründe in [DETAILS.md](DETAILS.md).

## Inhalt

- `get.sh` (alles in einem Schritt), `install.sh`, `update.sh`, `compose.yaml`, `config/`, `fail2ban/`: das Paket.
- `quellen/`: Dockerfile und unsere Patches für die Open-Source-Teile (Quelltext-Angebot).
- [NOTICE.md](NOTICE.md): Fremdkomponenten und Lizenzen. [CHANGELOG.md](CHANGELOG.md): Änderungen. [SECURITY.md](SECURITY.md): Sicherheit.

## Lizenz

- Eigene Teile (Skripte, Konfiguration, Texte, Verwaltungsoberfläche): kostenlos nutzbar, auch gewerblich für den eigenen Betrieb; nicht verkaufen, nicht als Dienst anbieten, nicht weitergeben, Name bleibt stehen. Siehe [LICENSE](LICENSE).
- Open-Source-Teile im Image: SRTLA-Empfänger AGPL-3.0, SRT-Bibliothek MPL-2.0, SRT-Server MIT. Quelltext unserer Änderungen im Ordner `quellen/` ([Lizenz](quellen/LICENSE.md)), Einzelheiten in [NOTICE.md](NOTICE.md).
- Die Verwaltungsoberfläche im Image ist nicht quelloffen. Sie darf zusammen mit diesem Image kostenlos genutzt werden.

Kein Anspruch auf Gewährleistung.

## Hilfe, Wünsche und Anregungen

Fehler, Wünsche und Anregungen bitte hier melden: [GitHub Issues](https://github.com/IRL4YOU/srtla-receiver/issues). Fragen und Austausch im Discord: https://discord.gg/7AQRAQAp4C
(Sicherheitslücken nicht öffentlich melden, siehe [SECURITY.md](SECURITY.md).)
