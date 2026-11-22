# IRL4YOU SRTLA Receiver: Installation

Du brauchst einen Linux-Server (Ubuntu oder Debian) mit Docker und Docker Compose, SSH-Zugang mit `sudo` und für HTTPS eine Domain, die auf den Server zeigt.

## Schnellstart: ein Befehl

Aktualisiert das System, richtet Git und Docker ein, holt das Paket und installiert alles. Als normaler Benutzer mit `sudo` ausführen.

Mit eigener Domain (HTTPS) und SSH nur mit Schlüssel:

```bash
wget -qO get.sh https://raw.githubusercontent.com/IRL4YOU/srtla-receiver/main/get.sh && bash get.sh --caddy meine.domain.de --ssh-haerten
```

Ohne Domain (Verwaltung im eigenen Netz über IP und Port):

```bash
wget -qO get.sh https://raw.githubusercontent.com/IRL4YOU/srtla-receiver/main/get.sh && bash get.sh
```

Während der Installation läuft nur ein Fortschrittsbalken. Das Skript fragt einmal, **wo der Server steht**: **1** (oder Enter) für Zuhause/eigenes Netz, **2** für Rechenzentrum/Internet. Bei 2 gibst du deine Domain ein oder drückst Enter für eine automatische Adresse aus der IP (sslip.io); Caddy richtet dann HTTPS mit Let's Encrypt ein. Am Ende zeigt das Skript in einer Zusammenfassung die **Adresse der Verwaltung**, den **Einmalcode**, die Sendeadressen und die freizugebenden Ports. Das Paket liegt danach in `~/srtla-receiver` (dort später auch `bash update.sh`). Weiter mit Schritt 3. Wer es lieber von Hand macht, nimmt die Schritte 0 bis 2.

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

Ohne Domain (Verwaltung im eigenen Netz über IP und Port):

```bash
bash install.sh
```

Das Skript lädt das Image, startet den Empfänger, richtet `fail2ban` ein und zeigt am Ende den **Einmalcode**.

## 3. Verwaltung einrichten

1. Die Adresse aus der Zusammenfassung öffnen (`https://meine.domain.de/schluessel` oder ohne Domain `http://<IP>:8181/schluessel`). Ohne Domain ist die Verbindung unverschlüsselt: nur im eigenen Netz verwenden. Im Rechenzentrum immer mit Domain installieren.

2. Einmalcode eingeben und ein Administrator-Passwort setzen (mindestens 12 Zeichen).
3. Benutzer und Stream anlegen. Die Verwaltung zeigt dann Adressen und Schlüssel zum Kopieren.

## 4. Ports freigeben (Router und Firewall)

| Port | Protokoll | Wofür | Wann |
|---|---|---|---|
| `22` | TCP | SSH | nur wenn du von außen auf den Server willst |
| `80` | TCP | Zertifikat (Let's Encrypt) | nur mit Domain |
| `443` | TCP | Verwaltung, Statistik und NOALBS per HTTPS | nur mit Domain |
| `8181` | TCP | Verwaltung, Statistik und NOALBS direkt | nur im eigenen Netz, ohne Domain |
| `8282` | UDP | OBS holt den Stream ab (geschützt durch den OBS-Schlüssel) | immer |
| `8383` | UDP | Senden per SRTLA (App, Handy, Box) | immer |
| `8384` | UDP | Senden per reinem SRT | immer |

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
