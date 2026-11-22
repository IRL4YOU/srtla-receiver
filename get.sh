#!/bin/bash
# IRL4YOU SRTLA Receiver: alles in einem Schritt (Ubuntu/Debian).
# System aktualisieren, Git und Docker einrichten, Paket holen, installieren.
# Aufruf als normaler Benutzer mit sudo-Recht:
#   wget -qO get.sh https://raw.githubusercontent.com/IRL4YOU/srtla-receiver/main/get.sh && bash get.sh [--caddy DOMAIN] [--ssh-haerten] [--ja]
# Alle Optionen werden an install.sh weitergegeben (siehe DETAILS.md).
set -eu

REPO="https://github.com/IRL4YOU/srtla-receiver.git"
ZIEL="$HOME/srtla-receiver"

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
command -v apt-get >/dev/null 2>&1 || { echo "ABBRUCH: Nur Ubuntu/Debian (apt) wird unterstuetzt."; exit 1; }
if [ -n "$SUDO" ] && ! command -v sudo >/dev/null 2>&1; then echo "ABBRUCH: sudo fehlt. Als root starten oder sudo installieren."; exit 1; fi

echo "1/4 System aktualisieren"
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get update -y
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y git curl ca-certificates

echo "2/4 Docker pruefen"
compose_da() { docker compose version >/dev/null 2>&1 || $SUDO docker compose version >/dev/null 2>&1; }
if ! command -v docker >/dev/null 2>&1 || ! compose_da; then
  curl -fsSL https://get.docker.com | $SUDO sh
fi

echo "3/4 Paket holen"
if [ -d "$ZIEL/.git" ]; then git -C "$ZIEL" pull --ff-only; else git clone "$REPO" "$ZIEL"; fi

echo "4/4 Installieren"
cd "$ZIEL"
bash install.sh "$@"

if [ -f /var/run/reboot-required ]; then
  echo
  echo "Hinweis: Das System meldet, dass ein Neustart noetig ist (nach dem Update). Bitte bei Gelegenheit: sudo reboot"
fi
