# Data Quality (DMF)

## Purpose
Data Metric Functions (DMFs) for automated data quality monitoring.
**Enterprise Edition required.**

**Note:** DMF privileges must be granted by ACCOUNTADMIN - see `Data-Engineering-Spec/Account-Admin.sql`

---

## System DMFs (SNOWFLAKE.CORE)

Built-in DMFs - all users have USAGE by default:

| DMF | Purpose | Usage |
|-----|---------|-------|
| `NULL_COUNT` | Count NULL values | `SNOWFLAKE.CORE.NULL_COUNT` |
| `DUPLICATE_COUNT` | Count duplicate values | `SNOWFLAKE.CORE.DUPLICATE_COUNT` |
| `UNIQUE_COUNT` | Count unique values | `SNOWFLAKE.CORE.UNIQUE_COUNT` |
| `FRESHNESS` | Time since last update | `SNOWFLAKE.CORE.FRESHNESS` |

### Attach System DMF

```sql
ALTER TABLE RAW_<SOURCE>.PSA.<ENTITY>
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (<column>);

ALTER TABLE RAW_<SOURCE>.PSA.<ENTITY>
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (<column>);
```

---

## Custom DMF Template

```sql
CREATE OR REPLACE DATA METRIC FUNCTION RAW_<SOURCE>.DQ.<RULE_NAME>_COUNT(
    ARG_T TABLE(ARG_C <datatype>)
)
RETURNS NUMBER
AS $$
    SELECT COUNT(*) FROM ARG_T WHERE <condition>
$$;
```

### Examples

```sql
-- Count negative values (should be 0)
CREATE OR REPLACE DATA METRIC FUNCTION RAW_<SOURCE>.DQ.NEGATIVE_VALUE_COUNT(
    ARG_T TABLE(ARG_C NUMBER)
)
RETURNS NUMBER
AS $$
    SELECT COUNT(*) FROM ARG_T WHERE ARG_C < 0
$$;

-- Count invalid ISO codes (not 3 chars)
CREATE OR REPLACE DATA METRIC FUNCTION RAW_<SOURCE>.DQ.INVALID_ISO_COUNT(
    ARG_T TABLE(ARG_C VARCHAR)
)
RETURNS NUMBER
AS $$
    SELECT COUNT(*) FROM ARG_T WHERE LENGTH(ARG_C) != 3
$$;

-- Count future dates (should be 0 for historical data)
CREATE OR REPLACE DATA METRIC FUNCTION RAW_<SOURCE>.DQ.FUTURE_DATE_COUNT(
    ARG_T TABLE(ARG_C DATE)
)
RETURNS NUMBER
AS $$
    SELECT COUNT(*) FROM ARG_T WHERE ARG_C > CURRENT_DATE()
$$;
```

---

## Attaching DMFs to Tables

```sql
-- Attach custom DMF
ALTER TABLE RAW_<SOURCE>.PSA.<ENTITY>
    ADD DATA METRIC FUNCTION RAW_<SOURCE>.DQ.<RULE_NAME>_COUNT ON (<column>);

-- Set schedule: trigger on changes
ALTER TABLE RAW_<SOURCE>.PSA.<ENTITY>
    SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- Set schedule: CRON (run daily at 7 AM UTC)
ALTER TABLE RAW_<SOURCE>.PSA.<ENTITY>
    SET DATA_METRIC_SCHEDULE = 'USING CRON 0 7 * * * UTC';

-- Set schedule: interval (every 60 minutes)
ALTER TABLE RAW_<SOURCE>.PSA.<ENTITY>
    SET DATA_METRIC_SCHEDULE = '60 MINUTE';
```

---

## Monitoring Results

### Query DQ Results

```sql
-- View all DQ results
SELECT * 
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
ORDER BY MEASUREMENT_TIME DESC;

-- Filter by table
SELECT 
    METRIC_NAME,
    METRIC_DATABASE,
    METRIC_SCHEMA,
    REF_ENTITY_NAME,
    VALUE,
    MEASUREMENT_TIME
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE REF_ENTITY_NAME = '<TABLE_NAME>'
ORDER BY MEASUREMENT_TIME DESC;

-- Find violations (non-zero counts for "should be zero" rules)
SELECT *
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE VALUE > 0
  AND METRIC_NAME LIKE '%COUNT'
ORDER BY MEASUREMENT_TIME DESC;
```

### Show DMF Associations

```sql
-- List all DMFs attached to a table
SELECT *
FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_NAME => '<TABLE_NAME>',
    REF_ENTITY_DOMAIN => 'TABLE'
));

-- List all DMFs in a schema
SHOW DATA METRIC FUNCTIONS IN SCHEMA RAW_<SOURCE>.DQ;
```

---

## Limitations

| Limitation | Workaround |
|------------|------------|
| **No non-deterministic functions** (CURRENT_TIMESTAMP, RANDOM) | Use static bounds or pass time as parameter |
| **Enterprise Edition required** | N/A |

---

## Schema

`RAW_<SOURCE>.DQ` - Custom DMF definitions per source

---

## File Locations
- `ETL/DQ/<Source>-DQ.sql` - Custom DMF definitions and attachments
- `ETL/DQ/Domain-DQ-Validation.sql` - Cross-layer validation queries

---

## CRITICAL: Post-ETL Validation (MUST RUN)

Run these validation queries after each ETL to catch referential integrity issues:

```sql
-- Referential Integrity Check: Facts with no matching dimension
SELECT 
    '<ENTITY>_FACT_ORPHANS' AS CHECK_NAME,
    COUNT(*) AS ORPHAN_COUNT,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM <DOMAIN>_DB.IL.<ENTITY>_FACT
WHERE <DIM>_KEY IS NULL;
```

### Full Validation Summary Query

```sql
WITH CHECKS AS (
    SELECT '<ENTITY1>_FACT_ORPHANS' AS CHECK_NAME, 
           COUNT(*) AS VALUE,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
    FROM <DOMAIN>_DB.IL.<ENTITY1>_FACT WHERE <DIM>_KEY IS NULL
    UNION ALL
    SELECT '<ENTITY2>_FACT_ORPHANS', COUNT(*),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM <DOMAIN>_DB.IL.<ENTITY2>_FACT WHERE <DIM>_KEY IS NULL
)
SELECT * FROM CHECKS ORDER BY STATUS DESC;
```

---

## Validation Checklist (Add to Prompt)

Add this to your prompt for future runs:

> **After completing all layers, run data validation:**
> 1. Execute `ETL/DQ/Domain-DQ-Validation.sql` 
> 2. Verify all checks return `PASS`
> 3. If any `FAIL`: investigate orphan codes, fix joins, re-run affected layers
