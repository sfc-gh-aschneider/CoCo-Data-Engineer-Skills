# Configuration

Project-specific variables. Customize per environment.

```yaml
# Orchestration
BATCH_SCHEDULE: "USING CRON 0 6 * * * UTC"    # Daily 6 AM UTC
ETL_WAREHOUSE: "ETL_WH"                        # Dedicated ETL warehouse

# Dynamic Tables
DT_LAG_DIMENSIONS: "DOWNSTREAM"                # Refresh when downstream needs
DT_LAG_FACTS: "1 hour"                         # Balance freshness vs compute
DT_REFRESH_MODE: "AUTO"
DT_INITIALIZE: "ON_CREATE"

# Data Quality
DQ_SEVERITY_LEVELS: [ERROR, WARNING, INFO]     # ERROR blocks pipeline
```
