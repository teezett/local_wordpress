#!/bin/sh
# Entpackt die Datei-Backups von UpdraftPlus (plugins/themes/uploads, aus others nur languages) nach wp-content/.
#
# UpdraftPlus legt pro Sicherung Dateien an wie
#   backup_2025-07-02-2339_Site_652f38cc34d2-{db,plugins,themes,uploads,others}.zip
# (bei grossen Seiten mehrteilig: -uploads.zip, -uploads2.zip, ...).
# Da Datenbank und Dateien oft in verschiedenen Rhythmen gesichert werden, wird fuer jeden Teil die
# neueste Sicherung benutzt, die diesen Teil enthaelt. Mit STEMPEL (z.B. 2025-07-02-2339) wird
# stattdessen genau diese Sicherung verwendet.
#
# Aufruf: scripts/restore-files.sh [STEMPEL]
# Umgebung: BACKUP_DIR (db-backups), TARGET_DIR (wp-content)
set -eu

BACKUP_DIR=${BACKUP_DIR:-db-backups}
TARGET_DIR=${TARGET_DIR:-wp-content}
only_stamp=${1:-}

command -v unzip >/dev/null || { echo "unzip fehlt" >&2; exit 1; }
listing=$(ls "$BACKUP_DIR" 2>/dev/null || true)

found=0
for kind in plugins themes uploads others; do
  stamp=$only_stamp
  if [ -z "$stamp" ]; then
    stamp=$(printf '%s\n' "$listing" \
      | sed -n "s/^backup_\([0-9-]\{15\}\)_.*-${kind}[0-9]*\.zip\$/\1/p" | sort -u | tail -n 1)
  fi
  if [ -z "$stamp" ]; then echo "==> $kind: keine Sicherung in $BACKUP_DIR"; continue; fi
  echo "==> $kind: Sicherung $stamp"
  for zip in "$BACKUP_DIR"/backup_"$stamp"_*-"$kind".zip "$BACKUP_DIR"/backup_"$stamp"_*-"$kind"[0-9]*.zip; do
    [ -f "$zip" ] || continue
    found=1
    mkdir -p "$TARGET_DIR"
    echo "    $(basename "$zip") -> $TARGET_DIR/"
    # Die Archive enthalten ihren Ordner selbst (plugins/, themes/, uploads/) relativ zu wp-content.
    # "others" enthaelt zusaetzlich Cache-Reste und -old-Ordner; davon wird nur languages/ gebraucht.
    if [ "$kind" = others ]; then
      unzip -oq "$zip" 'languages/*' -d "$TARGET_DIR" || true
    else
      unzip -oq "$zip" -d "$TARGET_DIR"
    fi
  done
done

[ "$found" = 1 ] || { echo "Keine Datei-Archive (plugins/themes/uploads/others) in $BACKUP_DIR gefunden" >&2; exit 1; }
echo "==> Fertig"
