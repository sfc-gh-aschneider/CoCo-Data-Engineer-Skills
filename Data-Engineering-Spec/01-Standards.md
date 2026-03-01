# Standards

Patterns and conventions. Follow consistently across all projects.

---

## Database Architecture

```
DATABASES:
├── RAW_<SOURCE>           # Landing databases per source system
│   ├── .API               # External API UDFs and views parsing responses
│   ├── .RAW               # Transient landing tables (truncate/reload)
│   ├── .PSA               # Persistent staging (insert-only, CHANGE_TRACKING=ON)
│   ├── .ORPHAN            # Synthetic placeholders for late-arriving dimensions
│   ├── .DQ                # Custom DMF definitions for this source
│   └── .ETL               # Source-specific stored procedures
│
├── <DOMAIN>_DB            # Domain databases (SALES_DB, HR_DB)
│   ├── .IL                # Dynamic Tables (dims + facts)
│   ├── .PL                # Views for business consumption
│   └── .DQ                # Domain-level DQ metrics
│
└── UTL_DB                 # Cross-database orchestration
    ├── .ETL               # Tasks spanning databases
    └── .COMMON            # Shared UDFs, network rules, external access integrations
```

---

## Account-Level Objects (NO 3-Part Naming)

- `CREATE EXTERNAL ACCESS INTEGRATION <name>` - NOT db.schema.name
- `CREATE SECURITY INTEGRATION <name>` - NOT db.schema.name
- Network rules ARE schema-scoped: `db.schema.rule_name` is correct

---

## Naming Conventions

| Layer | Pattern | Example |
|-------|---------|---------|
| RAW/PSA | `<SOURCE>_<ENTITY>` | `SRC1_ORDERS`, `SRC2_CUSTOMERS` |
| Dimensions | `<ENTITY>_DIM` | `CUSTOMER_DIM`, `PRODUCT_DIM` |
| Facts | `<ENTITY>_FACT` | `SALES_FACT`, `INVENTORY_FACT` |
| PL Views | Same as IL | - |
| Reports | `RPT_<PURPOSE>` | `RPT_SALES_SUMMARY` |

---

## Workspace Folder Structure

```
ETL/
├── API/                   # External API UDF definitions
│   └── <Source>-<Entity>.sql
├── DDL/                   # Schema & table DDL
│   ├── <Source>-RAW.sql
│   └── <Source>-PSA.sql
├── DQ/                    # Data Quality (DMF definitions)
│   └── <Source>-DQ.sql
├── RAW-PSA/<Source>/      # Load procedures
│   └── RAW-PSA-<Entity>.sql
├── PSA-IL/                # Dynamic Table definitions
│   ├── PSA-IL-<Entity>-Dim.sql
│   └── PSA-IL-<Entity>-Fact.sql
├── IL-PL/                 # PL views
│   └── PL-Star-Schema.sql
└── Tasks/                 # Task orchestration
    └── Tasks.sql
```

---

## Key Rules Summary

| Rule | Description |
|------|-------------|
| **PSA = Insert-Only** | NO surrogate keys, NO SCD2 - just source data + audit columns |
| **IL = SCD Type 2** | ALWAYS use Type 2 structure, even for stable dimensions |
| **Surrogate Keys** | Generate in IL using DENSE_RANK/ROW_NUMBER, order by MIN(INS_TS) |
| **Fact Joins** | ALWAYS LEFT JOIN to dimensions, never regenerate keys |
| **Column Retention** | NEVER drop columns in IL, keep NK_* for debugging |
| **Time Dimensions** | Year-grain = degenerate dimension, Day-grain = DATE_DIM |
