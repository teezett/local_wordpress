DC_BINARY = docker compose
#DC_FILE = docker-compose.${DEPLOY_STAGE}.yml
DC = ${DC_BINARY} -f docker-compose.yml

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

down: ## stop and remove containers
	${DC} down --remove-orphans
