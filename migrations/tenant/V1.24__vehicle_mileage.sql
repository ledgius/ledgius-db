-- Spec references: R-0051, A-0027.
-- Vehicle register and mileage tracking for ATO motor vehicle deductions.

CREATE TABLE IF NOT EXISTS vehicle (
    id                  SERIAL PRIMARY KEY,
    registration        TEXT NOT NULL,
    make                TEXT,
    model               TEXT,
    year                INT,
    colour              TEXT,
    fuel_type           TEXT DEFAULT 'petrol'
        CHECK (fuel_type IN ('petrol', 'diesel', 'electric', 'hybrid', 'lpg')),
    current_odometer    NUMERIC NOT NULL DEFAULT 0,
    is_default          BOOLEAN NOT NULL DEFAULT false,
    status              TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE vehicle IS 'Vehicles used for business purposes. Supports multiple vehicles per tenant.';
COMMENT ON COLUMN vehicle.registration IS 'Vehicle registration plate number, e.g. ABC-123';
COMMENT ON COLUMN vehicle.current_odometer IS 'Latest known odometer reading in km. Updated after each trip.';
COMMENT ON COLUMN vehicle.is_default IS 'Default vehicle for quick trip logging on mobile.';

-- ATO 12-week logbook periods.
CREATE TABLE IF NOT EXISTS logbook_period (
    id                  SERIAL PRIMARY KEY,
    vehicle_id          INT NOT NULL REFERENCES vehicle(id),
    start_date          DATE NOT NULL,
    end_date            DATE NOT NULL,
    status              TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'cancelled')),
    total_business_km   NUMERIC,
    total_personal_km   NUMERIC,
    total_km            NUMERIC,
    business_use_pct    NUMERIC,
    valid_until         DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE logbook_period IS 'ATO-compliant 12-week (84-day) logbook periods. Business-use percentage calculated on completion.';
COMMENT ON COLUMN logbook_period.business_use_pct IS 'Calculated: total_business_km / total_km * 100. Applied to vehicle running costs for deductions.';
COMMENT ON COLUMN logbook_period.valid_until IS 'ATO allows logbook to be used for up to 5 years. Default: start_date + 5 years.';

-- Individual trip records.
CREATE TABLE IF NOT EXISTS trip_log (
    id                  SERIAL PRIMARY KEY,
    vehicle_id          INT NOT NULL REFERENCES vehicle(id),
    trip_date           DATE NOT NULL DEFAULT CURRENT_DATE,
    start_odometer      NUMERIC,
    end_odometer        NUMERIC,
    distance_km         NUMERIC NOT NULL,
    start_location      TEXT,
    end_location        TEXT,
    purpose             TEXT,
    trip_type           TEXT NOT NULL DEFAULT 'business'
        CHECK (trip_type IN ('business', 'personal')),
    is_return_trip      BOOLEAN NOT NULL DEFAULT false,
    gps_route           JSONB,
    logbook_period_id   INT REFERENCES logbook_period(id),
    source              TEXT NOT NULL DEFAULT 'manual'
        CHECK (source IN ('manual', 'gps', 'recurring')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE trip_log IS 'Individual trip records for mileage tracking. Each trip classified as business or personal.';
COMMENT ON COLUMN trip_log.distance_km IS 'Trip distance in kilometres. Calculated from odometer delta or GPS path.';
COMMENT ON COLUMN trip_log.gps_route IS 'Optional GPS breadcrumb trail: [{lat, lng, ts}, ...] for route display and distance verification.';
COMMENT ON COLUMN trip_log.logbook_period_id IS 'Links trip to an active ATO 12-week logbook period, if applicable.';
COMMENT ON COLUMN trip_log.source IS 'How the trip was recorded: manual entry, GPS auto-detect, or recurring template.';

CREATE INDEX IF NOT EXISTS idx_trip_log_vehicle_date ON trip_log(vehicle_id, trip_date DESC);
CREATE INDEX IF NOT EXISTS idx_trip_log_type ON trip_log(trip_type);
CREATE INDEX IF NOT EXISTS idx_trip_log_period ON trip_log(logbook_period_id) WHERE logbook_period_id IS NOT NULL;

-- Fuel purchase records.
CREATE TABLE IF NOT EXISTS fuel_log (
    id                  SERIAL PRIMARY KEY,
    vehicle_id          INT NOT NULL REFERENCES vehicle(id),
    log_date            DATE NOT NULL DEFAULT CURRENT_DATE,
    litres              NUMERIC NOT NULL,
    cost                NUMERIC NOT NULL,
    odometer_reading    NUMERIC,
    fuel_type           TEXT,
    captured_receipt_id INT,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE fuel_log IS 'Fuel purchases linked to vehicles. Optional link to captured_receipt for receipt photo attachment.';
COMMENT ON COLUMN fuel_log.captured_receipt_id IS 'FK to captured_receipt — links fuel purchase to a photographed receipt.';

CREATE INDEX IF NOT EXISTS idx_fuel_log_vehicle ON fuel_log(vehicle_id, log_date DESC);

-- ATO cents-per-km rates (configurable per FY).
CREATE TABLE IF NOT EXISTS mileage_rate (
    id                  SERIAL PRIMARY KEY,
    financial_year      TEXT NOT NULL UNIQUE,
    cents_per_km        NUMERIC NOT NULL,
    max_km              INT NOT NULL DEFAULT 5000,
    valid_from          DATE NOT NULL,
    valid_to            DATE NOT NULL
);

COMMENT ON TABLE mileage_rate IS 'ATO cents-per-km rates by financial year. E.g. FY2025 = 85c/km, max 5,000 km.';

-- Seed current rates.
INSERT INTO mileage_rate (financial_year, cents_per_km, max_km, valid_from, valid_to)
VALUES
    ('FY2024', 0.85, 5000, '2023-07-01', '2024-06-30'),
    ('FY2025', 0.85, 5000, '2024-07-01', '2025-06-30'),
    ('FY2026', 0.88, 5000, '2025-07-01', '2026-06-30')
ON CONFLICT (financial_year) DO NOTHING;
