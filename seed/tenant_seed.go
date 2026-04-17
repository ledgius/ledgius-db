// Spec references: R-0017 (§Domain Model Completeness), R-0041.
//
// Tenant-side seed runner. Reads from the YAML fixtures and populates
// the tenant database with contacts (+ V1.33 channels/addresses),
// invoices (+ V1.34 line FKs, V1.35 document_type), and bills.
//
// Separated from main.go because it connects to the tenant DB (ledgius)
// not the platform DB (ledgius_platform).

package main

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"math/rand"
	"os"
	"path/filepath"
	"time"

	"gopkg.in/yaml.v3"
)

type tenantConfig struct {
	BusinessName        string  `yaml:"business_name"`
	PeriodDays          int     `yaml:"period_days"`
	Currency            string  `yaml:"currency"`
	GSTRate             float64 `yaml:"gst_rate"`
	InvoicePaymentTerms int     `yaml:"invoice_payment_terms"`
	BillPaymentTerms    int     `yaml:"bill_payment_terms"`
	ReferencePrefix     string  `yaml:"reference_prefix"`
	RandomSeed          int64   `yaml:"random_seed"`
}

type customersYAML struct {
	Customers []customerEntry `yaml:"customers"`
}
type customerEntry struct {
	Name        string        `yaml:"name"`
	Email       string        `yaml:"email"`
	PhoneMobile string        `yaml:"phone_mobile"`
	Address     *addressEntry `yaml:"address"`
}
type addressEntry struct {
	LineOne  string `yaml:"line_one"`
	City     string `yaml:"city"`
	State    string `yaml:"state"`
	Postcode string `yaml:"postcode"`
}

type vendorsYAML struct {
	Vendors []vendorYAMLEntry `yaml:"vendors"`
}
type vendorYAMLEntry struct {
	Name        string        `yaml:"name"`
	Code        string        `yaml:"code"`
	Email       string        `yaml:"email"`
	PhoneOffice string        `yaml:"phone_office"`
	Address     *addressEntry `yaml:"address"`
}

type servicesYAML struct {
	Services []serviceYAMLEntry `yaml:"services"`
}
type serviceYAMLEntry struct {
	Name     string  `yaml:"name"`
	MinPrice float64 `yaml:"min_price"`
	MaxPrice float64 `yaml:"max_price"`
}

type expensesYAML struct {
	Expenses []expenseYAMLEntry `yaml:"expenses"`
}
type expenseYAMLEntry struct {
	Description   string  `yaml:"description"`
	Vendor        string  `yaml:"vendor"`
	MinAmount     float64 `yaml:"min_amount"`
	MaxAmount     float64 `yaml:"max_amount"`
	FrequencyDays int     `yaml:"frequency_days"`
	Account       string  `yaml:"account"`
}

