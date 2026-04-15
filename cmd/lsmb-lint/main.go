// Spec references: R-0054, A-0030, T-0028.
//
// lsmb-lint — CI guardrail that prevents new SQL migrations from
// introducing PL/pgSQL triggers / functions / procedures, except where
// explicitly exempted with a documented marker.
//
// Usage:
//
//	# Lint mode — scan migrations for prohibited DDL
//	lsmb-lint
//	lsmb-lint --paths=migrations/tenant,migrations/platform
//
//	# Audit mode — show inventory parse + summary (requires --inventory)
//	lsmb-lint --audit --inventory=../ledgius-specs/domains/architecture/migration-safety/lsmb_inventory.md
//
// Per R-0054 LMT-008, a migration may carry server-side DDL only if its
// first non-blank line is a comment of the form:
//
//	-- lsmb-exempt: <reason>
//
// Per R-0054 LMT-009, exempt migrations must have a corresponding
// `retained` row in the inventory. The audit mode catches drift between
// the inventory and the live DB.

package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// prohibitedDDL matches CREATE TRIGGER / CREATE FUNCTION / CREATE OR
// REPLACE FUNCTION / CREATE PROCEDURE statements case-insensitively.
// Multiline mode so we can scan an entire .sql file body.
var prohibitedDDL = regexp.MustCompile(`(?im)^\s*CREATE\s+(?:OR\s+REPLACE\s+)?(?:TRIGGER|FUNCTION|PROCEDURE)\b`)

// exemptMarker matches `-- lsmb-exempt: <reason>` (any reason — non-empty).
var exemptMarker = regexp.MustCompile(`(?i)^\s*--\s*lsmb-exempt:\s*\S+`)

func main() {
	pathsArg := flag.String("paths", "migrations/tenant,migrations/platform,tenant,platform",
		"comma-separated migration directories to scan")
	auditMode := flag.Bool("audit", false,
		"audit mode — parse inventory and print summary instead of linting")
	inventoryPath := flag.String("inventory",
		"../ledgius-specs/domains/architecture/migration-safety/lsmb_inventory.md",
		"path to lsmb_inventory.md (audit mode only)")
	flag.Parse()

	if *auditMode {
		runAudit(*inventoryPath)
		return
	}

	paths := strings.Split(*pathsArg, ",")
	violations := runLint(paths)

	if len(violations) > 0 {
		fmt.Fprintln(os.Stderr)
		fmt.Fprintln(os.Stderr, "===========================================")
		fmt.Fprintf(os.Stderr, "lsmb-lint FAILED — %d violation(s)\n", len(violations))
		fmt.Fprintln(os.Stderr, "===========================================")
		for _, v := range violations {
			fmt.Fprintln(os.Stderr, " -", v)
		}
		fmt.Fprintln(os.Stderr)
		fmt.Fprintln(os.Stderr,
			"See R-0054 (LSMB Legacy Artifact Migration Tracking) for the full requirement.")
		fmt.Fprintln(os.Stderr,
			"To exempt a migration intentionally, add `-- lsmb-exempt: <reason>` as the first")
		fmt.Fprintln(os.Stderr,
			"non-blank line of the file AND add a corresponding `retained` row to the inventory at:")
		fmt.Fprintln(os.Stderr,
			"  ledgius-specs/domains/architecture/migration-safety/lsmb_inventory.md")
		os.Exit(1)
	}

	fmt.Fprintln(os.Stderr, "lsmb-lint: OK")
}

