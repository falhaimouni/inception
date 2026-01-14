NAME         := inception
COMPOSE_FILE := srcs/docker-compose.yml
ENV_FILE     := srcs/.env
COMPOSE      := docker compose

DATA_DIR     := /home/$(USER)/data
WP_DATA      := $(DATA_DIR)/wordpress
DB_DATA      := $(DATA_DIR)/mariadb

all: up

up: build
	@$(COMPOSE) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d

build: prepare
	@$(COMPOSE) -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build

down:
	@$(COMPOSE) -f $(COMPOSE_FILE) down

prepare:
	@mkdir -p $(WP_DATA) $(DB_DATA)

re: down all

.PHONY: all up build down prepare re