// seedTenant loads the YAML fixtures and populates the tenant database.
func seedTenant(ctx context.Context, tenantDSN, datasetDir string, logger *slog.Logger) error {
	db, err := sql.Open("postgres", tenantDSN)
	if err != nil {
		return fmt.Errorf("connect tenant db: %w", err)
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		return fmt.Errorf("ping tenant db: %w", err)
	}

	var cfg tenantConfig
	readYAMLFile(filepath.Join(datasetDir, "config.yaml"), &cfg)
	if cfg.ReferencePrefix == "" {
		cfg.ReferencePrefix = "LG"
	}
	if cfg.PeriodDays == 0 {
		cfg.PeriodDays = 90
	}
	if cfg.GSTRate == 0 {
		cfg.GSTRate = 0.10
	}
	if cfg.InvoicePaymentTerms == 0 {
		cfg.InvoicePaymentTerms = 30
	}
	if cfg.BillPaymentTerms == 0 {
		cfg.BillPaymentTerms = 30
	}

	var countryID int
	db.QueryRowContext(ctx, "SELECT id FROM country WHERE short_name ILIKE 'au'").Scan(&countryID)
	if countryID == 0 {
		db.QueryRowContext(ctx, "SELECT id FROM country LIMIT 1").Scan(&countryID)
	}

	lookup := func(accno string) int {
		var id int
		db.QueryRowContext(ctx, "SELECT id FROM account WHERE accno = $1", accno).Scan(&id)
		return id
	}

	arAccountID := lookup("1100")
	apAccountID := lookup("2100")
	gstCollectedID := lookup("2200")
	gstPaidID := lookup("1200")
	servicesRevenueID := lookup("4020")

	if arAccountID == 0 || apAccountID == 0 {
		return fmt.Errorf("required accounts not found — ensure AU chart of accounts is loaded")
	}

	var gstTaxCodeID int
	db.QueryRowContext(ctx, "SELECT id FROM tax_code WHERE code = 'GST' LIMIT 1").Scan(&gstTaxCodeID)

	prefix := cfg.ReferencePrefix

	// Seed customers
	var cust customersYAML
	if err := readYAMLFile(filepath.Join(datasetDir, "customers.yaml"), &cust); err != nil {
		return fmt.Errorf("read customers.yaml: %w", err)
	}
	type contactRef struct{ entityID, ecaID int }
	customers := make([]contactRef, 0, len(cust.Customers))
	for i, c := range cust.Customers {
		metaNumber := fmt.Sprintf("%s-CUST-%03d", prefix, i+1)
		eID, ecaID := seedTenantContact(ctx, db, countryID, c.Name, metaNumber, 2, arAccountID, c.Email, c.PhoneMobile, "", c.Address)
		if ecaID > 0 {
			customers = append(customers, contactRef{eID, ecaID})
		}
	}
	logger.Info("customers seeded", "count", len(customers))

	// Seed vendors
	var vend vendorsYAML
	if err := readYAMLFile(filepath.Join(datasetDir, "vendors.yaml"), &vend); err != nil {
		return fmt.Errorf("read vendors.yaml: %w", err)
	}
	vendorMap := make(map[string]contactRef, len(vend.Vendors))
	for _, v := range vend.Vendors {
		metaNumber := prefix + "-" + v.Code
		eID, ecaID := seedTenantContact(ctx, db, countryID, v.Name, metaNumber, 1, apAccountID, v.Email, "", v.PhoneOffice, v.Address)
		if ecaID > 0 {
			vendorMap[v.Code] = contactRef{eID, ecaID}
		}
	}
	logger.Info("vendors seeded", "count", len(vendorMap))

	// Seed invoices from services
	var svc servicesYAML
	readYAMLFile(filepath.Join(datasetDir, "services.yaml"), &svc)
	rng := rand.New(rand.NewSource(cfg.RandomSeed))
	startDate := time.Now().AddDate(0, 0, -cfg.PeriodDays)
	invoiceCount := 0

	for day := 0; day < cfg.PeriodDays; day++ {
		date := startDate.AddDate(0, 0, day)
		if len(svc.Services) == 0 || len(customers) == 0 {
			break
		}
		servicesPerDay := 1 + rng.Intn(2)
		for s := 0; s < servicesPerDay; s++ {
			invoiceCount++
			svcDef := svc.Services[rng.Intn(len(svc.Services))]
			price := svcDef.MinPrice + rng.Float64()*(svcDef.MaxPrice-svcDef.MinPrice)
			price = float64(int(price*100)) / 100
			customer := customers[rng.Intn(len(customers))]
			invNumber := fmt.Sprintf("%s-INV-%04d", prefix, invoiceCount)
			seedTenantInvoice(ctx, db, invNumber, date, customer.ecaID, arAccountID, servicesRevenueID, gstCollectedID, gstTaxCodeID, price, svcDef.Name, cfg.GSTRate, cfg.InvoicePaymentTerms)
		}
	}
	logger.Info("invoices seeded", "count", invoiceCount)

	// Seed bills from expenses
	var exp expensesYAML
	readYAMLFile(filepath.Join(datasetDir, "expenses.yaml"), &exp)
	billCount := 0

	for _, e := range exp.Expenses {
		vendor, ok := vendorMap[e.Vendor]
		if !ok {
			continue
		}
		expAccountID := lookup(e.Account)
		if expAccountID == 0 {
			expAccountID = lookup("5010")
		}
		if e.FrequencyDays == 0 {
			billCount++
			date := startDate.AddDate(0, 0, rng.Intn(cfg.PeriodDays))
			amount := e.MinAmount + rng.Float64()*(e.MaxAmount-e.MinAmount)
			amount = float64(int(amount*100)) / 100
			billNumber := fmt.Sprintf("%s-BILL-%04d", prefix, billCount)
			seedTenantBill(ctx, db, billNumber, date, vendor.ecaID, apAccountID, expAccountID, gstPaidID, gstTaxCodeID, amount, e.Description, cfg.GSTRate, cfg.BillPaymentTerms)
		} else {
			for day := 0; day < cfg.PeriodDays; day += e.FrequencyDays {
				billCount++
				date := startDate.AddDate(0, 0, day+rng.Intn(5))
				amount := e.MinAmount + rng.Float64()*(e.MaxAmount-e.MinAmount)
				amount = float64(int(amount*100)) / 100
				billNumber := fmt.Sprintf("%s-BILL-%04d", prefix, billCount)
				seedTenantBill(ctx, db, billNumber, date, vendor.ecaID, apAccountID, expAccountID, gstPaidID, gstTaxCodeID, amount, e.Description, cfg.GSTRate, cfg.BillPaymentTerms)
			}
		}
	}
	logger.Info("bills seeded", "count", billCount)

	logger.Info("tenant seed complete",
		"customers", len(customers),
		"vendors", len(vendorMap),
		"invoices", invoiceCount,
		"bills", billCount)
	return nil
}

