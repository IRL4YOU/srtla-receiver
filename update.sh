#!/bin/bash
# IRL4YOU SRTLA-Empfaenger: Update auf die Version in diesem Ordner.
# Aufruf im Paketordner (dort, wo compose.yaml liegt):   bash update.sh [image-datei.tar.gz]
#
# Was passiert:
#   1. Pruefsumme der Image-Datei kontrollieren
#   2. Datensicherung des Daten-Volumes (Benutzer, Streams, Schluessel) nach ./sicherung/
#   3. Neues Image laden, compose.yaml auf das neue Image umstellen (Kopie: compose.yaml.vor-update)
#   4. Container ersetzen und auf "healthy" warten
#   5. Daten vor/nach vergleichen
# Wird der neue Container nicht gesund, geht das Skript von selbst auf den alten Stand zurueck.
# Die Daten bleiben immer im Volume: Zugaenge, Schluessel und Streams muessen NICHT neu eingegeben werden.
# Aeltere Installationen (Schluessel zur Verschluesselung noch im Datenvolumen) werden dabei automatisch umgestellt:
# Die Schluesseldatei wandert aus dem Volumen nach ./secrets/ und wird als Docker-Secret eingebunden.
# Rueckweg von Hand: bash update.sh --rueckweg
set -u
cd "$(dirname "$0")" || exit 1

# Sprache: --de / --en (sonst Rueckfrage am Terminal, Enter = Deutsch; ohne Terminal: Systemsprache). Der Rest der Argumente bleibt wie gehabt.
L="${IRL4YOU_LANG:-}"; ARGS=()
for a in "$@"; do case "$a" in --de) L=de ;; --en) L=en ;; *) ARGS+=("$a") ;; esac; done
set -- ${ARGS[@]+"${ARGS[@]}"}
t() { if [ "$L" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
if [ -z "$L" ]; then
  case "${LC_ALL:-${LANG:-}}" in en*) L=en ;; *) L=de ;; esac
  if [ "${1:-}" != "--rueckweg" ] && [ -t 0 ] && [ -t 1 ]; then
    printf '\nSprache / Language:\n   1) Deutsch\n   2) English\nAuswahl / Choice (Enter = 1): '
    read -r SP
    case "$(printf '%s' "$SP" | tr -d ' \r')" in 2) L=en ;; *) L=de ;; esac
  fi
fi
export IRL4YOU_LANG="$L"

SERVICE=receiver
if docker info >/dev/null 2>&1; then D="docker"; else D="sudo docker"; fi

container_id() { $D compose ps -q "$SERVICE" 2>/dev/null | head -1; }
volume_name() {
  $D inspect "$1" --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}' 2>/dev/null
}
# Hilfs-Container: das laufende Empfaenger-Image selbst (immer lokal vorhanden, kein Download noetig)
HELFER=""
volume_summe() {
  $D run --rm --user 0 --entrypoint sh -v "$1":/data:ro "$HELFER" -c 'cd /data && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum' 2>/dev/null | cut -d' ' -f1
}
warte_gesund() {
  local i=0 h=""
  while [ "$i" -lt 90 ]; do
    cid=$(container_id)
    h=$($D inspect --format '{{.State.Health.Status}}' "$cid" 2>/dev/null)
    [ "$h" = healthy ] && return 0
    i=$((i+1)); sleep 1
  done
  return 1
}

