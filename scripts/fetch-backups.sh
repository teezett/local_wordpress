#!/bin/sh
# Holt UpdraftPlus-Sicherungen nach BACKUP_DIR.
#
# UpdraftPlus sichert Datenbank und Dateien oft in verschiedenen Rhythmen (z.B. DB taeglich, Dateien
# woechentlich). Darum wird fuer JEDEN Teil (db, plugins, themes, uploads, others) die neueste
# Sicherung geholt, die diesen Teil enthaelt. Mit STEMPEL wird stattdessen genau diese Sicherung
# (alle ihre Teile) geholt.
#
# Konfiguration in .db*.env:
#   UPDRAFT_METHOD=rsync   UPDRAFT_REMOTE=user@host:/pfad/zu/wp-content/updraft/   (Webspace per SSH)
#   UPDRAFT_METHOD=rclone  UPDRAFT_REMOTE=gdrive:UpdraftPlus                         (Google Drive & Co.)
# rclone einmalig einrichten:  brew install rclone && rclone config  (Remote "gdrive", Typ drive)
#
# Aufruf: scripts/fetch-backups.sh [STEMPEL]   z.B. 2025-07-02-2339
set -eu

BACKUP_DIR=${BACKUP_DIR:-db-backups}
method=${UPDRAFT_METHOD:-rsync}
remote=${UPDRAFT_REMOTE:-}
[ -n "$remote" ] || { echo "UPDRAFT_REMOTE fehlt in der .env-Datei" >&2; exit 1; }
only_stamp=${1:-}

case "$method" in
  rsync)  command -v rsync  >/dev/null || { echo "rsync fehlt" >&2; exit 1; } ;;
  rclone) command -v rclone >/dev/null || { echo "rclone fehlt (brew install rclone, dann rclone config)" >&2; exit 1; } ;;
  *) echo "UPDRAFT_METHOD muss rsync oder rclone sein" >&2; exit 1 ;;
esac

case "$method" in
  rsync)
    if [ -d "${remote%/}" ]; then listing=$(ls "${remote%/}")   # lokaler Pfad (Tests)
    else listing=$(ssh "${remote%%:*}" "ls '${remote#*:}'"); fi ;;
  rclone) listing=$(rclone lsf "$remote") ;;
esac

fetch() { # fetch <stempel> <teil>
  pat="backup_${1}_*-${2}*"
  echo "    $2: Sicherung $1"
  case "$method" in
    rsync)  rsync -a --progress --include="$pat" --exclude='*' "${remote%/}/" "$BACKUP_DIR/" ;;
    rclone) rclone copy --progress --include "$pat" "$remote" "$BACKUP_DIR" ;;
  esac
}

mkdir -p "$BACKUP_DIR"
echo "==> Hole von $remote ($method)"
got=0
for kind in db plugins themes uploads others; do
  stamp=$only_stamp
  if [ -z "$stamp" ]; then
    stamp=$(printf '%s\n' "$listing" \
      | sed -n "s/^backup_\([0-9-]\{15\}\)_.*-${kind}[0-9]*\(\.[A-Za-z.]*\)\{0,1\}\$/\1/p" | sort -u | tail -n 1)
  fi
  if [ -z "$stamp" ]; then echo "    $kind: keine Sicherung gefunden"; continue; fi
  fetch "$stamp" "$kind"
  got=1
done
[ "$got" = 1 ] || { echo "Nichts gefunden auf $remote" >&2; exit 1; }
