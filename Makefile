NAME         := inception
COMPOSE_FILE := srcs/docker-compose.yml
ENV_FILE     := srcs/.env
COMPOSE      := docker compose
USER         := $(shell whoami)

DATA_DIR     := /home/$(USER)/data
WP_DATA      := $(DATA_DIR)/wordpress
DB_DATA      := $(DATA_DIR)/mariadb

all: build up

build: prepare
	@echo "Building Docker images..."
	@$(COMPOSE) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build

up: prepare
	@echo "Starting containers..."
	@$(COMPOSE) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d
	@echo "✓ Inception is starting - accessing at https://$(shell grep DOMAIN_NAME $(ENV_FILE) | cut -d'=' -f2)"

down:
	@echo "Stopping containers..."
	@$(COMPOSE) -f $(COMPOSE_FILE) down

logs:
	@$(COMPOSE) -f $(COMPOSE_FILE) logs -f

ps:
	@$(COMPOSE) -f $(COMPOSE_FILE) ps

clean: down
	@echo "Cleaning up containers and images..."
	@docker system prune -f

fclean: clean
	@echo "Removing all data and volumes..."
	@sudo rm -rf $(DATA_DIR)
	@docker system prune -af

re: fclean all

prepare:
	@mkdir -p $(WP_DATA) $(DB_DATA)
	@chmod 777 $(WP_DATA) $(DB_DATA) 2>/dev/null || true

.PHONY: all build up down logs ps clean fclean re prepare
