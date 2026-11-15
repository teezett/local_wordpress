# local_wordpress

Lokale WordPress-Staging-Umgebung (Docker) zum Testen von Änderungen vor dem Live-Gang.
Daten kommen aus UpdraftPlus-Backups. Sprache im Projekt: Deutsch (Kommentare, README, Commits).

## Aufbau

- `docker-compose.yml`: `wordpress` (gepinnt), `db` (MySQL), `mailpit` (fängt Mails), `wpcli` (Profil `tools`, nur via `make wp`/`run`)
- `Makefile`: alle Befehle, `make help` listet sie. Compose läuft immer mit `--env-file <Config>`.
- `scripts/fetch-backups.sh`: holt UpdraftPlus-Backups (rsync/SSH oder rclone)
- `scripts/restore-files.sh`: entpackt plugins/themes/uploads (aus `others` nur `languages/`) nach `wp-content`
- `staging/mu-plugins/staging.php`: Mails an Mailpit, Suchmaschinen aus, "LOCAL STAGING" in der Admin-Leiste
- `.db.template.env`: Vorlage für die Config je Seite

## Seiten (`SITE`)

Pro Seite eine Config `.db.<site>.env` (nicht im Git) und Daten unter `sites/<site>/{db-backups,wp-content}` (nicht im Git).
Befehle immer mit `make SITE=<site> …`. Ohne `SITE` gelten `.db.env`, `db-backups/`, `wp-content/`.
Aktuell eingerichtet: `lincoln` (https://www.lincoln-darmstadt.de, Backups in Google Drive).

```sh
make SITE=lincoln fetch-backups   # neueste Sicherung je Teil (db/plugins/themes/uploads/others) holen
make SITE=lincoln restore-all     # Dateien entpacken + DB einspielen + URLs ersetzen
make SITE=lincoln up | down | ps | logs
make SITE=lincoln wp ARGS="plugin list"
make SITE=lincoln reset           # löscht DB- und WP-Volumes (fragt nach)
```

Seite: http://localhost:8080 · Mails: http://localhost:8025 (Ports pro Seite in `.db.<site>.env`: `WP_PORT`, `DB_PORT`, `MAILPIT_PORT`).

## Wichtige Regeln

- `.db*.env` enthält Passwörter: nie ausgeben, committen oder in andere Dateien kopieren (Werte nur maskiert zeigen).
- URLs nie per `sed` im Dump ersetzen (serialisierte Daten brechen), sondern `wp search-replace` (`make search-replace`).
- WordPress/PHP/MySQL-Versionen stehen in der Config und sollen zur Live-Seite passen (Kopf des Dumps nennt sie).
- UpdraftPlus sichert DB und Dateien in verschiedenen Rhythmen, daher wird pro Teil die neueste Sicherung gewählt.
  DB und Dateien können dadurch auseinanderliegen; für einen konsistenten Stand `STAMP=<Zeitstempel>` angeben.
- `DISABLE_PLUGINS` (in der Config) wird bei jedem Restore deaktiviert: Backup-, Cache-, Link-Check-Plugins gehören nicht auf Staging.
- Ports sind nur an `127.0.0.1` gebunden, Mails gehen nie an echte Empfänger.

## Stolpersteine

- **Docker-PATH:** Meldet `docker compose` `docker-credential-osxkeychain not found`, fehlt im `PATH`:
  `export PATH=$PATH:/Applications/Docker.app/Contents/Resources/bin`
- **Docker läuft nicht:** `open -a Docker`, dann warten, bis `docker info` antwortet.
- **rclone/Google Drive:** Remote `lincoln-backup` (Typ `drive`, `scope=drive.readonly`, `shared_with_me=true`,
  weil der Ordner `UpdraftPlus` nur freigegeben ist). Beim Einrichten `client_id` leer lassen. Die geteilte
  rclone-Client-ID läuft 2026 aus: eigene Client-ID anlegen (https://rclone.org/drive/#making-your-own-client-id).
  Der Login im Browser geht nur interaktiv (`rclone config reconnect lincoln-backup:`).
- **Versions-/Credential-Wechsel:** Danach einmal `make SITE=<site> reset`, sonst passt das DB-Volume nicht mehr.
- **UpdraftPlus-Zips** enthalten ihren Ordner (`plugins/…`, `themes/…`, `uploads/…`) schon selbst; direkt nach `wp-content` entpacken.
- `sed -i` ist auf macOS anders als auf Linux (`sed -i ''`); im Makefile wird kein `sed -i` mehr benutzt.

## Konventionen

- Kleine, thematisch getrennte Commits, deutsche Messages.
- Änderungen an Makefile/Skripten mit `make -n …` und `sh -n scripts/*.sh` prüfen, `docker compose --env-file <Config> config -q` für die Compose-Datei.
- Großes (Backups, `sites/`, `wp-content/`) steht in `.gitignore` und gehört nicht ins Repo.
