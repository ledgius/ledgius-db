// Spec references: R-0041 (auth), R-0054 (LSMB tracking — pure-Go pattern).
//
// Ledgius DB seed runner.
//
// Loads platform-level seed data (users, tenants, tenant memberships)
// from a YAML dataset under fixtures/datasets/. Per project convention
// (see ~/.claude/.../project_seed_data_in_db_repo.md) seed code lives
// in ledgius-db, not ledgius-api.
//
// Usage:
//
//	# From ledgius-db root:
//	go run ./seed --dataset=looking-good --action=load
//	go run ./seed --dataset=looking-good --action=unload
//
//	# Or via Make:
//	make seed-load   DATASET=looking-good
//	make seed-unload DATASET=looking-good
//
// Idempotent: load can be run repeatedly without duplicating rows
// (uses ON CONFLICT DO UPDATE on email and slug uniqueness).
//
// What this runner currently seeds:
//   - ledgius_platform.users           (with bcrypt-hashed passwords)
//   - ledgius_platform.tenants         (one per dataset)
//   - ledgius_platform.tenant_memberships (one per user × tenant pair)
//
// What this runner does NOT yet seed (and what the legacy broken
// seed/main.go was attempting to do): tenant-side data such as
// services / customers / vendors / expenses. Those need their own
// SeedFromYAML implementation and tenant-DB connection — out of scope
// for the immediate "unblock local login" need.

package main

import (
	"context"
	"database/sql"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
	"gopkg.in/yaml.v3"
)

type usersFile struct {
	Users []userEntry `yaml:"users"`
}

type userEntry struct {
	Email         string `yaml:"email"`
	DisplayName   string `yaml:"display_name"`
	Password      string `yaml:"password"`
	Role          string `yaml:"role"`
	PlatformAdmin bool   `yaml:"platform_admin"`
}

type configFile struct {
	BusinessName string `yaml:"business_name"`
}

