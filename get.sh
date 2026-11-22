#!/bin/bash
# IRL4YOU SRTLA Receiver: alles in einem Schritt (Ubuntu/Debian).
# System aktualisieren, Git und Docker einrichten, Paket holen, installieren. Angezeigt wird nur ein Fortschrittsbalken.
# Aufruf als normaler Benutzer mit sudo-Recht:
#   wget -qO get.sh https://raw.githubusercontent.com/IRL4YOU/srtla-receiver/main/get.sh && bash get.sh [--caddy DOMAIN] [--ssh-haerten] [--ja] [--ausfuehrlich]
# Alle Optionen werden an install.sh weitergegeben (siehe DETAILS.md). Ohne --caddy gibt es HTTPS ueber die IP (selbst signiertes Zertifikat).
set -u

REPO="https://github.com/IRL4YOU/srtla-receiver.git"
ZIEL="$HOME/srtla-receiver"
LOG="/tmp/irl4you-get-$(date +%Y%m%d-%H%M%S).log"
VERBOSE=0; for a in "$@"; do [ "$a" = "--ausfuehrlich" ] && VERBOSE=1; done
TOTAL=9; STEP=0

exec 3>&1
if [ -t 3 ]; then C_C=$'\033[1;36m'; C_R=$'\033[1;31m'; C_0=$'\033[0m'; else C_C=""; C_R=""; C_0=""; fi
stage() {
  STEP=$((STEP+1))
  if [ "$VERBOSE" -eq 1 ]; then printf '== %s\n' "$1" >&3; return; fi
  local w=30 f=$((STEP*30/TOTAL)) p=$((STEP*100/TOTAL)) fill rest
  fill=$(printf '%*s' "$f" '' | tr ' ' '#'); rest=$(printf '%*s' "$((w-f))" '' | tr ' ' '-')
  printf '\r%s[%s%s]%s %3d%%  %-44s\033[K' "$C_C" "$fill" "$rest" "$C_0" "$p" "$1" >&3
}
bei_ende() {
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '\n\n%sFEHLER (Code %s).%s Die letzten Meldungen:\n' "$C_R" "$rc" "$C_0" >&3
    [ "$VERBOSE" -eq 0 ] && { tail -n 15 "$LOG" >&3; printf 'Vollstaendiges Protokoll: %s\n' "$LOG" >&3; }
  fi
}
trap bei_ende EXIT

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
  printf '%sHinweis: Du bist als root angemeldet. Das funktioniert; das Paket liegt dann in %s. Ueblicher ist ein normaler Benutzer mit sudo.%s\n' "$C_C" "$ZIEL" "$C_0" >&3
else SUDO="sudo"; fi
command -v apt-get >/dev/null 2>&1 || { echo "Nur Ubuntu/Debian (apt) wird unterstuetzt." >&3; exit 1; }
if [ -n "$SUDO" ] && ! command -v sudo >/dev/null 2>&1; then echo "sudo fehlt. Als root starten oder sudo installieren." >&3; exit 1; fi
# Passwortabfrage fuer sudo gleich zu Beginn, solange die Ausgabe noch sichtbar ist
if [ -n "$SUDO" ]; then $SUDO -v || exit 1; fi

[ "$VERBOSE" -eq 0 ] && exec >"$LOG" 2>&1
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
APT="$SUDO env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y -o Dpkg::Options::=--force-confold"

stage "System aktualisieren (dauert etwas)"
$APT update || exit 1
$APT upgrade || exit 1
$APT install git curl ca-certificates || exit 1

stage "Docker pruefen"
compose_da() { docker compose version >/dev/null 2>&1 || $SUDO docker compose version >/dev/null 2>&1; }
if ! command -v docker >/dev/null 2>&1 || ! compose_da; then
  curl -fsSL https://get.docker.com | $SUDO sh || exit 1
fi

stage "Paket holen"
if [ -d "$ZIEL/.git" ]; then git -C "$ZIEL" pull --ff-only || exit 1; else git clone "$REPO" "$ZIEL" || exit 1; fi

cd "$ZIEL" || exit 1
IRL4YOU_BAR_TOTAL=$TOTAL IRL4YOU_BAR_OFFSET=$STEP bash install.sh "$@" >&3 2>&3
rc=$?
if [ -f /var/run/reboot-required ]; then
  printf '\nHinweis: Das System meldet, dass nach dem Update ein Neustart noetig ist. Bei Gelegenheit: sudo reboot\n' >&3
fi
exit $rc