func seedTenantContact(ctx context.Context, db *sql.DB, countryID int, name, metaNumber string, entityClass, arapAccountID int, email, phoneMobile, phoneOffice string, addr *addressEntry) (int, int) {
	var entityID int
	db.QueryRowContext(ctx, `INSERT INTO entity (name, country_id, control_code) VALUES ($1, $2, $3) ON CONFLICT (control_code) DO NOTHING RETURNING id`, name, countryID, metaNumber).Scan(&entityID)
	if entityID == 0 {
		db.QueryRowContext(ctx, `SELECT id FROM entity WHERE control_code = $1`, metaNumber).Scan(&entityID)
	}
	if entityID == 0 {
		return 0, 0
	}
	db.ExecContext(ctx, `INSERT INTO company (entity_id, legal_name) VALUES ($1, $2) ON CONFLICT DO NOTHING`, entityID, name)
	db.ExecContext(ctx, `INSERT INTO entity_credit_account (entity_id, entity_class, meta_number, curr, ar_ap_account_id) VALUES ($1, $2, $3, 'AUD', $4) ON CONFLICT DO NOTHING`, entityID, entityClass, metaNumber, arapAccountID)
	var ecaID int
	db.QueryRowContext(ctx, `SELECT id FROM entity_credit_account WHERE meta_number = $1`, metaNumber).Scan(&ecaID)
	if ecaID == 0 {
		return entityID, 0
	}

	if email != "" {
		db.ExecContext(ctx, `INSERT INTO contact (entity_credit_account_id, contact_class, value, is_primary) VALUES ($1, 'email', $2, true) ON CONFLICT DO NOTHING`, ecaID, email)
	}
	if phoneMobile != "" {
		db.ExecContext(ctx, `INSERT INTO contact (entity_credit_account_id, contact_class, value, is_primary) VALUES ($1, 'phone_mobile', $2, true) ON CONFLICT DO NOTHING`, ecaID, phoneMobile)
	}
	if phoneOffice != "" {
		db.ExecContext(ctx, `INSERT INTO contact (entity_credit_account_id, contact_class, value, is_primary) VALUES ($1, 'phone_office', $2, true) ON CONFLICT DO NOTHING`, ecaID, phoneOffice)
	}
	if addr != nil && addr.LineOne != "" {
		var locID int
		db.QueryRowContext(ctx, `INSERT INTO location (line_one, city, state, country_id, mail_code) VALUES ($1, $2, $3, $4, $5) RETURNING id`, addr.LineOne, addr.City, addr.State, countryID, addr.Postcode).Scan(&locID)
		if locID > 0 {
			db.ExecContext(ctx, `INSERT INTO eca_to_location (entity_credit_account_id, location_id, location_class_id, is_primary) VALUES ($1, $2, 1, true) ON CONFLICT DO NOTHING`, ecaID, locID)
		}
	}
	return entityID, ecaID
}

func seedTenantInvoice(ctx context.Context, db *sql.DB, invNumber string, transDate time.Time, customerECAID, arAccountID, revenueAccountID, gstAccountID, gstTaxCodeID int, netAmount float64, description string, gstRate float64, paymentTermsDays int) {
	net := netAmount
	gst := net * gstRate
	gross := net + gst
	dueDate := transDate.AddDate(0, 0, paymentTermsDays)

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()

	tx.ExecContext(ctx, `INSERT INTO open_item (item_number, item_type, account_id) VALUES ($1, 'ar', $2) ON CONFLICT DO NOTHING`, invNumber, arAccountID)
	var openItemID int
	tx.QueryRowContext(ctx, `SELECT id FROM open_item WHERE item_number = $1`, invNumber).Scan(&openItemID)
	if openItemID == 0 {
		return
	}
	tx.ExecContext(ctx, `INSERT INTO transactions (table_name, approved, transdate, reference, description, trans_type_code) VALUES ('ar', true, $1, $2, $3, 'ar')`, transDate, invNumber, description)
	var transID int
	tx.QueryRowContext(ctx, `SELECT id FROM transactions WHERE reference = $1 AND table_name = 'ar' ORDER BY id DESC LIMIT 1`, invNumber).Scan(&transID)
	tx.ExecContext(ctx, `INSERT INTO ar (trans_id, invnumber, invoice, curr, entity_credit_account, amount_bc, amount_tc, netamount_bc, netamount_tc, open_item_id, duedate, document_type) VALUES ($1, $2, true, 'AUD', $3, $4, $4, $5, $5, $6, $7, 'invoice')`,
		transID, invNumber, customerECAID, gross, net, openItemID, dueDate)
	if gstTaxCodeID > 0 {
		tx.ExecContext(ctx, `INSERT INTO invoice (trans_id, description, qty, allocated, sellprice, account_id, tax_id) VALUES ($1, $2, 1, 0, $3, $4, $5)`, transID, description, net, revenueAccountID, gstTaxCodeID)
	} else {
		tx.ExecContext(ctx, `INSERT INTO invoice (trans_id, description, qty, allocated, sellprice, account_id) VALUES ($1, $2, 1, 0, $3, $4)`, transID, description, net, revenueAccountID)
	}
	tx.ExecContext(ctx, `INSERT INTO acc_trans (trans_id, chart_id, transdate, amount_bc, amount_tc, curr, approved, open_item_id) VALUES ($1, $2, $3, $4, $4, 'AUD', true, $5)`, transID, arAccountID, transDate, gross, openItemID)
	tx.ExecContext(ctx, `INSERT INTO acc_trans (trans_id, chart_id, transdate, amount_bc, amount_tc, curr, approved) VALUES ($1, $2, $3, $4, $4, 'AUD', true)`, transID, revenueAccountID, transDate, -net)
	tx.ExecContext(ctx, `INSERT INTO acc_trans (trans_id, chart_id, transdate, amount_bc, amount_tc, curr, approved) VALUES ($1, $2, $3, $4, $4, 'AUD', true)`, transID, gstAccountID, transDate, -gst)
	tx.Commit()
}

