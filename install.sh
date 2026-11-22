#!/bin/bash
# IRL4YOU SRTLA-Empfaenger: Erstinstallation (Komplettpaket). Das Image kommt von Docker Hub oder aus einer Datei srtla-*.tar.gz im Ordner.
# Aufruf im Paketordner:   bash install.sh [--caddy DOMAIN] [--ssh-haerten] [--ja] [--ohne-fail2ban]
#
#   Immer:    Schluesseldatei anlegen (getrennt von den Daten), Image laden, Empfaenger starten, Einmalcode zeigen.
#   fail2ban: wird mit installiert (SSH und Weboberflaeche). Mit --ohne-fail2ban ueberspringen (nicht empfohlen).
#   --caddy DOMAIN   HTTPS fuer die Verwaltung (Caddy mit automatischem Zertifikat). DOMAIN zeigt auf diesen Server.
#   --ssh-haerten    SSH nur noch mit Schluessel (Passwort-Anmeldung aus). Nur wenn ein Schluessel hinterlegt ist.
#   --ja             Rueckfragen automatisch mit Ja beantworten.
#   --nur-schutz     nur fail2ban/SSH/Caddy einrichten (der Empfaenger laeuft schon, z. B. bei bestehenden Servern)
#   Umgebung: IRL4YOU_IGNORE_NETS="192.168.1.0/24" (eigene Netze/Adressen, die nie gesperrt werden; empfohlen: das Heimnetz),
#             IRL4YOU_IGNORE_SSH_CLIENT=1 (Adresse der aktuellen SSH-Sitzung nie sperren; 0 nur fuer Tests),
#             IRL4YOU_BANTIME=1h (Sperrzeit), IRL4YOU_WEB_PORTS=8181 (Ports der Verwaltung, fuer die Sperre in DOCKER-USER)
set -u
cd "$(dirname "$0")" || exit 1

CADDY_DOMAIN=""; SSH_HAERTEN=0; JA=0; F2B=1; NUR_SCHUTZ=0
while [ $# -gt 0 ]; do
  case "$1" in
    --caddy) CADDY_DOMAIN="${2:-}"; shift 2 ;;
    --ssh-haerten) SSH_HAERTEN=1; shift ;;
    --ja) JA=1; shift ;;
    --ohne-fail2ban) F2B=0; shift ;;
    --nur-schutz) NUR_SCHUTZ=1; shift ;;
    *) echo "Unbekannte Option: $1"; exit 1 ;;
  esac
done

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
if docker info >/dev/null 2>&1; then D="docker"; else D="$SUDO docker"; fi
frage() { [ "$JA" -eq 1 ] && return 0; printf '%s [j/N] ' "$1"; read -r a; [ "$a" = j ] || [ "$a" = J ] || [ "$a" = ja ]; }
ok() { printf '   OK: %s\n' "$1"; }

if [ "$NUR_SCHUTZ" -eq 0 ]; then
echo "== 0. Voraussetzungen"
command -v docker >/dev/null 2>&1 || { echo "ABBRUCH: Docker fehlt. Installation siehe https://docs.docker.com/engine/install/ (danach dieses Skript erneut starten)."; exit 1; }
$D compose version >/dev/null 2>&1 || { echo "ABBRUCH: Docker Compose fehlt (Paket docker-compose-plugin)."; exit 1; }
[ -n "$SUDO" ] && ! sudo -n true 2>/dev/null && echo "   Hinweis: fuer einzelne Schritte wird gleich das sudo-Passwort abgefragt."
[ -f compose.yaml ] || { echo "ABBRUCH: compose.yaml fehlt (Skript im Paketordner ausfuehren)."; exit 1; }
if $D compose ps -q receiver 2>/dev/null | grep -q .; then echo "ABBRUCH: Der Empfaenger laeuft schon. Fuer Updates: bash update.sh"; exit 1; fi

