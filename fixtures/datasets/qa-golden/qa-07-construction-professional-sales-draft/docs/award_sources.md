# Award and compliance sources used for fixture metadata

The fixture encodes award codes, classifications and rate snapshots as QA seed data. The calculation engine should still resolve rule authority references at runtime.

- MA000002 Clerks—Private Sector Award 2020 — office administration / clerical employees.
- MA000022 Cleaning Services Award 2020 — cleaning services employee level 1 casual fixture.
- MA000004 General Retail Industry Award 2020 — retail casual and supervisor fixtures.
- MA000009 Hospitality Industry (General) Award 2020 — hospitality casual and part-time fixtures.
- MA000020 Building and Construction General On-site Award 2020 — construction worker fixtures.
- MA000065 Professional Employees Award 2020 — professional/salary/annualised wage fixtures.
- MA000083 Commercial Sales Award 2020 — field sales / commission fixture.

Contractors in these fixtures intentionally have `award_code = null`, `payroll_enabled = false`, and no leave profile.
