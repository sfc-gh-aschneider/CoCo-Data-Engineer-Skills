# Configuration

Project-specific variables. Customize per environment.

## Variables

```yaml
DOMAIN: "FINANCE"                   # → FINANCE_DB, FINANCE_DATA_SHARE, etc.

BATCH_NAME: "DAILY"                 # → DAILY_KICKOFF_TASK, etc.
BATCH_SCHEDULE: "Daily at 6:00 AM AEST"   # CRON: 0 6 * * * Australia/Melbourne
ETL_WAREHOUSE: "ETL_WH"

DT_LAG_FACTS: "1 hour"              # Balance freshness vs compute costs
```

## Naming Conventions

| Pattern | Example |
|---------|---------|
| `<DOMAIN>_DB` | `FINANCE_DB`, `SALES_DB` |
| `<DOMAIN>_DATA_SHARE` | `FINANCE_DATA_SHARE` |
| `RAW_<SOURCE>` | `RAW_WB`, `RAW_CRM`, `RAW_STRIPE` |
| `<BATCH>_KICKOFF_TASK` | `DAILY_KICKOFF_TASK` |

Source names (`RAW_<SOURCE>`) are chosen during Bronze layer build based on the systems you're integrating.

## Schedule Reference

| Schedule | Syntax |
|----------|--------|
| Daily 6 AM AEST | `USING CRON 0 6 * * * Australia/Melbourne` |
| Hourly | `60 MINUTE` |
| Every 15 min | `15 MINUTE` |
| Weekdays 8 AM UTC | `USING CRON 0 8 * * 1-5 UTC` |
