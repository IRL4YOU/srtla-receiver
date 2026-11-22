# IRL4YOU SRTLA Receiver: Installation

Du brauchst einen Linux-Server (Ubuntu oder Debian) mit Docker und Docker Compose, SSH-Zugang mit `sudo` und für HTTPS eine Domain, die auf den Server zeigt.

## Schnellstart: ein Befehl

Aktualisiert das System, richtet Git und Docker ein, holt das Paket und installiert alles. Als normaler Benutzer mit `sudo` ausführen.

Mit Domain (HTTPS) und SSH nur mit Schlüssel:

```bash
wget -qO get.sh https://raw.githubusercontent.com/IRL4YOU/srtla-receiver/main/get.sh && bash get.sh --caddy meine.domain.de --ssh-haerten
```

Ohne Domain (Zugriff per SSH-Tunnel):

```bash
wget -qO get.sh https://raw.githubusercontent.com/IRL4YOU/srtla-receiver/main/get.sh && bash get.sh
```

Am Ende zeigt das Skript den **Einmalcode**. Das Paket liegt danach in `~/srtla-receiver` (dort später auch `bash update.sh`). Weiter mit Schritt 3. Wer es lieber von Hand macht, nimmt die Schritte 0 bis 2.

## 0. Frischer Server: Git und Docker installieren

Nur nötig, wenn beides noch fehlt:

```bash
sudo apt update && sudo apt install -y git curl
```

```bash
curl -fsSL https://get.docker.com | sudo sh
```

## 1. Paket holen

```bash
git clone https://github.com/IRL4YOU/srtla-receiver.git
```

```bash
cd srtla-receiver
```

## 2. Installieren

Mit Domain (HTTPS) und SSH nur mit Schlüssel:

```bash
bash install.sh --caddy meine.domain.de --ssh-haerten
```

Ohne Domain (Zugriff per SSH-Tunnel):

```bash
bash install.sh
```

Das Skript lädt das Image, startet den Empfänger, richtet `fail2ban` ein und zeigt am Ende den **Einmalcode**.

## 3. Verwaltung einrichten

1. `https://meine.domain.de/schluessel` öffnen. Ohne Domain zuerst den Tunnel starten und dann `http://localhost:8181/schluessel` öffnen:

   ```bash
   ssh -L 8181:127.0.0.1:8181 benutzer@server
   ```

2. Einmalcode eingeben und ein Administrator-Passwort setzen (mindestens 12 Zeichen).
3. Benutzer und Stream anlegen. Die Verwaltung zeigt dann Adressen und Schlüssel zum Kopieren.

## 4. Ports freigeben (Router und Firewall)

| Port | Wofür |
|---|---|
| `8383/udp` | Senden per SRTLA (App, Handy, Box) |
| `8384/udp` | Senden per reinem SRT |
| `443/tcp`, `80/tcp` | Verwaltung, Statistik und NOALBS per HTTPS (nur mit Domain) |
| `22/tcp` | SSH, nur wenn du von außen auf den Server willst |
| `8282/udp` | OBS von außen, nur wenn OBS nicht im selben Netz läuft |

## 5. Update

```bash
bash update.sh
```

Das Skript sichert die Daten, holt die neueste Version und wechselt. Geht etwas schief, kehrt es von selbst zurück. Von Hand zurück:

```bash
bash update.sh --rueckweg
```

Zugänge, Schlüssel und Streams bleiben erhalten. Neue Versionen zeigt die Verwaltung unter **Updates und Hilfe** an, dort stehen auch die Links zum Melden von Fehlern und Wünschen.

## 6. Sicherung

In der Verwaltung unter **Sicherheit und Sicherungen** gibt es automatische Sicherungen und den Knopf **Sicherung herunterladen** (mit eigenem Passwort). Lade nach größeren Änderungen eine herunter und bewahre sie außerhalb des Servers auf. Wiederherstellen: neu installieren, Administrator anlegen, Sicherung einspielen. Den Ordner `secrets/` zusammen mit der Sicherung aufbewahren, nicht weitergeben.

## Hilfe, Wünsche und Anregungen

Fehler, Wünsche und Anregungen: [GitHub Issues](https://github.com/IRL4YOU/srtla-receiver/issues). Fragen und Austausch: Discord https://discord.gg/7AQRAQAp4C. Alle Optionen und Hintergründe stehen in `DETAILS.md`.
