# Task Orchestration

## Purpose
Coordinate ETL pipeline execution across layers using Snowflake Tasks.

---

## Task Flow

```
KICKOFF (CRON)
    │
    ├──► SOURCE_1_RAW_TASK ──┐
    ├──► SOURCE_2_RAW_TASK ──┼──► RAW_WAIT_TASK
    └──► SOURCE_N_RAW_TASK ──┘
                                      │
    ┌─────────────────────────────────┘
    │
    ├──► SOURCE_1_PSA_TASK ──┐
    ├──► SOURCE_2_PSA_TASK ──┼──► PSA_WAIT_TASK ──► [DTs auto-refresh]
    └──► SOURCE_N_PSA_TASK ──┘
                                      │
    ┌─────────────────────────────────┘
    │
    └──► ORPHAN_DETECT_TASK ──► ORPHAN_WAIT_TASK ──► [DTs refresh again]
```

---

## Schema
`UTL_DB.ETL` - Cross-database task orchestration

---

## Naming Conventions

| Task Type | Pattern | Example |
|-----------|---------|---------|
| Source Tasks | `<SOURCE>_<LAYER>_<ENTITY>_TASK` | `WB_RAW_COUNTRY_TASK` |
| Wait Tasks | `<BATCH>_<STAGE>_WAIT_TASK` | `DAILY_RAW_WAIT_TASK` |
| Kickoff | `<BATCH>_KICKOFF_TASK` | `DAILY_KICKOFF_TASK` |

---

## Task Templates

### Kickoff Task (CRON Scheduled)

```sql
CREATE OR REPLACE TASK UTL_DB.ETL.<BATCH>_KICKOFF_TASK
    WAREHOUSE = ETL_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'  -- Daily 6 AM UTC
AS
SELECT 1;  -- Body is trivial, just triggers children
```

### Stage 1: RAW Tasks (Parallel)

```sql
CREATE OR REPLACE TASK UTL_DB.ETL.<SOURCE>_RAW_<ENTITY>_TASK
    WAREHOUSE = ETL_WH
    AFTER UTL_DB.ETL.<BATCH>_KICKOFF_TASK
AS
CALL RAW_<SOURCE>.ETL.SP_LOAD_RAW_<ENTITY>();
```

### RAW Wait Task (Sync Point)

```sql
CREATE OR REPLACE TASK UTL_DB.ETL.<BATCH>_RAW_WAIT_TASK
    WAREHOUSE = ETL_WH
    AFTER UTL_DB.ETL.<SOURCE1>_RAW_<ENTITY>_TASK,
          UTL_DB.ETL.<SOURCE2>_RAW_<ENTITY>_TASK
AS
SELECT 1;  -- Sync point
```

### Stage 2: PSA Tasks (Parallel)

```sql
CREATE OR REPLACE TASK UTL_DB.ETL.<SOURCE>_PSA_<ENTITY>_TASK
    WAREHOUSE = ETL_WH
    AFTER UTL_DB.ETL.<BATCH>_RAW_WAIT_TASK
AS
CALL RAW_<SOURCE>.ETL.SP_LOAD_PSA_<ENTITY>();
```

### PSA Wait Task (DTs Auto-Refresh After)

```sql
CREATE OR REPLACE TASK UTL_DB.ETL.<BATCH>_PSA_WAIT_TASK
    WAREHOUSE = ETL_WH
    AFTER UTL_DB.ETL.<SOURCE1>_PSA_<ENTITY>_TASK,
          UTL_DB.ETL.<SOURCE2>_PSA_<ENTITY>_TASK
AS
SELECT 1;  -- DTs auto-refresh after this completes
```

### Stage 3: Orphan Detection

```sql
CREATE OR REPLACE TASK UTL_DB.ETL.<BATCH>_ORPHAN_DETECT_TASK
    WAREHOUSE = ETL_WH
    AFTER UTL_DB.ETL.<BATCH>_PSA_WAIT_TASK
AS
BEGIN
    CALL RAW_<SOURCE1>.ETL.SP_DETECT_<ENTITY1>_ORPHANS();
    CALL RAW_<SOURCE2>.ETL.SP_DETECT_<ENTITY2>_ORPHANS();
END;
```

### Orphan Wait Task (Final DT Refresh)

```sql
CREATE OR REPLACE TASK UTL_DB.ETL.<BATCH>_ORPHAN_WAIT_TASK
    WAREHOUSE = ETL_WH
    AFTER UTL_DB.ETL.<BATCH>_ORPHAN_DETECT_TASK
AS
SELECT 1;  -- DTs refresh again to include orphans
```

---

## Resume Tasks (Required!)

```sql
-- Tasks are created SUSPENDED by default
ALTER TASK UTL_DB.ETL.<BATCH>_ORPHAN_WAIT_TASK RESUME;
ALTER TASK UTL_DB.ETL.<BATCH>_ORPHAN_DETECT_TASK RESUME;
ALTER TASK UTL_DB.ETL.<BATCH>_PSA_WAIT_TASK RESUME;
ALTER TASK UTL_DB.ETL.<SOURCE>_PSA_<ENTITY>_TASK RESUME;
ALTER TASK UTL_DB.ETL.<BATCH>_RAW_WAIT_TASK RESUME;
ALTER TASK UTL_DB.ETL.<SOURCE>_RAW_<ENTITY>_TASK RESUME;
ALTER TASK UTL_DB.ETL.<BATCH>_KICKOFF_TASK RESUME;  -- Resume root LAST
```

**CRITICAL: Resume in reverse dependency order (leaves first, root last)**

---

## Monitoring

```sql
-- Check task status
SHOW TASKS IN SCHEMA UTL_DB.ETL;

-- View task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE DATABASE_NAME = 'UTL_DB'
ORDER BY SCHEDULED_TIME DESC
LIMIT 100;

-- Manual execution
EXECUTE TASK UTL_DB.ETL.<BATCH>_KICKOFF_TASK;
```

---

## File Location
- `ETL/Tasks/Tasks.sql` - All task definitions
