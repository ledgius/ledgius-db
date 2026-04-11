package main

import (
	"flag"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"

	"github.com/mattdbush/ledgius/api/internal/fixtures"
	"github.com/mattdbush/ledgius/api/pkg/config"
)

func main() {
	dataset := flag.String("dataset", "", "Dataset directory name (e.g. looking-good)")
	action := flag.String("action", "load", "Action: load or unload")
	datasetsDir := flag.String("datasets-dir", "", "Path to datasets directory (default: auto-detect)")
	flag.Parse()

	if *dataset == "" {
		fmt.Println("Ledgius MDS Seed Tool")
		fmt.Println()
		fmt.Println("Usage:")
		fmt.Println("  go run ./cmd/seed/ --dataset=looking-good --action=load")
		fmt.Println("  go run ./cmd/seed/ --dataset=looking-good --action=unload")
		fmt.Println()
		fmt.Println("The dataset is a directory of YAML files under fixtures/datasets/.")
		fmt.Println("Edit the YAML files to customise the demo data — no coding required.")
		fmt.Println()
		fmt.Println("Files in each dataset:")
		fmt.Println("  config.yaml      Business name, period, currency, GST rate")
		fmt.Println("  services.yaml    Service catalogue with prices and durations")
		fmt.Println("  customers.yaml   Customer name list")
		fmt.Println("  vendors.yaml     Supplier names and codes")
		fmt.Println("  expenses.yaml    Expense items, amounts, frequencies")
		fmt.Println("  users.yaml       Demo user credentials and roles")
		fmt.Println()
		fmt.Println("Available datasets:")
		listDatasets()
		os.Exit(1)
	}

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	cfg := config.Load()

	db, err := gorm.Open(postgres.Open(cfg.LedgiusDB.DSN()), &gorm.Config{
		Logger: gormlogger.Default.LogMode(gormlogger.Silent),
	})
	if err != nil {
		logger.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}

	datasetDir := resolveDatasetDir(*datasetsDir, *dataset)
	if _, err := os.Stat(datasetDir); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "dataset directory not found: %s\n", datasetDir)
		os.Exit(1)
	}

	switch *action {
	case "load":
		if err := fixtures.SeedFromYAML(db, logger, datasetDir); err != nil {
			logger.Error("seed failed", "error", err)
			os.Exit(1)
		}
		fmt.Println()
		users, _ := fixtures.LoadDatasetUsers(datasetDir)
		if len(users) > 0 {
			fmt.Println("Demo users:")
			for _, u := range users {
				fmt.Printf("  %-35s password: %-12s (%s)\n", u.Email, u.Password, u.Role)
			}
		}
		fmt.Println()
		fmt.Printf("To remove: go run ./cmd/seed/ --dataset=%s --action=unload\n", *dataset)

	case "unload":
		prefix := readPrefix(datasetDir)
		if err := fixtures.UnloadByPrefix(db, logger, prefix); err != nil {
			logger.Error("unload failed", "error", err)
			os.Exit(1)
		}

	default:
		fmt.Fprintf(os.Stderr, "unknown action: %s (use load or unload)\n", *action)
		os.Exit(1)
	}
}

// readPrefix extracts reference_prefix from config.yaml for the unload operation.
func readPrefix(datasetDir string) string {
	type cfgPrefix struct {
		ReferencePrefix string `yaml:"reference_prefix"`
	}
	data, err := os.ReadFile(filepath.Join(datasetDir, "config.yaml"))
	if err != nil {
		return "LG" // fallback
	}
	var cp cfgPrefix
	if err := yaml.Unmarshal(data, &cp); err != nil || cp.ReferencePrefix == "" {
		return "LG"
	}
	return cp.ReferencePrefix
}

func resolveDatasetDir(base, name string) string {
	if base != "" {
		return filepath.Join(base, name)
	}
	candidates := []string{
		filepath.Join("fixtures", "datasets", name),
		filepath.Join("..", "fixtures", "datasets", name),
		filepath.Join("api", "fixtures", "datasets", name),
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return filepath.Join("fixtures", "datasets", name)
}

func listDatasets() {
	candidates := []string{
		filepath.Join("fixtures", "datasets"),
		filepath.Join("api", "fixtures", "datasets"),
	}
	for _, dir := range candidates {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() {
				cfgPath := filepath.Join(dir, e.Name(), "config.yaml")
				if _, err := os.Stat(cfgPath); err == nil {
					fmt.Printf("  %-20s %s\n", e.Name(), cfgPath)
				}
			}
		}
		return
	}
	fmt.Println("  (no datasets found)")
}