rueckweg() {
  if [ -f compose.yaml.vor-update ]; then
    echo "$(t '>> Rueckweg: alte compose.yaml wiederherstellen und Container neu starten' '>> Rollback: restoring the old compose.yaml and restarting the container')"
    # Der alte Stand erwartet die Schluesseldatei im Volumen: aus secrets/ zurueckkopieren, falls sie dort fehlt
    local cid vol img
    cid=$(container_id); vol=$(volume_name "$cid"); img=$($D inspect "$cid" --format '{{.Config.Image}}' 2>/dev/null)
    if [ -n "$vol" ] && [ -n "$img" ] && [ -d secrets ]; then
      $D run --rm --user 0 --entrypoint sh -v "$vol":/data -v "$PWD/secrets":/s:ro "$img" -c 'test -s /s/enc.key && ! test -e /data/enc.key && cp /s/enc.key /data/enc.key && chown 101:102 /data/enc.key && chmod 600 /data/enc.key && echo "   Schluesseldatei ins Volumen zurueckgelegt"' 2>/dev/null
    fi
    cp compose.yaml.vor-update compose.yaml
    $D compose up -d 2>&1 | tail -3
    warte_gesund && echo "$(t '>> Alter Stand laeuft wieder (healthy)' '>> The old version is running again (healthy)')" || echo "$(t ">> ACHTUNG: alter Container wurde nicht gesund, bitte Logs ansehen: $D compose logs --tail 50" ">> WARNING: the old container did not become healthy, please check the logs: $D compose logs --tail 50")"
  else
    echo "$(t 'Keine Sicherung (compose.yaml.vor-update) gefunden.' 'No backup (compose.yaml.vor-update) found.')"
  fi
}

if [ "${1:-}" = "--rueckweg" ]; then rueckweg; exit 0; fi

# Image aus einer Datei (bash update.sh [datei.tar.gz], sonst die neueste srtla-*.tar.gz im Ordner) oder, wenn keine Datei da ist, von Docker Hub.
IMGFILE="${1:-$(ls -1 srtla-*.tar.gz 2>/dev/null | sort -V | tail -1)}"
if [ -n "${IMGFILE:-}" ] && [ ! -f "$IMGFILE" ]; then echo "$(t "ABBRUCH: Datei $IMGFILE nicht gefunden" "ABORTED: file $IMGFILE not found")"; exit 1; fi
[ -f compose.yaml ] || { echo "$(t 'ABBRUCH: compose.yaml fehlt (Skript im Paketordner ausfuehren)' 'ABORTED: compose.yaml is missing (run the script in the package folder)')"; exit 1; }
$D compose version >/dev/null 2>&1 || { echo "$(t 'ABBRUCH: Docker Compose nicht verfuegbar' 'ABORTED: Docker Compose is not available')"; exit 1; }

echo "$(t "1/6 Pruefsumme der Image-Datei: ${IMGFILE:-(keine Datei, Download von Docker Hub)}" "1/6 Checksum of the image file: ${IMGFILE:-(no file, download from Docker Hub)}")"
if [ -z "${IMGFILE:-}" ]; then
  echo "$(t '   (Download von Docker Hub, keine Datei zu pruefen)' '   (download from Docker Hub, no file to check)')"
elif [ -f "$IMGFILE.sha256" ]; then
  if command -v sha256sum >/dev/null 2>&1; then sha256sum -c "$IMGFILE.sha256" || { echo "$(t 'ABBRUCH: Pruefsumme stimmt nicht' 'ABORTED: checksum does not match')"; exit 1; }
  else shasum -a 256 -c "$IMGFILE.sha256" || { echo "$(t 'ABBRUCH: Pruefsumme stimmt nicht' 'ABORTED: checksum does not match')"; exit 1; }; fi
else
  echo "$(t '   (keine .sha256-Datei vorhanden, Pruefung uebersprungen)' '   (no .sha256 file present, check skipped)')"
fi

echo "$(t '2/6 Laufenden Container und Daten-Volume suchen' '2/6 Looking for the running container and data volume')"
CID=$(container_id)
[ -n "$CID" ] || { echo "$(t "ABBRUCH: kein laufender Container zu dieser compose.yaml gefunden (erst 'docker compose up -d', siehe ANLEITUNG.md)" "ABORTED: no running container found for this compose.yaml (first 'docker compose up -d', see ANLEITUNG.md)")"; exit 1; }
ALT=$($D inspect "$CID" --format '{{.Config.Image}}')
VOL=$(volume_name "$CID")
HELFER="$ALT"
[ -n "$VOL" ] || { echo "$(t 'ABBRUCH: kein Daten-Volume unter /data gefunden' 'ABORTED: no data volume found at /data')"; exit 1; }
echo "$(t "   laufende Version: $ALT" "   running version:  $ALT")"
echo "$(t "   Daten-Volume:     $VOL" "   Data volume:      $VOL")"

