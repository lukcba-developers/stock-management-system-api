# Makefile para Stock Management System

# Variables
DOCKER_COMPOSE = docker-compose
NODE_BACKEND = cd backend && npm
NODE_FRONTEND = cd frontend && npm
SCRIPT_DIR = ./scripts
BACKEND_ENV_EXAMPLE = backend/.env.example
BACKEND_ENV = backend/.env
FRONTEND_ENV_EXAMPLE = frontend/.env.example
FRONTEND_ENV = frontend/.env

# Comandos principales
.PHONY: all
all: setup

.PHONY: setup
setup: env-setup install-deps

.PHONY: env-setup
env-setup:
	@echo "🔧 Configurando variables de entorno..."
	@if [ ! -f $(BACKEND_ENV) ]; then \
		node $(SCRIPT_DIR)/generate-env.js; \
	fi
	@if [ ! -f $(FRONTEND_ENV) ]; then \
		cp $(FRONTEND_ENV_EXAMPLE) $(FRONTEND_ENV); \
	fi

.PHONY: install-deps
install-deps:
	@echo "📦 Instalando dependencias..."
	$(NODE_BACKEND) install
	$(NODE_FRONTEND) install

.PHONY: dev
dev:
	@echo "🚀 Iniciando entorno de desarrollo..."
	$(DOCKER_COMPOSE) up -d
	$(NODE_BACKEND) run dev & $(NODE_FRONTEND) run dev

.PHONY: build
build:
	@echo "🏗️  Construyendo aplicación..."
	$(NODE_BACKEND) run build
	$(NODE_FRONTEND) run build

.PHONY: test
test:
	@echo "🧪 Ejecutando tests..."
	$(NODE_BACKEND) test
	$(NODE_FRONTEND) test

.PHONY: lint
lint:
	@echo "🔍 Ejecutando linters..."
	$(NODE_BACKEND) run lint
	$(NODE_FRONTEND) run lint

.PHONY: clean
clean:
	@echo "🧹 Limpiando archivos temporales..."
	rm -rf backend/dist frontend/dist
	rm -rf backend/node_modules frontend/node_modules
	$(DOCKER_COMPOSE) down -v

.PHONY: deploy
deploy:
	@echo "🚀 Desplegando aplicación..."
	go run $(SCRIPT_DIR)/deploy.go

.PHONY: health-check
health-check:
	@echo "🩺 Ejecutando chequeo de salud..."
	node $(SCRIPT_DIR)/health-check.js

.PHONY: backup-db
backup-db:
	@echo "💾 Realizando backup de la base de datos..."
	@read -p "Ingrese la ruta del archivo de backup: " backup_path; \
	$(SCRIPT_DIR)/backup-database.sh "$$backup_path"

.PHONY: restore-db
restore-db:
	@echo "📥 Restaurando base de datos..."
	@read -p "Ingrese la ruta del archivo de backup: " backup_path; \
	$(SCRIPT_DIR)/restore-database.sh "$$backup_path"

# Ayuda
.PHONY: help
help:
	@echo "📋 Comandos disponibles:"
	@echo "  make setup        - Configura el entorno y instala dependencias"
	@echo "  make dev         - Inicia el entorno de desarrollo"
	@echo "  make build       - Construye la aplicación"
	@echo "  make test        - Ejecuta los tests"
	@echo "  make lint        - Ejecuta los linters"
	@echo "  make clean       - Limpia archivos temporales"
	@echo "  make deploy      - Despliega la aplicación"
	@echo "  make health-check - Ejecuta chequeo de salud"
	@echo "  make backup-db   - Realiza backup de la base de datos"
	@echo "  make restore-db  - Restaura la base de datos"
	@echo "  make help        - Muestra esta ayuda" 