echo "== 1. Schluesseldatei (getrennt vom Datenvolumen)"
# Der Container-Benutzer hat die Nummer 101. Nur er darf die Datei lesen; auf dem Server braucht man dafuer sudo.
IMG=$(ls -1 srtla-*.tar.gz 2>/dev/null | sort -V | tail -1)
if [ -n "$IMG" ]; then
  # Image aus einer mitgelieferten Datei (ohne Internet)
  if [ -f "$IMG.sha256" ]; then
    if command -v sha256sum >/dev/null 2>&1; then sha256sum -c "$IMG.sha256" || exit 1; else shasum -a 256 -c "$IMG.sha256" || exit 1; fi
  fi
  $D load -i "$IMG" | tail -1
else
  REF=$(awk '/^[[:space:]]*image:/{print $2; exit}' compose.yaml)
  echo "   Image $REF wird heruntergeladen ..."
  $D pull "$REF" >/dev/null 2>&1 || { echo "ABBRUCH: $REF konnte nicht heruntergeladen werden (Internetverbindung? Oder die Image-Datei srtla-*.tar.gz in diesen Ordner legen)."; exit 1; }
fi
mkdir -p secrets && chmod 700 secrets
if $SUDO test -s secrets/enc.key; then
  ok "secrets/enc.key ist schon vorhanden (wird nicht ueberschrieben)"
else
  od -An -N32 -tx1 /dev/urandom | tr -d ' \n' > secrets/enc.key
  $SUDO chown 101:102 secrets/enc.key && $SUDO chmod 400 secrets/enc.key
  ok "secrets/enc.key angelegt (nur der Container-Benutzer darf sie lesen)"
fi
$SUDO chmod 700 secrets 2>/dev/null; $SUDO chown 0:0 secrets 2>/dev/null || true
# secrets/ gehoert jetzt root; der Docker-Daemon (root) kann die Datei einbinden.

echo "== 2. Empfaenger starten"
$D compose up -d 2>&1 | tail -3
i=0; h=""
CID=$($D compose ps -q receiver | head -1)
while [ "$i" -lt 90 ]; do h=$($D inspect --format '{{.State.Health.Status}}' "$CID" 2>/dev/null); [ "$h" = healthy ] && break; i=$((i+1)); sleep 1; done
[ "$h" = healthy ] || { echo "FEHLER: Empfaenger wurde nicht gesund. Log: $D compose logs --tail 50"; exit 1; }
ok "Empfaenger laeuft (healthy)"
echo
$D compose logs receiver 2>&1 | grep -a ERSTEINRICHTUNG | tail -1
echo "   Verwaltung per SSH-Tunnel: ssh -L 8181:127.0.0.1:8181 BENUTZER@SERVER, dann http://localhost:8181/schluessel"
echo "   (oder mit HTTPS ueber --caddy DOMAIN, siehe unten)"
fi