echo "$(t '3/6 Datensicherung' '3/6 Data backup')"
umask 077
mkdir -p sicherung && chmod 700 sicherung
STAMP=$(date +%Y%m%d-%H%M%S)
SICH="sicherung/data-vor-update-$STAMP.tgz"
$D run --rm --user 0 --entrypoint tar -v "$VOL":/data:ro -v "$PWD/sicherung":/out "$HELFER" czf "/out/data-vor-update-$STAMP.tgz" -C /data . || { echo "$(t 'ABBRUCH: Sicherung fehlgeschlagen' 'ABORTED: backup failed')"; exit 1; }
VORHER=$(volume_summe "$VOL")
$D run --rm --user 0 --entrypoint chmod -v "$PWD/sicherung":/out "$HELFER" 600 "/out/data-vor-update-$STAMP.tgz" 2>/dev/null
echo "$(t "   Sicherung: $SICH (nur fuer den Besitzer lesbar, enthaelt die Schluessel im Klartext: sicher aufbewahren)" "   Backup: $SICH (readable by the owner only, contains the keys in plain text: keep it safe)")"
echo "$(t "   Pruefsumme der Daten vorher: ${VORHER:0:16}..." "   Checksum of the data before: ${VORHER:0:16}...")"

echo "$(t '4/6 Neues Image laden' '4/6 Loading the new image')"
if [ -n "${IMGFILE:-}" ]; then
  NEU=$($D load -i "$IMGFILE" | awk '/Loaded image:/{print $3}' | tail -1)
