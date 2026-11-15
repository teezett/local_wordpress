export LC_ALL=C
# Mehrere Seiten: make SITE=meineseite <target>  (Config .db.meineseite.env, Daten in sites/meineseite/)
# Ohne SITE: .db.env, db-backups/, wp-content/
SITE ?=
ifneq ($(SITE),)
CREDENTIALS_FILE = .db.$(SITE).env
BACKUP_DIR = sites/$(SITE)/db-backups
export WP_CONTENT_DIR = sites/$(SITE)/wp-content
export COMPOSE_PROJECT_NAME = local_wordpress_$(SITE)
else
CREDENTIALS_FILE = .db.env
BACKUP_DIR = db-backups
endif
# Neuester Dump im Backup-Verzeichnis; ueberschreibbar: make restore-db DUMP=db-backups/foo.sql
DUMP ?= $(lastword $(sort $(wildcard $(BACKUP_DIR)/backup_*-db*)))
DC = docker compose --env-file ${CREDENTIALS_FILE} -f docker-compose.yml

.DEFAULT_GOAL := help
SHELL := /bin/bash
.PHONY: fetch-backups restore-files restore-all help check ps logs up db-up down reset restore-db search-replace wp

help:
	@echo "# Local wordpress instance"
	@echo "Commands: make ..."
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_0-9-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check:
	@test -r "${CREDENTIALS_FILE}" || { echo "${CREDENTIALS_FILE} fehlt: cp .db.template.env ${CREDENTIALS_FILE} und anpassen"; exit 1; }

ps: check ## what's up?
	${DC} ps

logs: check ## Show logs of all containers (stop with ctrl-c)
	${DC} logs -f -t --tail=100

up: check ## start all containers (Seite: http://localhost:8080, Mails: http://localhost:8025)
	${DC} up -d --wait

db-up: check ## start db container only
	${DC} up -d --wait db

down: check ## stop and remove containers (data is kept)
	${DC} down --remove-orphans

reset: check ## Containers UND Volumes (DB + WP-Core) loeschen; wp-content/ bleibt
	@printf "Datenbank und WordPress-Volume wirklich loeschen? [y/N] " && read ans && [ "$$ans" = y ]
	${DC} --profile tools down --remove-orphans --volumes

restore-db: up ## DB aus Dump wiederherstellen (DUMP=..., Standard: neuester in db-backups/), URLs ersetzen
	@test -r "${DUMP}" || { echo "Dump nicht lesbar: '${DUMP}' (DUMP=... setzen)"; exit 1; }
	@echo "==> Importiere ${DUMP}"
	${DC} exec -T db sh -c 'mysql -uroot -p"$$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS $$MYSQL_DATABASE; CREATE DATABASE $$MYSQL_DATABASE;"'
	if echo "${DUMP}" | grep -q '\.gz$$'; then gunzip -c "${DUMP}"; else cat "${DUMP}"; fi \
	  | ${DC} exec -T db sh -c 'mysql -uroot -p"$$MYSQL_ROOT_PASSWORD" "$$MYSQL_DATABASE"'
	$(MAKE) search-replace

search-replace: check ## PROD_URL -> localhost ersetzen (serialisierungssicher), Plugins deaktivieren
	${DC} run --rm wpcli sh -c '\
	  test -n "$$PROD_URL" || { echo "PROD_URL fehlt in .db.env"; exit 1; }; \
	  wp search-replace "$$PROD_URL" "$$LOCAL_URL" --all-tables --skip-columns=guid && \
	  wp search-replace "$${PROD_URL#*://}" "$${LOCAL_URL#*://}" --all-tables --skip-columns=guid; \
	  for p in $$DISABLE_PLUGINS; do wp plugin deactivate "$$p" || true; done; \
	  wp cache flush; wp rewrite flush'

wp: check ## WP-CLI ausfuehren: make wp ARGS="plugin list"
	${DC} run --rm wpcli wp ${ARGS}

fetch-backups: check ## UpdraftPlus-Sicherung holen, rsync/SSH oder rclone (UPDRAFT_METHOD/UPDRAFT_REMOTE in .db.env; STAMP=...)
	set -a; . ./${CREDENTIALS_FILE}; set +a; BACKUP_DIR=${BACKUP_DIR} scripts/fetch-backups.sh ${STAMP}

restore-files: ## plugins/themes/uploads/others aus UpdraftPlus-Zips nach wp-content/ entpacken (STAMP=... optional)
	BACKUP_DIR=${BACKUP_DIR} TARGET_DIR=$${WP_CONTENT_DIR:-wp-content} scripts/restore-files.sh ${STAMP}

restore-all: restore-files restore-db ## Dateien UND Datenbank aus der Sicherung wiederherstellen
