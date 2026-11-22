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
    echo ">> Rueckweg: alte compose.yaml wiederherstellen und Container neu starten"
    # Der alte Stand erwartet die Schluesseldatei im Volumen: aus secrets/ zurueckkopieren, falls sie dort fehlt
    local cid vol img
    cid=$(container_id); vol=$(volume_name "$cid"); img=$($D inspect "$cid" --format '{{.Config.Image}}' 2>/dev/null)
    if [ -n "$vol" ] && [ -n "$img" ] && [ -d secrets ]; then
      $D run --rm --user 0 --entrypoint sh -v "$vol":/data -v "$PWD/secrets":/s:ro "$img" -c 'test -s /s/enc.key && ! test -e /data/enc.key && cp /s/enc.key /data/enc.key && chown 101:102 /data/enc.key && chmod 600 /data/enc.key && echo "   Schluesseldatei ins Volumen zurueckgelegt"' 2>/dev/null
    fi
    cp compose.yaml.vor-update compose.yaml
    $D compose up -d 2>&1 | tail -3
    warte_gesund && echo ">> Alter Stand laeuft wieder (healthy)" || echo ">> ACHTUNG: alter Container wurde nicht gesund, bitte Logs ansehen: $D compose logs --tail 50"
  else
    echo "Keine Sicherung (compose.yaml.vor-update) gefunden."
  fi
}

if [ "${1:-}" = "--rueckweg" ]; then rueckweg; exit 0; fi

# Image aus einer Datei (bash update.sh [datei.tar.gz], sonst die neueste srtla-*.tar.gz im Ordner) oder, wenn keine Datei da ist, von Docker Hub.
IMGFILE="${1:-$(ls -1 srtla-*.tar.gz 2>/dev/null | sort -V | tail -1)}"
if [ -n "${IMGFILE:-}" ] && [ ! -f "$IMGFILE" ]; then echo "ABBRUCH: Datei $IMGFILE nicht gefunden"; exit 1; fi
[ -f compose.yaml ] || { echo "ABBRUCH: compose.yaml fehlt (Skript im Paketordner ausfuehren)"; exit 1; }
$D compose version >/dev/null 2>&1 || { echo "ABBRUCH: Docker Compose nicht verfuegbar"; exit 1; }

echo "1/6 Pruefsumme der Image-Datei: ${IMGFILE:-(keine Datei, Download von Docker Hub)}"
if [ -z "${IMGFILE:-}" ]; then
  echo "   (Download von Docker Hub, keine Datei zu pruefen)"
elif [ -f "$IMGFILE.sha256" ]; then
  if command -v sha256sum >/dev/null 2>&1; then sha256sum -c "$IMGFILE.sha256" || { echo "ABBRUCH: Pruefsumme stimmt nicht"; exit 1; }
  else shasum -a 256 -c "$IMGFILE.sha256" || { echo "ABBRUCH: Pruefsumme stimmt nicht"; exit 1; }; fi
else
  echo "   (keine .sha256-Datei vorhanden, Pruefung uebersprungen)"
fi

echo "2/6 Laufenden Container und Daten-Volume suchen"
CID=$(container_id)
[ -n "$CID" ] || { echo "ABBRUCH: kein laufender Container zu dieser compose.yaml gefunden (erst 'docker compose up -d', siehe ANLEITUNG.md)"; exit 1; }
ALT=$($D inspect "$CID" --format '{{.Config.Image}}')
VOL=$(volume_name "$CID")
HELFER="$ALT"
[ -n "$VOL" ] || { echo "ABBRUCH: kein Daten-Volume unter /data gefunden"; exit 1; }
echo "   laufende Version: $ALT"
echo "   Daten-Volume:     $VOL"

echo "3/6 Datensicherung"
umask 077
mkdir -p sicherung && chmod 700 sicherung
STAMP=$(date +%Y%m%d-%H%M%S)
SICH="sicherung/data-vor-update-$STAMP.tgz"
$D run --rm --user 0 --entrypoint tar -v "$VOL":/data:ro -v "$PWD/sicherung":/out "$HELFER" czf "/out/data-vor-update-$STAMP.tgz" -C /data . || { echo "ABBRUCH: Sicherung fehlgeschlagen"; exit 1; }
VORHER=$(volume_summe "$VOL")
$D run --rm --user 0 --entrypoint chmod -v "$PWD/sicherung":/out "$HELFER" 600 "/out/data-vor-update-$STAMP.tgz" 2>/dev/null
echo "   Sicherung: $SICH (nur fuer den Besitzer lesbar, enthaelt die Schluessel im Klartext: sicher aufbewahren)"
echo "   Pruefsumme der Daten vorher: ${VORHER:0:16}..."

echo "4/6 Neues Image laden"
if [ -n "${IMGFILE:-}" ]; then
  NEU=$($D load -i "$IMGFILE" | awk '/Loaded image:/{print $3}' | tail -1)
