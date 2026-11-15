# local_wordpress

Lokale Staging-Umgebung für eine WordPress-Seite (Docker): WordPress + MySQL aus einem Live-Backup,
URLs werden auf `http://localhost:8080` umgeschrieben, ausgehende Mails landen in Mailpit.

## Voraussetzungen

- Docker mit Compose-Plugin ([Installation](https://docs.docker.com/engine/install/)); unter Linux ggf.
  [Docker ohne root nutzen](https://docs.docker.com/engine/install/linux-postinstall/)
- `make`

Ein MySQL-Client auf dem Host ist **nicht** nötig.

## Einrichtung

1. Konfiguration anlegen: `cp .db.template.env .db.env` und anpassen (DB-Zugang, `PROD_URL`, Versionen).
   Die Versionen (`WP_VERSION`, `PHP_VERSION`, `MYSQL_VERSION`) sollten zur Live-Seite passen; sie stehen
   im Kopf des Dumps. `.db.env` ist nicht im Git.
2. UpdraftPlus-Sicherung nach `db-backups/` legen (alle Dateien einer Sicherung:
   `backup_<Datum>_…-db[.gz]`, `-plugins.zip`, `-themes.zip`, `-uploads.zip`, `-others.zip`).
   `make fetch-backups` holt die Sicherung automatisch (Einstellungen in `.db.env`). Da UpdraftPlus
   Datenbank und Dateien oft in verschiedenen Rhythmen sichert (z. B. DB täglich, Dateien wöchentlich),
   wird **pro Teil** (db, plugins, themes, uploads, others) die neueste Sicherung geholt, die diesen Teil
   enthält. Datenbank und Dateien können dadurch bis zu einem Intervall auseinanderliegen; für einen
   konsistenten Stand `STAMP=<Zeitstempel der Voll-Sicherung>` angeben.
   - **Webspace per SSH:** `UPDRAFT_METHOD=rsync`, `UPDRAFT_REMOTE=user@host:/pfad/zu/wp-content/updraft/`
     (SSH-Key/Login muss funktionieren).
   - **Google Drive:** `UPDRAFT_METHOD=rclone`, `UPDRAFT_REMOTE=gdrive:UpdraftPlus`. Einmalig
     `brew install rclone` und `rclone config` (neuer Remote `gdrive`, Typ `drive`, Browser-Login).
   - Andere Ziele (Dropbox, S3 …): mit rclone genauso möglich, oder Dateien von Hand nach `db-backups/` legen.
3. `make restore-all` entpackt die Dateien nach `wp-content/` und spielt die DB ein
   (einzeln: `make restore-files`, `make restore-db`; bestimmte Sicherung: `STAMP=2025-07-02-2339`).

## Mehrere Seiten

Jede Seite bekommt eine eigene Config und eigene Daten, mit `SITE=<name>` vor jedem Befehl:

```sh
cp .db.template.env .db.seite-a.env     # anpassen, WP_PORT/DB_PORT/MAILPIT_PORT je Seite verschieden!
make SITE=seite-a fetch-backups restore-all
make SITE=seite-b up
```

Daten liegen dann in `sites/<name>/db-backups` und `sites/<name>/wp-content`, die Container und Volumes
sind pro Seite getrennt (`local_wordpress_<name>`). Ohne `SITE` gilt wie bisher `.db.env`, `db-backups/`, `wp-content/`.

## Benutzung

`make help` zeigt alle Befehle.

| Befehl | Wirkung |
| --- | --- |
| `make up` | Container starten – Seite: <http://localhost:8080>, Mails: <http://localhost:8025> |
| `make restore-db` | DB löschen, neuesten Dump aus `db-backups/` einspielen, URLs ersetzen |
| `make restore-db DUMP=db-backups/datei.sql` | bestimmten Dump einspielen |
| `make search-replace` | nur URL-Ersetzung + Deaktivieren der `DISABLE_PLUGINS` wiederholen |
| `make wp ARGS="plugin list"` | WP-CLI ausführen |
| `make down` | Container stoppen (Daten bleiben) |
| `make reset` | Container **und** DB/WP-Volumes löschen (`wp-content/` bleibt) |

Typischer Ablauf: `make up` → `make restore-db` → Änderungen testen → bei Bedarf `make restore-db` für einen frischen Stand.

## Staging-Schutz

- Ports sind nur an `127.0.0.1` gebunden.
- Alle Mails gehen an Mailpit, nie an echte Empfänger (`staging/mu-plugins/staging.php`).
- Suchmaschinen sind ausgesperrt, WP-Cron ist aus, `WP_ENVIRONMENT_TYPE=staging`.
- Plugins aus `DISABLE_PLUGINS` (Backup-, Cache-Plugins …) werden beim Restore deaktiviert.
- Der Dump enthält echte Nutzerdaten – nicht weitergeben.

## Hinweise

- URLs werden mit WP-CLI ersetzt (`wp search-replace`), das serialisierte Daten korrekt behandelt.
  Kein `sed` auf dem Dump.
- Nach einem Wechsel der Versionen oder Zugangsdaten in `.db.env` einmal `make reset` ausführen.
- Läuft `docker` im Terminal in einen Fehler `docker-credential-osxkeychain not found`, fehlt
  `/Applications/Docker.app/Contents/Resources/bin` im `PATH`.
