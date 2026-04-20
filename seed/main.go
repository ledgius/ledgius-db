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
	"strings"

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

// tenantsFile supports datasets that define multiple tenants with
// per-tenant user memberships (e.g. test-tenants dataset).
type tenantsFile struct {
	Tenants []tenantEntry `yaml:"tenants"`
}

type tenantEntry struct {
	Slug         string             `yaml:"slug"`
	DisplayName  string             `yaml:"display_name"`
	BusinessType string             `yaml:"business_type"`
	IsTest       bool               `yaml:"is_test"`
	BillingState string             `yaml:"billing_state"`
	BillingCity  string             `yaml:"billing_city"`
	Users        []tenantUserEntry  `yaml:"users"`
}

type tenantUserEntry struct {
	Email string `yaml:"email"`
	Role  string `yaml:"role"`
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
	tenantDB := flag.String("tenant-db",
		"host=localhost port=5436 user=ledgius password=ledgius_dev_password dbname=ledgius sslmode=disable",
		"Postgres DSN for the tenant database (for seeding contacts, invoices, bills)")
	skipTenant := flag.Bool("skip-tenant-data", false, "Skip tenant-side data seeding (contacts, invoices, bills)")
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
		multiTenant, err := load(ctx, db, logger, dir, *dataset, *tenantDBName)
		if err != nil {
			logger.Error("load", "error", err)
			os.Exit(1)
		}
		// Tenant-side data seeding only applies to single-tenant datasets
		// (e.g. looking-good) that have customers.yaml, etc. Multi-tenant
		// datasets (test-tenants) only seed platform-level records.
		if !multiTenant && !*skipTenant {
			if err := seedTenant(ctx, *tenantDB, dir, logger); err != nil {
				logger.Error("tenant seed", "error", err)
				os.Exit(1)
			}
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

func load(ctx context.Context, db *sql.DB, logger *slog.Logger, datasetDir, datasetSlug, tenantDBName string) (multiTenant bool, err error) {
	// Check for multi-tenant dataset (tenants.yaml).
	tenants, multiErr := readTenants(datasetDir)
	if multiErr == nil && len(tenants) > 0 {
		return true, loadMultiTenant(ctx, db, logger, datasetDir, tenants)
	}

	// Fall back to single-tenant mode (config.yaml + users.yaml).
	users, err := readUsers(datasetDir)
	if err != nil {
		return false, fmt.Errorf("read users: %w", err)
	}
	cfg, _ := readConfig(datasetDir) // best-effort; missing config tolerated

	displayName := datasetSlug
	if cfg.BusinessName != "" {
		displayName = cfg.BusinessName
	}

	// 1. Tenant — upsert by slug.
	tenantID, err := upsertTenant(ctx, db, datasetSlug, displayName, tenantDBName)
	if err != nil {
		return false, fmt.Errorf("upsert tenant: %w", err)
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
			return false, fmt.Errorf("upsert user %s: %w", u.Email, err)
		}
		if err := upsertMembership(ctx, db, userID, tenantID, defaultRole(u.Role)); err != nil {
			return false, fmt.Errorf("upsert membership for %s: %w", u.Email, err)
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
	return false, nil
}

// loadMultiTenant seeds multiple tenants from tenants.yaml, each with
// their own user memberships. Users must already exist (seeded from
// users.yaml or V1.12 migration).
func loadMultiTenant(ctx context.Context, db *sql.DB, logger *slog.Logger, datasetDir string, tenants []tenantEntry) error {
	// Seed users first (if users.yaml exists).
	users, err := readUsers(datasetDir)
	if err == nil {
		for _, u := range users {
			if u.Email == "" || u.Password == "" {
				continue
			}
			userID, err := upsertUser(ctx, db, u)
			if err != nil {
				return fmt.Errorf("upsert user %s: %w", u.Email, err)
			}
			logger.Info("user ready", "email", u.Email, "id", userID, "platform_admin", u.PlatformAdmin)
		}
	}

	// Seed each tenant.
	for i := range tenants {
		t := &tenants[i]
		if t.Slug == "" && t.DisplayName != "" {
			t.Slug = generateSlug(t.DisplayName)
			logger.Info("slug generated from display_name", "name", t.DisplayName, "slug", t.Slug)
		}
		if t.Slug == "" {
			continue
		}
		dbName := t.Slug // tenant DB name = slug
		tenantID, err := upsertTenantFull(ctx, db, *t, dbName)
		if err != nil {
			return fmt.Errorf("upsert tenant %s: %w", t.Slug, err)
		}
		logger.Info("tenant ready",
			"slug", t.Slug,
			"id", tenantID,
			"is_test", t.IsTest,
			"business_type", t.BusinessType)

		// Assign users to this tenant.
		for _, tu := range t.Users {
			userID, err := lookupUserByEmail(ctx, db, tu.Email)
			if err != nil {
				logger.Warn("user not found for tenant membership — seed the user first",
					"email", tu.Email, "tenant", t.Slug, "error", err)
				continue
			}
			if err := upsertMembership(ctx, db, userID, tenantID, defaultRole(tu.Role)); err != nil {
				return fmt.Errorf("membership %s→%s: %w", tu.Email, t.Slug, err)
			}
			logger.Info("membership ready", "email", tu.Email, "tenant", t.Slug, "role", defaultRole(tu.Role))
		}
	}

	fmt.Println()
	fmt.Printf("Seeded %d tenants. Tenant databases are NOT auto-created.\n", len(tenants))
	fmt.Println("Use the provisioning pipeline or manual DB creation for each tenant.")
	fmt.Println()
	return nil
}

// unload removes the tenant created by this dataset and any membership rows
// that reference it. Users are *not* removed because they may have been
// granted access to other tenants outside this dataset.
func unload(ctx context.Context, db *sql.DB, logger *slog.Logger, datasetSlug string) error {
	// Check for multi-tenant dataset.
	dir := resolveDatasetDir("", datasetSlug)
	tenants, err := readTenants(dir)
	if err == nil && len(tenants) > 0 {
		for _, t := range tenants {
			res, err := db.ExecContext(ctx, `DELETE FROM tenants WHERE slug = $1`, t.Slug)
			if err != nil {
				return fmt.Errorf("delete tenant %s: %w", t.Slug, err)
			}
			n, _ := res.RowsAffected()
			logger.Info("tenant removed", "slug", t.Slug, "rows", n)
		}
		return nil
	}

	// Single-tenant mode.
	res, err2 := db.ExecContext(ctx, `DELETE FROM tenants WHERE slug = $1`, datasetSlug)
	if err2 != nil {
		return fmt.Errorf("delete tenant: %w", err2)
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

func readTenants(dir string) ([]tenantEntry, error) {
	data, err := os.ReadFile(filepath.Join(dir, "tenants.yaml"))
	if err != nil {
		return nil, err
	}
	var f tenantsFile
	if err := yaml.Unmarshal(data, &f); err != nil {
		return nil, err
	}
	return f.Tenants, nil
}

func lookupUserByEmail(ctx context.Context, db *sql.DB, email string) (string, error) {
	var id string
	err := db.QueryRowContext(ctx, `SELECT id FROM users WHERE email = $1`, email).Scan(&id)
	return id, err
}

func upsertTenantFull(ctx context.Context, db *sql.DB, t tenantEntry, dbName string) (string, error) {
	id := uuid.New().String()
	row := db.QueryRowContext(ctx, `
		INSERT INTO tenants (id, slug, display_name, db_name, is_test, business_type, billing_state, billing_city)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (slug) DO UPDATE SET
			display_name = EXCLUDED.display_name,
			is_test = EXCLUDED.is_test,
			business_type = EXCLUDED.business_type,
			billing_state = EXCLUDED.billing_state,
			billing_city = EXCLUDED.billing_city,
			updated_at = now()
		RETURNING id
	`, id, t.Slug, t.DisplayName, dbName, t.IsTest, nullString(t.BusinessType), nullString(t.BillingState), nullString(t.BillingCity))
	var resID string
	if err := row.Scan(&resID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", db.QueryRowContext(ctx, `SELECT id FROM tenants WHERE slug = $1`, t.Slug).Scan(&resID)
		}
		return "", err
	}
	return resID, nil
}

func nullString(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
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

// generateSlug mirrors the canonical slug algorithm from ledgius-api/pkg/slug.
// Kept in sync manually. The authoritative implementation is pkg/slug.Generate().
// Rules: lowercase, hyphens for spaces, strip special chars, no stop-word removal,
// max 63 chars (PostgreSQL database name limit).
func generateSlug(name string) string {
	s := strings.ToLower(strings.TrimSpace(name))
	s = strings.NewReplacer(
		" ", "-", "_", "-", "'", "", "'", "", "&", "", ".", "-",
	).Replace(s)
	// Strip non-alphanumeric/hyphen.
	var b strings.Builder
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' {
			b.WriteRune(r)
		}
	}
	s = b.String()
	// Collapse multi-hyphens and trim.
	for strings.Contains(s, "--") {
		s = strings.ReplaceAll(s, "--", "-")
	}
	s = strings.Trim(s, "-")
	if len(s) > 63 {
		s = s[:63]
	}
	return s
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