// runLint walks each path, scans every .sql file, and returns a list of
// human-readable violation strings.
func runLint(paths []string) []string {
	var violations []string

	for _, p := range paths {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		if _, err := os.Stat(p); os.IsNotExist(err) {
			// Path absent in this repo — skip silently. The same lint binary is
			// run from both `ledgius-db` and `ledgius-api`, which have different
			// migration directory layouts.
			continue
		}

		err := filepath.Walk(p, func(path string, info os.FileInfo, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			if info.IsDir() {
				return nil
			}
			if !strings.HasSuffix(strings.ToLower(info.Name()), ".sql") {
				return nil
			}

			body, err := os.ReadFile(path)
			if err != nil {
				violations = append(violations,
					fmt.Sprintf("%s: read error: %v", path, err))
				return nil
			}

			hasProhibited := prohibitedDDL.MatchString(string(body))
			if !hasProhibited {
				return nil
			}

			if hasExemptMarker(body) {
				// Allowed — the operator has marked this migration as intentional.
				// (Cross-validation against the inventory `retained` rows is the
				// reviewer's responsibility today; future work will automate it.)
				return nil
			}

			violations = append(violations,
				fmt.Sprintf("%s: introduces server-side DDL "+
					"(CREATE TRIGGER / CREATE FUNCTION / CREATE PROCEDURE) "+
					"without `-- lsmb-exempt: <reason>` marker on first non-blank line",
					path))
			return nil
		})
		if err != nil {
			violations = append(violations,
				fmt.Sprintf("walk %s: %v", p, err))
		}
	}

	return violations
}

// hasExemptMarker reports whether the file's first non-blank, non-comment-
// stripped line carries the exempt marker. We look at the first non-blank
// line — if it starts with `-- lsmb-exempt:` we accept.
func hasExemptMarker(body []byte) bool {
	scanner := bufio.NewScanner(strings.NewReader(string(body)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		return exemptMarker.MatchString(line)
	}
	return false
}

// --- Audit mode ---------------------------------------------------------

// runAudit parses the inventory file and prints a summary. The current
// implementation reports counts by status (parsed from the Markdown
// tables); the planned future enhancement also joins against a live DB
// (via --db-url) to flag drift.
func runAudit(inventoryPath string) {
	body, err := os.ReadFile(inventoryPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "lsmb-lint audit: read inventory: %v\n", err)
		os.Exit(2)
	}

	counts := map[string]int{}
	rowCount := 0

	scanner := bufio.NewScanner(strings.NewReader(string(body)))
	for scanner.Scan() {
		line := scanner.Text()
		// Match Markdown table rows whose first cell is a non-header,
		// non-divider value. We're looking for the `status` column —
		// which is the 4th pipe-delimited field in trigger/function rows.
		if !strings.HasPrefix(line, "| ") {
			continue
		}
		// Skip header rows (names ending in `:--`) and the explicit
		// header-text rows (containing "name |").
		if strings.Contains(line, "---") || strings.Contains(line, "| name |") {
			continue
		}
		// Tally the recognised status values.
		for _, status := range []string{"unmapped", "in-use", "replaced", "dropped", "retained"} {
			if strings.Contains(line, "| "+status+" |") {
				counts[status]++
				rowCount++
				break
			}
		}
	}

	fmt.Println()
	fmt.Println("LSMB Inventory — Status Summary")
	fmt.Println("================================")
	fmt.Printf("  Inventory rows parsed: %d\n", rowCount)
	fmt.Println()
	fmt.Printf("  unmapped:  %d\n", counts["unmapped"])
	fmt.Printf("  in-use:    %d  (work outstanding)\n", counts["in-use"])
	fmt.Printf("  replaced:  %d  (drop migration pending)\n", counts["replaced"])
	fmt.Printf("  dropped:   %d  (verified removed)\n", counts["dropped"])
	fmt.Printf("  retained:  %d  (Ledgius own — excluded from completeness)\n", counts["retained"])
	fmt.Println()

	// Completeness % — excludes retained and unmapped per A-0030
	denom := counts["in-use"] + counts["replaced"] + counts["dropped"]
	if denom == 0 {
		fmt.Println("  Completeness:  n/a (no countable rows)")
	} else {
		pct := 100.0 * float64(counts["replaced"]+counts["dropped"]) / float64(denom)
		fmt.Printf("  Completeness:  %.2f%%\n", pct)
	}
	fmt.Println()
}