func main() {
	dataset := flag.String("dataset", "", "Dataset name under fixtures/datasets/")
	action := flag.String("action", "load", "Action: load or unload")
	datasetsDir := flag.String("datasets-dir", "", "Datasets directory (default: auto-detect)")
	platformDB := flag.String("platform-db",
		"host=localhost port=5436 user=ledgius password=ledgius_dev_password dbname=ledgius_platform sslmode=disable",
		"Postgres DSN for ledgius_platform")
	tenantDBName := flag.String("tenant-db-name", "ledgius",
		"Tenant database name to register the seeded tenant against")
	flag.Parse()

	if *dataset == "" {
		usage()
		os.Exit(1)
	}

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

	dir := resolveDatasetDir(*datasetsDir, *dataset)
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "dataset directory not found: %s\n", dir)
		os.Exit(1)
	}

	db, err := sql.Open("postgres", *platformDB)
	if err != nil {
		logger.Error("connect", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		logger.Error("ping", "error", err)
		os.Exit(1)
	}

	ctx := context.Background()

	switch *action {
	case "load":
		if err := load(ctx, db, logger, dir, *dataset, *tenantDBName); err != nil {
			logger.Error("load", "error", err)
			os.Exit(1)
		}
	case "unload":
		if err := unload(ctx, db, logger, *dataset); err != nil {
			logger.Error("unload", "error", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "unknown action: %s (use load or unload)\n", *action)
		os.Exit(1)
	}
}

func load(ctx context.Context, db *sql.DB, logger *slog.Logger, datasetDir, datasetSlug, tenantDBName string) error {
	users, err := readUsers(datasetDir)
	if err != nil {
		return fmt.Errorf("read users: %w", err)
	}
	cfg, _ := readConfig(datasetDir) // best-effort; missing config tolerated

	displayName := datasetSlug
	if cfg.BusinessName != "" {
		displayName = cfg.BusinessName
	}

	// 1. Tenant — upsert by slug.
	tenantID, err := upsertTenant(ctx, db, datasetSlug, displayName, tenantDBName)
	if err != nil {
		return fmt.Errorf("upsert tenant: %w", err)
	}
	logger.Info("tenant ready", "slug", datasetSlug, "id", tenantID, "db", tenantDBName)

	// 2. Users + memberships.
	for _, u := range users {
		if u.Email == "" || u.Password == "" {
			logger.Warn("skipping user (missing email or password)", "user", u)
			continue
		}
		userID, err := upsertUser(ctx, db, u)
		if err != nil {
			return fmt.Errorf("upsert user %s: %w", u.Email, err)
		}
		if err := upsertMembership(ctx, db, userID, tenantID, defaultRole(u.Role)); err != nil {
			return fmt.Errorf("upsert membership for %s: %w", u.Email, err)
		}
		logger.Info("user ready",
			"email", u.Email,
			"id", userID,
			"role", defaultRole(u.Role),
			"platform_admin", u.PlatformAdmin)
	}

	fmt.Println()
	fmt.Println("Demo users (use these to log in):")
	for _, u := range users {
		flag := ""
		if u.PlatformAdmin {
			flag = "  [platform admin]"
		}
		fmt.Printf("  %-35s password: %-12s role: %s%s\n",
			u.Email, u.Password, defaultRole(u.Role), flag)
	}
	fmt.Println()
	fmt.Printf("Tenant: %s (db: %s)\n", displayName, tenantDBName)
	fmt.Println()
	fmt.Printf("To remove: go run ./seed --dataset=%s --action=unload\n", datasetSlug)
	return nil
}

// unload removes the tenant created by this dataset and any membership rows
// that reference it. Users are *not* removed because they may have been
// granted access to other tenants outside this dataset.
func unload(ctx context.Context, db *sql.DB, logger *slog.Logger, datasetSlug string) error {
	res, err := db.ExecContext(ctx, `DELETE FROM tenants WHERE slug = $1`, datasetSlug)
	if err != nil {
		return fmt.Errorf("delete tenant: %w", err)
	}
	n, _ := res.RowsAffected()
	logger.Info("tenant removed", "slug", datasetSlug, "rows", n)
	// tenant_memberships is ON DELETE CASCADE → removed automatically.
	return nil
}

func readUsers(dir string) ([]userEntry, error) {
	data, err := os.ReadFile(filepath.Join(dir, "users.yaml"))
	if err != nil {
		return nil, err
	}
	var f usersFile
	if err := yaml.Unmarshal(data, &f); err != nil {
		return nil, err
	}
	return f.Users, nil
}

func readConfig(dir string) (configFile, error) {
	var c configFile
	data, err := os.ReadFile(filepath.Join(dir, "config.yaml"))
	if err != nil {
		return c, err
	}
	return c, yaml.Unmarshal(data, &c)
}

func upsertTenant(ctx context.Context, db *sql.DB, slug, displayName, dbName string) (string, error) {
	id := uuid.New().String()
	row := db.QueryRowContext(ctx, `
		INSERT INTO tenants (id, slug, display_name, db_name)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (slug) DO UPDATE SET display_name = EXCLUDED.display_name
		RETURNING id
	`, id, slug, displayName, dbName)
	var resID string
	if err := row.Scan(&resID); err != nil {
		// db_name is also UNIQUE — if it conflicts independently of slug,
		// fall back to a SELECT.
		if errors.Is(err, sql.ErrNoRows) {
			return "", db.QueryRowContext(ctx, `SELECT id FROM tenants WHERE slug = $1`, slug).Scan(&resID)
		}
		return "", err
	}
	return resID, nil
}

func upsertUser(ctx context.Context, db *sql.DB, u userEntry) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(u.Password), 10)
	if err != nil {
		return "", err
	}
	id := uuid.New().String()
	row := db.QueryRowContext(ctx, `
		INSERT INTO users (id, email, password_hash, display_name, is_platform_admin)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (email) DO UPDATE SET
			password_hash     = EXCLUDED.password_hash,
			display_name      = EXCLUDED.display_name,
			is_platform_admin = EXCLUDED.is_platform_admin,
			updated_at        = now()
		RETURNING id
	`, id, u.Email, string(hash), u.DisplayName, u.PlatformAdmin)
	var resID string
	return resID, row.Scan(&resID)
}

func upsertMembership(ctx context.Context, db *sql.DB, userID, tenantID, role string) error {
	_, err := db.ExecContext(ctx, `
		INSERT INTO tenant_memberships (id, user_id, tenant_id, role)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (user_id, tenant_id) DO UPDATE SET role = EXCLUDED.role, updated_at = now()
	`, uuid.New().String(), userID, tenantID, role)
	return err
}

func defaultRole(role string) string {
	switch role {
	case "owner", "master_accountant", "accountant", "bookkeeper", "viewer":
		return role
	default:
		return "viewer"
	}
}

func resolveDatasetDir(base, name string) string {
	if base != "" {
		return filepath.Join(base, name)
	}
	candidates := []string{
		filepath.Join("fixtures", "datasets", name),
		filepath.Join("..", "fixtures", "datasets", name),               // run from seed/
		filepath.Join("..", "ledgius-db", "fixtures", "datasets", name), // run from sibling repo
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return filepath.Join("fixtures", "datasets", name)
}

func usage() {
	fmt.Println(`Ledgius DB seed runner
Usage:
  go run ./seed --dataset=<name> --action=load
  go run ./seed --dataset=<name> --action=unload

Flags:
  --dataset         dataset name under fixtures/datasets/ (e.g. looking-good)
  --action          load (default) or unload
  --platform-db     Postgres DSN for ledgius_platform
                    (default: localhost:5436 ledgius/ledgius_dev_password)
  --tenant-db-name  tenant database name to register
                    (default: ledgius)`)
}
