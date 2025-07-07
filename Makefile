export LC_ALL=C
DC_BINARY = docker compose
#DC_FILE = docker-compose.${DEPLOY_STAGE}.yml
DC = ${DC_BINARY} -f docker-compose.yml
BACKUP_DIR = db-backups
CREDENTIALS_FILE = .db.env
DB_FILE = tmp/LincolnSiedlung-db.sql

help:
	@echo "# Local wordpress instance"
	@echo "Commands: make ..."
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_0-9-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

ps: ## what's up?
	${DC} ps

logs: ## Show logs of all containers (stop with ctrl-c)
	${DC} logs -f -t --tail=100

up:	## start all containers
	${DC} up -d --wait

db-up:	# start db container
	${DC} up -d --wait db
.PHONY: db-up

down: ## stop and remove containers
	${DC} down --remove-orphans

restore-db: db-up ## restore db with name ${BACKUP_DB_FILE}
	test -n "${BACKUP_DB_FILE}"  # check if variable BACKUP_DB_FILE is set
	test -r "./${BACKUP_DIR}/${BACKUP_DB_FILE}"
	test -r "./${CREDENTIALS_FILE}"
	cp ./${BACKUP_DIR}/${BACKUP_DB_FILE} ${DB_FILE}
	sed -i -e 's@https://www.lincoln-darmstadt.de@http://localhost:8080@g' ${DB_FILE}
	sed -i -e 's/lincoln-darmstadt/localhost:8080/g' ${DB_FILE}
	. ./${CREDENTIALS_FILE} && mysql -h 127.0.0.1 -P 3306 -u $$DB_USER -p$$DB_PASS $$DB_NAME < ${DB_FILE}
.PHONY: restore-db

