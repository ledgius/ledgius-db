# Ledgius DB — Flyway Migration Targets
# Spec references: A-0021.

# ── Connection defaults (override via env or .env.local) ──
DB_HOST ?= localhost
DB_PORT ?= 5432
DB_USER ?= ledgius
DB_PASSWORD ?= ledgius_dev_password
TENANT_DB ?= ledgius
PLATFORM_DB ?= ledgius_platform

export DB_HOST DB_PORT DB_USER DB_PASSWORD

# ── Tenant migrations ──

.PHONY: db-migrate
db-migrate: ## Apply all pending tenant migrations
	DB_NAME=$(TENANT_DB) ./flyway.sh migrate tenant

.PHONY: db-status
db-status: ## Show tenant migration status
	DB_NAME=$(TENANT_DB) ./flyway.sh status tenant

.PHONY: db-validate
db-validate: ## Validate all tenant migrations applied
	DB_NAME=$(TENANT_DB) ./flyway.sh validate tenant

.PHONY: db-reset
db-reset: ## Drop and recreate tenant DB (DESTRUCTIVE)
	DB_NAME=$(TENANT_DB) ./flyway.sh reset tenant

# ── Platform migrations ──

.PHONY: db-migrate-platform
db-migrate-platform: ## Apply all pending platform migrations
	DB_NAME=$(PLATFORM_DB) ./flyway.sh migrate platform

.PHONY: db-status-platform
db-status-platform: ## Show platform migration status
	DB_NAME=$(PLATFORM_DB) ./flyway.sh status platform

.PHONY: db-reset-platform
db-reset-platform: ## Drop and recreate platform DB (DESTRUCTIVE)
	DB_NAME=$(PLATFORM_DB) ./flyway.sh reset platform

# ── Combined ──

.PHONY: db-init
db-init: ## Create databases and apply all migrations + seed data
	@echo "=== Creating databases if needed ==="
	@PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres -c "SELECT 1 FROM pg_database WHERE datname = '$(TENANT_DB)'" | grep -q 1 || \
		PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres -c "CREATE DATABASE $(TENANT_DB) OWNER $(DB_USER);"
	@PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres -c "SELECT 1 FROM pg_database WHERE datname = '$(PLATFORM_DB)'" | grep -q 1 || \
		PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres -c "CREATE DATABASE $(PLATFORM_DB) OWNER $(DB_USER);"
	@$(MAKE) db-migrate
	@$(MAKE) db-migrate-platform
	@echo ""
	@echo "=== Database initialisation complete ==="

.PHONY: db-reset-all
db-reset-all: db-reset db-reset-platform ## Reset both databases (DESTRUCTIVE)

# ── Fly.io ──

.PHONY: fly-migrate
fly-migrate: ## Run tenant migrations on Fly.io
	fly ssh console -C "/app/flyway.sh migrate tenant"

.PHONY: fly-migrate-platform
fly-migrate-platform: ## Run platform migrations on Fly.io
	fly ssh console -C "/app/flyway.sh migrate platform"

.PHONY: fly-status
fly-status: ## Show migration status on Fly.io
	fly ssh console -C "/app/flyway.sh status tenant"

# ── LSMB legacy artifact migration tracking (R-0054, A-0030, T-0028) ──

.PHONY: lsmb-lint
lsmb-lint: ## Run the LSMB legacy artifact CI guardrail (block new triggers/functions in migrations)
	cd cmd/lsmb-lint && go run . --paths=../../migrations/tenant,../../migrations/platform,../../tenant,../../platform

.PHONY: lsmb-audit
lsmb-audit: ## Show LSMB migration progress summary (status counts + completeness %)
	cd cmd/lsmb-lint && go run . --audit \
		--inventory=../../../ledgius-specs/domains/architecture/migration-safety/lsmb_inventory.md

.PHONY: lsmb-audit-db
lsmb-audit-db: ## Run the SQL audit query against the live DB (lists all triggers + functions present)
	PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(TENANT_DB) -f scripts/lsmb_inventory_audit.sql

# ── Help ──

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