if [ "$F2B" -eq 1 ]; then
  echo "== 3. fail2ban (Schutz fuer SSH und die Weboberflaeche)"
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban python3-systemd >/dev/null 2>&1 && ok "fail2ban installiert" || echo "   FEHLER bei der Installation von fail2ban (apt)."
    # Eigene Adresse der aktuellen SSH-Sitzung nicht aussperren
    MYIP=$(echo "${SSH_CLIENT:-}" | awk '{print $1}')
    IGN="127.0.0.1/8 ::1"; [ -n "$MYIP" ] && [ "${IRL4YOU_IGNORE_SSH_CLIENT:-1}" = 1 ] && IGN="$IGN $MYIP"
    [ -n "${IRL4YOU_IGNORE_NETS:-}" ] && IGN="$IGN $IRL4YOU_IGNORE_NETS"
    $SUDO mkdir -p /etc/fail2ban/filter.d /etc/fail2ban/jail.d
    $SUDO cp fail2ban/filter.d/irl4you-web.conf /etc/fail2ban/filter.d/irl4you-web.conf
    $SUDO cp fail2ban/filter.d/irl4you-recidive.conf /etc/fail2ban/filter.d/irl4you-recidive.conf
    $SUDO mkdir -p /etc/fail2ban/action.d /etc/irl4you
    $SUDO cp fail2ban/action.d/irl4you-event.conf /etc/fail2ban/action.d/irl4you-event.conf
    $SUDO install -m 755 fail2ban/irl4you-f2b-event /usr/local/sbin/irl4you-f2b-event
    # Ereignisdatei im Datenvolumen der Verwaltung (der Container liest sie): Pfad des Volumes ermitteln
    DATADIR="${IRL4YOU_DATA_DIR:-}"
    if [ -z "$DATADIR" ]; then
      CN=$($D compose ps -q receiver 2>/dev/null | head -1); [ -n "$CN" ] || CN=irl4you-srtla-receiver
      DATADIR=$($D inspect "$CN" --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' 2>/dev/null)
    fi
    if [ -n "$DATADIR" ] && $SUDO test -d "$DATADIR"; then
      echo "$DATADIR/fail2ban-events.log" | $SUDO tee /etc/irl4you/f2b-logfile >/dev/null
      ok "Sperren werden im Sicherheitsprotokoll der Verwaltung angezeigt (ohne Adressen)"
    else
      echo "   Hinweis: Datenvolumen nicht gefunden: Sperren erscheinen nicht in der Verwaltung (IRL4YOU_DATA_DIR=... setzen)."
    fi
    $SUDO mkdir -p /etc/fail2ban/fail2ban.d
    printf '[Definition]\n# Sperren sollen auch einen Neustart ueberleben (Wochensperre): Standard waere 1 Tag\ndbpurgeage = 8d\n' | $SUDO tee /etc/fail2ban/fail2ban.d/irl4you.local >/dev/null
    BT="${IRL4YOU_BANTIME:-1h}"; WEBPORTS="${IRL4YOU_WEB_PORTS:-8181}"
    $SUDO tee /etc/fail2ban/jail.d/irl4you.local >/dev/null <<EOF
[DEFAULT]
bantime = $BT
findtime = 10m
maxretry = 5
ignoreip = $IGN

[sshd]
enabled = true
backend = systemd
action = %(action_)s
         irl4you-event[name=%(__name__)s]

# Weboberflaeche hinter Caddy (Ports 80/443 gehoeren dem Rechner selbst: Kette INPUT)
[irl4you-web]
enabled = true
filter = irl4you-web
action = %(action_)s
         irl4you-event[name=%(__name__)s]
backend = polling
logpath = /var/lib/docker/containers/*/*-json.log
maxretry = 10
port = http,https
banaction = iptables-multiport

# Direkter Zugriff auf Port 8181 (von Docker veroeffentlicht: Kette DOCKER-USER)
[irl4you-web-docker]
enabled = true
filter = irl4you-web
action = %(action_)s
         irl4you-event[name=%(__name__)s]
backend = polling
logpath = /var/lib/docker/containers/*/*-json.log
maxretry = 10
port = $WEBPORTS
chain = DOCKER-USER
banaction = iptables-multiport

# Wiederholungstaeter: 10 Sperren (SSH oder Weboberflaeche) innerhalb von 7 Tagen: eine Woche gesperrt.
# Nur SSH, http und https; die Senderports (SRTLA/SRT) bleiben absichtlich frei: Mobilfunknetze teilen sich Adressen
# (CGNAT), ein Scanner aus demselben Netz soll nicht die eigene Sendeverbindung kappen.
[irl4you-recidive]
enabled = true
filter = irl4you-recidive
action = %(action_)s
         irl4you-event[name=%(__name__)s]
backend = polling
logpath = /var/log/fail2ban.log
maxretry = 10
findtime = 7d
bantime = 1w
port = ssh,http,https
banaction = iptables-multiport
EOF
    $SUDO systemctl enable --now fail2ban >/dev/null 2>&1; $SUDO systemctl restart fail2ban
    sleep 3
    $SUDO fail2ban-client status 2>/dev/null | sed -n '1,3p'
    [ -n "$MYIP" ] && ok "Ihre aktuelle Adresse $MYIP wird nicht gesperrt (ignoreip)"
  else
    echo "   Kein apt gefunden. fail2ban bitte von Hand einrichten: fail2ban/filter.d/irl4you-web.conf und die Jails aus install.sh uebernehmen."
  fi
fi

if [ "$SSH_HAERTEN" -eq 1 ]; then
  echo "== 4. SSH nur mit Schluessel"
  KEYS=0; for f in "$HOME/.ssh/authorized_keys"; do [ -s "$f" ] && KEYS=1; done
  if [ "$KEYS" -ne 1 ]; then
    echo "   NICHT geaendert: in $HOME/.ssh/authorized_keys ist kein Schluessel hinterlegt. Sonst wuerden Sie sich aussperren."
  elif frage "   Passwort-Anmeldung per SSH abschalten? Sie melden sich danach nur noch mit Ihrem Schluessel an."; then
    $SUDO mkdir -p /etc/ssh/sshd_config.d
    printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\n' | $SUDO tee /etc/ssh/sshd_config.d/10-irl4you.conf >/dev/null
    if $SUDO sshd -t 2>/dev/null; then $SUDO systemctl reload ssh 2>/dev/null || $SUDO systemctl reload sshd 2>/dev/null; ok "SSH nur noch mit Schluessel (bestehende Sitzung bleibt offen: bitte in einem zweiten Fenster neu anmelden und pruefen)"; else $SUDO rm -f /etc/ssh/sshd_config.d/10-irl4you.conf; echo "   Konfigurationsfehler, nichts geaendert."; fi
  fi
fi

if [ -n "$CADDY_DOMAIN" ]; then
  echo "== 5. HTTPS mit Caddy fuer $CADDY_DOMAIN"
  command -v caddy >/dev/null 2>&1 || $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y caddy >/dev/null 2>&1
  if command -v caddy >/dev/null 2>&1; then
    printf '%s {\n    reverse_proxy 127.0.0.1:8181\n}\n' "$CADDY_DOMAIN" | $SUDO tee /etc/caddy/Caddyfile >/dev/null
    $SUDO systemctl enable --now caddy >/dev/null 2>&1; $SUDO systemctl reload caddy 2>/dev/null || $SUDO systemctl restart caddy
    ok "Caddy eingerichtet. Ports 80 und 443 muessen von aussen erreichbar sein (Firewall/Router). Verwaltung: https://$CADDY_DOMAIN/schluessel"
  else
    echo "   Caddy konnte nicht installiert werden (apt). Anleitung: https://caddyserver.com/docs/install"
  fi
fi

echo
echo "FERTIG. Wichtig:"
echo " - Den Ordner secrets/ zusammen mit Ihrer Sicherung aufbewahren, aber nicht weitergeben."
echo " - Ports, die im Router (Portweiterleitung) und in der Firewall des Servers freigegeben werden muessen:"
echo "     22/tcp     SSH (Verwaltung des Servers aus der Ferne)   nur wenn Sie von aussen auf den Server wollen; dann mit fail2ban und nur mit Schluessel (--ssh-haerten)"
echo "     8383/udp   SRTLA-Senden (App/Handy und auch die Box)      immer"
echo "     8384/udp   reines SRT-Senden (gleiche Stream-ID)     immer"
if [ -n "$CADDY_DOMAIN" ]; then
echo "     443/tcp    Weboberflaeche per HTTPS, Statistikseite und NOALBS-Adresse   (mit --caddy: noetig)"
echo "     80/tcp     nur fuer das automatische Zertifikat (Let's Encrypt)          (mit --caddy: noetig)"
else
echo "     443/tcp + 80/tcp   Weboberflaeche per HTTPS, Statistikseite und NOALBS-Adresse: nur mit --caddy DOMAIN (empfohlen)"
echo "     8181/tcp   Weboberflaeche DIREKT, unverschluesselt: nur im eigenen Netz oder per SSH-Tunnel, nicht ins Internet"
fi
echo "     8282/udp   OBS-Wiedergabe von aussen: nur wenn OBS NICHT im selben Netz laeuft (in compose.yaml das 127.0.0.1: bei 8282 entfernen)"
echo " - NOALBS: braucht nur die Statistik-Adresse https://DOMAIN/stats/<Statistikschluessel> (Zugriff auf 443). Laeuft NOALBS im selben Netz,"
echo "   reicht auch http://SERVER:8181/stats/<Statistikschluessel> im LAN. Den Statistikschluessel zeigt die Verwaltung beim Stream."
echo " - Updates spaeter: bash update.sh"
