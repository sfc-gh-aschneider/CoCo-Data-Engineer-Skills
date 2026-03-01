# Configuration

Project-specific variables. Customize per environment.

# Domain (used in main database naming conventions)
DOMAIN: "FINANCE"                                  # → FINANCE_DB, FINANCE_DATA_SHARE, etc.

# Orchestration
BATCH_NAME: "DAILY"                             # → DAILY_KICKOFF_TASK, etc.
BATCH_SCHEDULE: "Daily at 6:00 AM AEST"         # CRON: 0 6 * * * Australia/Melbourne
ETL_WAREHOUSE: "ETL_WH"                         # Dedicated ETL warehouse

# Dynamic Tables
DT_LAG_FACTS: "1 hour"                          # Balance freshness vs compute costs

## Naming Convention Reference

| Variable | Used In |
|----------|---------|
| `DOMAIN` | `<DOMAIN>_DB` (database), `<DOMAIN>_DATA_SHARE` (share), listings |
| `SOURCES` | `RAW_<SOURCE>` (databases), task names, procedure names |
| `BATCH_NAME` | `<BATCH>_KICKOFF_TASK`, `<BATCH>_RAW_WAIT_TASK`, etc. |

**Example with `DOMAIN: "SALES"` and `SOURCES: ["CRM", "ERP"]`:**
- Databases: `SALES_DB`, `RAW_CRM`, `RAW_ERP`
- Share: `SALES_DATA_SHARE`
- Tasks: `DAILY_KICKOFF_TASK`, `CRM_RAW_ORDERS_TASK`

**Example Schedules:
#   Daily 6 AM AEST    → USING CRON 0 6 * * * Australia/Melbourne
#   Hourly             → 60 MINUTE
#   Every 15 min       → 15 MINUTE
#   Weekdays 8 AM      → USING CRON 0 8 * * 1-5 UTC
