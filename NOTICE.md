# NOTICE: Fremdkomponenten, Lizenzen und Quelltext

IRL4YOU SRTLA Receiver besteht aus eigenen Teilen und aus Open-Source-Komponenten anderer Projekte. Wir danken den Autoren.

## Enthaltene Komponenten

| Komponente | Quelle (fester Stand) | Lizenz | Unsere Aenderungen |
|---|---|---|---|
| SRTLA-Empfaenger `srtla_rec` | github.com/IRLServer/srtla, Commit `877dc16e36d3fef421f9cffd345b54a526020732` | **AGPL-3.0** | `irlserver-srtla-broadcast-dropreq`, `irlserver-srtla-ack-weighting`, `irlserver-srtla-auth-throttle` |
| SRT-Bibliothek (libsrt 1.5.7, Fork) | github.com/CERALIVE/srt, Commit `d487b13365205b6cd5da9d9b50868c323e255b7c` (Ursprung: Haivision SRT) | **MPL-2.0** | `libsrt-allow-empty-ctrl`, `libsrt-periodic-nak-filter` |
| SRT-Server `srt_server` | github.com/IRLServer/irl-srt-server, Commit `a86dd8abd3659baea8ca8315bb4842410d4bc292` | **MIT** | `irl-srt-server-listen-callback-order`, `-frame-stats`, `-reorder-stats`, `-srtla-reorder-window` |
| spdlog (im SRTLA-Empfaenger) | Commit `4a5fdcb0b16f54139f3cd77d59660298e63ed58c` | MIT | keine |
| nginx, njs, Alpine Linux, tini | Pakete der Alpine-Distribution | jeweils eigene Lizenzen | keine |

Die vollstaendigen Lizenztexte liegen im Image unter `/usr/share/licenses/irl4you/`.

Die Verwaltungsoberflaeche (Schluesselverwaltung, Benutzer, Sicherungen, Sicherheitsprotokoll, Weboberflaeche) ist ein eigenes Programm, das ueber
Web-Schnittstellen mit dem Empfaenger spricht. Sie ist nicht quelloffen und darf zusammen mit diesem Image kostenlos genutzt werden, nach der Nutzungslizenz in `LICENSE` (kein Verkauf, kein Angebot als Dienst, keine Weitergabe, Name bleibt erhalten).

## Quelltext (Angebot nach AGPL-3.0 und MPL-2.0)

Den Quelltext der geaenderten Komponenten erhalten Sie so:
1. Die unveraenderten Originale sind oben mit dem festen Commit genannt (sie sind bei den jeweiligen Projekten abrufbar).
2. Unsere Aenderungen daran sind als Patch-Dateien (`quellen/patches/*.patch`, siehe Spalte "Unsere Aenderungen") zusammen mit dem Bauplan (`Dockerfile`)
   im Ordner `quellen/` des Repositorys unter der im Programm angezeigten Adresse ("Quelltext und Lizenzen" am Seitenende) abrufbar.
3. Das Dockerfile im Ordner `quellen/` baut aus den Originalen (fester Commit) und den Patches die geaenderten Programme `srtla_rec`, `libsrt` und `srt_server`
   und fuehrt deren eingebaute Tests aus.

Auf Anfrage senden wir die Patches und das Dockerfile auch direkt zu.