else
  REPO=$(echo "$ALT" | sed 's/:[^:/]*$//')
  echo "   lade $REPO:latest von Docker Hub ..."
  $D pull "$REPO:latest" >/dev/null 2>&1 || { echo "ABBRUCH: $REPO:latest konnte nicht heruntergeladen werden (Internetverbindung?)"; exit 1; }
  VERS=$($D inspect "$REPO:latest" --format '{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null)
  [ -n "$VERS" ] || { echo "ABBRUCH: Version des Images nicht lesbar"; exit 1; }
  NEU="$REPO:$VERS"
  $D tag "$REPO:latest" "$NEU"
fi
[ -n "$NEU" ] || { echo "ABBRUCH: Image konnte nicht geladen werden"; exit 1; }
echo "   neue Version:     $NEU"
if [ "$NEU" = "$ALT" ]; then echo "   Hinweis: gleiche Version, es wird nur neu gestartet falls sich das Image geaendert hat."; fi

cp compose.yaml compose.yaml.vor-update
sed -i.tmp "s#^\([[:space:]]*image:[[:space:]]*\).*#\1$NEU#" compose.yaml && rm -f compose.yaml.tmp
# --- Umstellung: Schluessel zur Verschluesselung aus dem Datenvolumen nach ./secrets/ ---
MIGRIERT=0
if ! grep -q 'irl4you_enc_key' compose.yaml; then
  echo "   Umstellung: Schluesseldatei kommt aus dem Datenvolumen nach ./secrets/"
  mkdir -p secrets && chmod 700 secrets
  $D run --rm --user 0 --entrypoint sh -v "$VOL":/data:ro -v "$PWD/secrets":/s "$HELFER" -c '
      if test -s /data/enc.key; then cp /data/enc.key /s/enc.key; else od -An -N32 -tx1 /dev/urandom | tr -d " \n" > /s/enc.key; fi
      chown 101:102 /s/enc.key && chmod 400 /s/enc.key' || { echo "ABBRUCH: Schluesseldatei konnte nicht angelegt werden"; exit 1; }
  # secrets: Eintraege in compose.yaml ergaenzen (Kopie liegt in compose.yaml.vor-update)
  awk '
    /^    volumes:[[:space:]]*$/ && !a { print "    secrets:"; print "      - irl4you_enc_key"; a=1 }
    /^volumes:[[:space:]]*$/ && !b { print "secrets:"; print "  irl4you_enc_key:"; print "    file: ./secrets/enc.key"; print ""; b=1 }
    { print }' compose.yaml > compose.yaml.neu && mv compose.yaml.neu compose.yaml
  grep -q 'irl4you_enc_key' compose.yaml || { echo "ABBRUCH: compose.yaml konnte nicht angepasst werden"; cp compose.yaml.vor-update compose.yaml; exit 1; }
  MIGRIERT=1
fi

grep -n 'image:' compose.yaml

echo "5/6 Container ersetzen (Daten bleiben im Volume)"
$D compose up -d 2>&1 | tail -3
if ! warte_gesund; then
  echo "FEHLER: neuer Container wurde nicht gesund"
  rueckweg
  exit 1
fi

echo "6/6 Daten kontrollieren"
CID=$(container_id)
if [ "$MIGRIERT" -eq 1 ]; then
  if $D exec "$CID" cmp /run/secrets/irl4you_enc_key /data/enc.key >/dev/null 2>&1; then
    $D exec "$CID" sh -c 'rm -f /data/enc.key /data/enc.key.vorher' && echo "   Schluesseldatei im Datenvolumen entfernt (liegt jetzt nur noch in ./secrets/enc.key)"
  elif $D exec "$CID" test -e /data/enc.key; then
    echo "   Hinweis: die Datei im Volumen weicht ab und wurde NICHT entfernt. Bitte pruefen."
  fi
fi
NACHHER=$(volume_summe "$(volume_name "$CID")")
echo "   Pruefsumme der Daten nachher: ${NACHHER:0:16}..."
if [ "$VORHER" = "$NACHHER" ]; then
  echo "   Daten identisch: Zugaenge, Schluessel und Streams sind unveraendert."
else
  if [ "$MIGRIERT" -eq 1 ]; then
    echo "   Pruefsumme weicht ab, weil die Schluesseldatei aus dem Volumen entfernt wurde (erwartet). Benutzer und Streams siehst du in der Verwaltung. Sicherung: $SICH"
  else
    echo "   Hinweis: Pruefsumme weicht ab. Der Empfaenger darf Zaehler und Zeitstempel schreiben; ob Benutzer und Streams noch da sind, siehst du in der Verwaltung. Die Sicherung liegt unter $SICH"
  fi
fi
$D compose ps --format 'table {{.Name}}\t{{.Image}}\t{{.Status}}'
[ "$MIGRIERT" -eq 1 ] && echo "   WICHTIG: Den Ordner secrets/ zusammen mit Ihrer Sicherung aufbewahren (ohne ihn sind die gespeicherten Schluessel nicht mehr anzeigbar; die Streams laufen trotzdem)."
echo "FERTIG. Rueckweg bei Problemen: bash update.sh --rueckweg  (altes Image bleibt auf dem Rechner)"