func seedTenantBill(ctx context.Context, db *sql.DB, billNumber string, transDate time.Time, vendorECAID, apAccountID, expenseAccountID, gstPaidAccountID, gstTaxCodeID int, netAmount float64, description string, gstRate float64, paymentTermsDays int) {
	net := netAmount
	gst := net * gstRate
	gross := net + gst
	dueDate := transDate.AddDate(0, 0, paymentTermsDays)

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()

	tx.ExecContext(ctx, `INSERT INTO open_item (item_number, item_type, account_id) VALUES ($1, 'ap', $2) ON CONFLICT DO NOTHING`, billNumber, apAccountID)
	var openItemID int
	tx.QueryRowContext(ctx, `SELECT id FROM open_item WHERE item_number = $1`, billNumber).Scan(&openItemID)
	if openItemID == 0 {
		return
	}
	tx.ExecContext(ctx, `INSERT INTO transactions (table_name, approved, transdate, reference, description, trans_type_code) VALUES ('ap', true, $1, $2, $3, 'ap')`, transDate, billNumber, description)
	var transID int
	tx.QueryRowContext(ctx, `SELECT id FROM transactions WHERE reference = $1 AND table_name = 'ap' ORDER BY id DESC LIMIT 1`, billNumber).Scan(&transID)
	tx.ExecContext(ctx, `INSERT INTO ap (trans_id, invnumber, invoice, curr, entity_credit_account, amount_bc, amount_tc, netamount_bc, netamount_tc, open_item_id, duedate, document_type) VALUES ($1, $2, true, 'AUD', $3, $4, $4, $5, $5, $6, $7, 'invoice')`,
		transID, billNumber, vendorECAID, gross, net, openItemID, dueDate)
	if gstTaxCodeID > 0 {
		tx.ExecContext(ctx, `INSERT INTO invoice (trans_id, description, qty, allocated, sellprice, account_id, tax_id) VALUES ($1, $2, 1, 0, $3, $4, $5)`, transID, description, net, expenseAccountID, gstTaxCodeID)
	} else {
		tx.ExecContext(ctx, `INSERT INTO invoice (trans_id, description, qty, allocated, sellprice, account_id) VALUES ($1, $2, 1, 0, $3, $4)`, transID, description, net, expenseAccountID)
	}
	tx.ExecContext(ctx, `INSERT INTO acc_trans (trans_id, chart_id, transdate, amount_bc, amount_tc, curr, approved, open_item_id) VALUES ($1, $2, $3, $4, $4, 'AUD', true, $5)`, transID, apAccountID, transDate, -gross, openItemID)
	tx.ExecContext(ctx, `INSERT INTO acc_trans (trans_id, chart_id, transdate, amount_bc, amount_tc, curr, approved) VALUES ($1, $2, $3, $4, $4, 'AUD', true)`, transID, expenseAccountID, transDate, net)
	tx.ExecContext(ctx, `INSERT INTO acc_trans (trans_id, chart_id, transdate, amount_bc, amount_tc, curr, approved) VALUES ($1, $2, $3, $4, $4, 'AUD', true)`, transID, gstPaidAccountID, transDate, gst)
	tx.Commit()
}

func parseAmount(s interface{}) float64 {
	switch v := s.(type) {
	case float64:
		return v
	case string:
		var f float64
		fmt.Sscanf(v, "%f", &f)
		return f
	default:
		return 0
	}
}

func readYAMLFile(path string, out interface{}) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return yaml.Unmarshal(data, out)
}
