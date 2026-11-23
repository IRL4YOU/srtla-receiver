# Änderungen

## 1.0.1

- Oberfläche zweisprachig: Deutsch und English, Umschalter DE | EN oben in der Leiste (gemerkt im Browser, Standard: Browsersprache).
- Installation und Update fragen zu Beginn nach der Sprache (Deutsch oder English) und zeigen alle Meldungen in dieser Sprache. Auch per Option: `--de` oder `--en`.
- Update-Befehl mit Aktualisieren der Skripte: `cd ~/srtla-receiver && git pull && bash update.sh`.

## 1.0.0

Erste öffentliche Version.

- Empfänger für SRTLA (gebündeltes Mobilfunk-Streaming) und reines SRT, Weitergabe an OBS, Statistik auch für NOALBS.
- Verwaltung im Browser mit Benutzern, Streams und je Stream drei getrennten Schlüsseln (Senden, OBS, Statistik).
- Stabilere Übertragung bei wechselndem Mobilfunk durch verbesserte Behandlung von Bestätigungen und Nachforderungen verlorener Pakete.
- Basissystem, Webserver, SRT-Bibliothek und SRTLA-Empfänger auf dem aktuellen Stand.
- Sicherheit: Zugangsdaten nur als Hash, Schlüssel getrennt vom Datenvolumen, Anmeldesperre, `fail2ban` für SSH und Weboberfläche mit Wochensperre.
- Automatische Sicherungen, Sicherheitsprotokoll ohne IP-Adressen, Versionsanzeige und Update-Hinweis.
- Installation und Update mit je einem Befehl, Updates können Versionen überspringen.