else
  REPO=$(echo "$ALT" | sed 's/:[^:/]*$//')
  echo "$(t "   lade $REPO:latest von Docker Hub ..." "   downloading $REPO:latest from Docker Hub ...")"
  $D pull "$REPO:latest" >/dev/null 2>&1 || { echo "$(t "ABBRUCH: $REPO:latest konnte nicht heruntergeladen werden (Internetverbindung?)" "ABORTED: $REPO:latest could not be downloaded (internet connection?)")"; exit 1; }
  VERS=$($D inspect "$REPO:latest" --format '{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null)
  [ -n "$VERS" ] || { echo "$(t 'ABBRUCH: Version des Images nicht lesbar' 'ABORTED: version of the image not readable')"; exit 1; }
  NEU="$REPO:$VERS"
  $D tag "$REPO:latest" "$NEU"
fi
[ -n "$NEU" ] || { echo "$(t 'ABBRUCH: Image konnte nicht geladen werden' 'ABORTED: image could not be loaded')"; exit 1; }
echo "$(t "   neue Version:     $NEU" "   new version:      $NEU")"
if [ "$NEU" = "$ALT" ]; then echo "$(t '   Hinweis: gleiche Version, es wird nur neu gestartet falls sich das Image geaendert hat.' '   Note: same version, it is only restarted if the image has changed.')"; fi

cp compose.yaml compose.yaml.vor-update
sed -i.tmp "s#^\([[:space:]]*image:[[:space:]]*\).*#\1$NEU#" compose.yaml && rm -f compose.yaml.tmp
# --- Umstellung: Schluessel zur Verschluesselung aus dem Datenvolumen nach ./secrets/ ---
MIGRIERT=0
if ! grep -q 'irl4you_enc_key' compose.yaml; then
  echo "$(t '   Umstellung: Schluesseldatei kommt aus dem Datenvolumen nach ./secrets/' '   Changeover: the key file moves from the data volume to ./secrets/')"
  mkdir -p secrets && chmod 700 secrets
  $D run --rm --user 0 --entrypoint sh -v "$VOL":/data:ro -v "$PWD/secrets":/s "$HELFER" -c '
      if test -s /data/enc.key; then cp /data/enc.key /s/enc.key; else od -An -N32 -tx1 /dev/urandom | tr -d " \n" > /s/enc.key; fi
      chown 101:102 /s/enc.key && chmod 400 /s/enc.key' || { echo "$(t 'ABBRUCH: Schluesseldatei konnte nicht angelegt werden' 'ABORTED: key file could not be created')"; exit 1; }
  # secrets: Eintraege in compose.yaml ergaenzen (Kopie liegt in compose.yaml.vor-update)
  awk '
    /^    volumes:[[:space:]]*$/ && !a { print "    secrets:"; print "      - irl4you_enc_key"; a=1 }
    /^volumes:[[:space:]]*$/ && !b { print "secrets:"; print "  irl4you_enc_key:"; print "    file: ./secrets/enc.key"; print ""; b=1 }
    { print }' compose.yaml > compose.yaml.neu && mv compose.yaml.neu compose.yaml
  grep -q 'irl4you_enc_key' compose.yaml || { echo "$(t 'ABBRUCH: compose.yaml konnte nicht angepasst werden' 'ABORTED: compose.yaml could not be adjusted')"; cp compose.yaml.vor-update compose.yaml; exit 1; }
  MIGRIERT=1
fi

grep -n 'image:' compose.yaml

echo "$(t '5/6 Container ersetzen (Daten bleiben im Volume)' '5/6 Replacing the container (data stays in the volume)')"
$D compose up -d 2>&1 | tail -3
if ! warte_gesund; then
  echo "$(t 'FEHLER: neuer Container wurde nicht gesund' 'ERROR: the new container did not become healthy')"
  rueckweg
  exit 1
fi

echo "$(t '6/6 Daten kontrollieren' '6/6 Checking the data')"
CID=$(container_id)
if [ "$MIGRIERT" -eq 1 ]; then
  if $D exec "$CID" cmp /run/secrets/irl4you_enc_key /data/enc.key >/dev/null 2>&1; then
    $D exec "$CID" sh -c 'rm -f /data/enc.key /data/enc.key.vorher' && echo "$(t '   Schluesseldatei im Datenvolumen entfernt (liegt jetzt nur noch in ./secrets/enc.key)' '   Key file removed from the data volume (it now only lives in ./secrets/enc.key)')"
  elif $D exec "$CID" test -e /data/enc.key; then
    echo "$(t '   Hinweis: die Datei im Volumen weicht ab und wurde NICHT entfernt. Bitte pruefen.' '   Note: the file in the volume differs and was NOT removed. Please check.')"
  fi
fi
NACHHER=$(volume_summe "$(volume_name "$CID")")
echo "$(t "   Pruefsumme der Daten nachher: ${NACHHER:0:16}..." "   Checksum of the data after: ${NACHHER:0:16}...")"
if [ "$VORHER" = "$NACHHER" ]; then
  echo "$(t '   Daten identisch: Zugaenge, Schluessel und Streams sind unveraendert.' '   Data identical: logins, keys and streams are unchanged.')"
else
  if [ "$MIGRIERT" -eq 1 ]; then
    echo "$(t "   Pruefsumme weicht ab, weil die Schluesseldatei aus dem Volumen entfernt wurde (erwartet). Benutzer und Streams siehst du in der Verwaltung. Sicherung: $SICH" "   The checksum differs because the key file was removed from the volume (expected). You can see users and streams in the administration. Backup: $SICH")"
  else
    echo "$(t "   Hinweis: Pruefsumme weicht ab. Der Empfaenger darf Zaehler und Zeitstempel schreiben; ob Benutzer und Streams noch da sind, siehst du in der Verwaltung. Die Sicherung liegt unter $SICH" "   Note: the checksum differs. The receiver may write counters and timestamps; you can see in the administration whether users and streams are still there. The backup is at $SICH")"
  fi
fi
$D compose ps --format 'table {{.Name}}\t{{.Image}}\t{{.Status}}'
[ "$MIGRIERT" -eq 1 ] && echo "$(t '   WICHTIG: Den Ordner secrets/ zusammen mit Ihrer Sicherung aufbewahren (ohne ihn sind die gespeicherten Schluessel nicht mehr anzeigbar; die Streams laufen trotzdem).' '   IMPORTANT: keep the folder secrets/ together with your backup (without it the stored keys can no longer be shown; the streams keep running).')"
echo "$(t 'FERTIG. Rueckweg bei Problemen: bash update.sh --rueckweg  (altes Image bleibt auf dem Rechner)' 'DONE. Rollback if there are problems: bash update.sh --rueckweg  (the old image stays on the machine)')"
