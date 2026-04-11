package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log/slog"
	"os"

	_ "github.com/lib/pq"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"

	"github.com/mattdbush/ledgius/api/internal/platform"
	"github.com/mattdbush/ledgius/api/pkg/config"
)

func main() {
	runPlatform := flag.Bool("platform", false, "Run platform migrations")
	runTenant := flag.String("tenant-id", "", "Run tenant migrations for a specific tenant")
	runAllTenants := flag.Bool("all-tenants", false, "Run tenant migrations for all active tenants")
	migrationsBase := flag.String("dir", "migrations", "Base migrations directory")
	flag.Parse()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	cfg := config.Load()

	if !*runPlatform && *runTenant == "" && !*runAllTenants {
		fmt.Println("Usage:")
		fmt.Println("  ledgius-migrate --platform              Run platform DB migrations")
		fmt.Println("  ledgius-migrate --tenant-id=UUID         Run tenant DB migrations for one tenant")
		fmt.Println("  ledgius-migrate --all-tenants            Run tenant DB migrations for all active tenants")
		fmt.Println("  ledgius-migrate --dir=path               Base migrations directory (default: migrations)")
		os.Exit(1)
	}

	if *runPlatform {
		logger.Info("running platform migrations")
		dsn := cfg.PlatformDB.DSN()
		db, err := sql.Open("postgres", dsn)
		if err != nil {
			logger.Error("connect to platform DB", "error", err)
			os.Exit(1)
		}
		defer db.Close()

		dir := *migrationsBase + "/platform"
		if err := platform.RunMigrationsOnDB(db, dir); err != nil {
			logger.Error("platform migrations failed", "error", err)
			os.Exit(1)
		}
		logger.Info("platform migrations complete")
	}

	if *runTenant != "" {
		logger.Info("running tenant migrations", "tenant_id", *runTenant)
		if err := migrateOneTenant(cfg, *runTenant, *migrationsBase, logger); err != nil {
			logger.Error("tenant migrations failed", "tenant_id", *runTenant, "error", err)
			os.Exit(1)
		}
		logger.Info("tenant migrations complete", "tenant_id", *runTenant)
	}

	if *runAllTenants {
		logger.Info("running tenant migrations for all active tenants")
		if err := migrateAllTenants(cfg, *migrationsBase, logger); err != nil {
			logger.Error("all-tenants migrations failed", "error", err)
			os.Exit(1)
		}
	}
}

func migrateOneTenant(cfg config.Config, tenantID, migrationsBase string, logger *slog.Logger) error {
	gormCfg := &gorm.Config{Logger: gormlogger.Default.LogMode(gormlogger.Warn)}
	platformDB, err := gorm.Open(postgres.Open(cfg.PlatformDB.DSN()), gormCfg)
	if err != nil {
		return fmt.Errorf("connect to platform DB: %w", err)
	}

	repo := platform.NewRepository(platformDB)
	t, err := repo.GetTenantByID(nil, tenantID)
	if err != nil {
		return fmt.Errorf("tenant not found: %w", err)
	}

	return migrateTenantDB(cfg, t, migrationsBase, logger)
}

func migrateAllTenants(cfg config.Config, migrationsBase string, logger *slog.Logger) error {
	gormCfg := &gorm.Config{Logger: gormlogger.Default.LogMode(gormlogger.Warn)}
	platformDB, err := gorm.Open(postgres.Open(cfg.PlatformDB.DSN()), gormCfg)
	if err != nil {
		return fmt.Errorf("connect to platform DB: %w", err)
	}

	repo := platform.NewRepository(platformDB)
	tenants, err := repo.ListActiveTenants(nil)
	if err != nil {
		return fmt.Errorf("list tenants: %w", err)
	}

	logger.Info("found active tenants", "count", len(tenants))

	var failures int
	for _, t := range tenants {
		logger.Info("migrating tenant", "tenant_id", t.ID, "slug", t.Slug, "db", t.DBName)
		if err := migrateTenantDB(cfg, &t, migrationsBase, logger); err != nil {
			logger.Error("tenant migration failed", "tenant_id", t.ID, "slug", t.Slug, "error", err)
			failures++
			continue
		}
		logger.Info("tenant migration complete", "tenant_id", t.ID, "slug", t.Slug)
	}

	if failures > 0 {
		return fmt.Errorf("%d of %d tenant migrations failed", failures, len(tenants))
	}
	return nil
}

func migrateTenantDB(cfg config.Config, t *platform.Tenant, migrationsBase string, logger *slog.Logger) error {
	dsn := fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		t.DBHost, t.DBPort,
		cfg.LedgiusDB.User, cfg.LedgiusDB.Password,
		t.DBName, cfg.LedgiusDB.SSLMode,
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return fmt.Errorf("connect to %s: %w", t.DBName, err)
	}
	defer db.Close()

	dir := migrationsBase + "/tenant"
	return platform.RunMigrationsOnDB(db, dir)
}
