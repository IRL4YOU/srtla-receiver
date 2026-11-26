#!/bin/bash
# IRL4YOU SRTLA Receiver: alles in einem Schritt (Ubuntu/Debian).
# System aktualisieren, Git und Docker einrichten, Paket holen, installieren. Angezeigt wird nur ein Fortschrittsbalken.
# Sprache: --de / --en (sonst Rueckfrage am Terminal); wird an install.sh weitergegeben.
# Aufruf als normaler Benutzer mit sudo-Recht:
#   wget -qO get.sh https://raw.githubusercontent.com/IRL4YOU/srtla-receiver/main/get.sh && bash get.sh [--caddy DOMAIN] [--ssh-haerten] [--ja] [--ausfuehrlich]
# Alle Optionen werden an install.sh weitergegeben (siehe DETAILS.md). Ohne --caddy gibt es HTTPS ueber die IP (selbst signiertes Zertifikat).
set -u
L=""
t() { if [ "$L" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

REPO="https://github.com/IRL4YOU/srtla-receiver.git"
ZIEL="$HOME/srtla-receiver"
LOG="/tmp/irl4you-get-$(date +%Y%m%d-%H%M%S).log"
VERBOSE=0; JA=0; for a in "$@"; do
  case "$a" in --ausfuehrlich) VERBOSE=1 ;; --ja) JA=1 ;; --de) L=de ;; --en) L=en ;; esac
done
TOTAL=9; STEP=0

exec 3>&1
if [ -t 3 ]; then C_C=$'\033[1;36m'; C_R=$'\033[1;31m'; C_Y=$'\033[1;33m'; C_0=$'\033[0m'; else C_C=""; C_R=""; C_Y=""; C_0=""; fi
# Sprache waehlen (ohne Angabe: Rueckfrage am Terminal, sonst Systemsprache)
if [ -z "$L" ]; then
  case "${LC_ALL:-${LANG:-}}" in en*) L=en ;; *) L=de ;; esac
  if [ "$JA" -eq 0 ] && [ -t 0 ]; then
    printf '\n%sSprache / Language:%s\n   1) Deutsch\n   2) English\n%sAuswahl / Choice (Enter = 1):%s ' "$C_Y" "$C_0" "$C_Y" "$C_0" >&3
    read -r SP
    case "$(printf '%s' "$SP" | tr -d ' \r')" in 2) L=en ;; *) L=de ;; esac
  fi
fi
export IRL4YOU_LANG="$L"
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
    printf "$(t '\n\n%sFEHLER (Code %s).%s Die letzten Meldungen:\n' '\n\n%sERROR (code %s).%s The last messages:\n')" "$C_R" "$rc" "$C_0" >&3
    [ "$VERBOSE" -eq 0 ] && { tail -n 15 "$LOG" >&3; printf "$(t 'Vollstaendiges Protokoll: %s\n' 'Full log: %s\n')" "$LOG" >&3; }
  fi
}
trap bei_ende EXIT

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
  printf "$(t '%sHinweis: Du bist als root angemeldet. Das funktioniert; das Paket liegt dann in %s. Ueblicher ist ein normaler Benutzer mit sudo.%s\n' '%sNote: you are logged in as root. That works; the package will be in %s. A normal user with sudo is more usual.%s\n')" "$C_C" "$ZIEL" "$C_0" >&3
else SUDO="sudo"; fi
command -v apt-get >/dev/null 2>&1 || { echo "$(t 'Nur Ubuntu/Debian (apt) wird unterstuetzt.' 'Only Ubuntu/Debian (apt) is supported.')" >&3; exit 1; }
if [ -n "$SUDO" ] && ! command -v sudo >/dev/null 2>&1; then echo "$(t 'sudo fehlt. Als root starten oder sudo installieren.' 'sudo is missing. Run as root or install sudo.')" >&3; exit 1; fi
# Passwortabfrage fuer sudo gleich zu Beginn, solange die Ausgabe noch sichtbar ist
if [ -n "$SUDO" ]; then $SUDO -n true 2>/dev/null || $SUDO -v || exit 1; fi

[ "$VERBOSE" -eq 0 ] && exec >"$LOG" 2>&1
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
APT="$SUDO env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y -o Dpkg::Options::=--force-confold"

stage "$(t 'System aktualisieren (dauert etwas)' 'Updating the system (takes a while)')"
$APT update || exit 1
$APT upgrade || exit 1
$APT install git curl ca-certificates || exit 1

stage "$(t 'Docker pruefen' 'Checking Docker')"
compose_da() { docker compose version >/dev/null 2>&1 || $SUDO docker compose version >/dev/null 2>&1; }
if ! command -v docker >/dev/null 2>&1 || ! compose_da; then
  curl -fsSL https://get.docker.com | $SUDO sh || exit 1
fi

stage "$(t 'Paket holen' 'Fetching the package')"
if [ -d "$ZIEL/.git" ]; then git -C "$ZIEL" pull --ff-only || exit 1; else git clone "$REPO" "$ZIEL" || exit 1; fi

cd "$ZIEL" || exit 1
IRL4YOU_BAR_TOTAL=$TOTAL IRL4YOU_BAR_OFFSET=$STEP bash install.sh "$@" >&3 2>&3
rc=$?
if [ -f /var/run/reboot-required ]; then
  printf "$(t '\nHinweis: Das System meldet, dass nach dem Update ein Neustart noetig ist. Bei Gelegenheit: sudo reboot\n' '\nNote: the system reports that a restart is needed after the update. When convenient: sudo reboot\n')" >&3
fi
exit $rc
