# Bronze Layer (RAW + PSA)

## Purpose
Source-aligned landing and staging. Two sub-layers:
- **RAW**: Transient, truncate/reload (API responses, file dumps)
- **PSA**: Persistent, insert-only (full history preserved)

---

## Schemas

| Schema | Purpose |
|--------|---------|
| `RAW_<SOURCE>.API` | External API UDFs and response parsing |
| `RAW_<SOURCE>.RAW` | Transient landing tables (truncate/reload) |
| `RAW_<SOURCE>.PSA` | Persistent staging (insert-only, change-tracked) |
| `RAW_<SOURCE>.ORPHAN` | Late-arriving dimension placeholders |
| `RAW_<SOURCE>.DQ` | Custom DMF definitions |
| `RAW_<SOURCE>.ETL` | Source-specific stored procedures |

---

## API UDF Pattern

```sql
-- Network rule for API access
CREATE OR REPLACE NETWORK RULE RAW_<SOURCE>.API.<SOURCE>_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('<api_host>');

-- External access integration (ACCOUNT-LEVEL - no 3-part name!)
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION <SOURCE>_API_ACCESS
    ALLOWED_NETWORK_RULES = (RAW_<SOURCE>.API.<SOURCE>_NETWORK_RULE)
    ENABLED = TRUE;

-- API UDF
CREATE OR REPLACE FUNCTION RAW_<SOURCE>.API.<ENTITY>_API(<params>)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'fetch_data'
EXTERNAL_ACCESS_INTEGRATIONS = (<SOURCE>_API_ACCESS)
PACKAGES = ('requests')
AS
$$
import requests

def fetch_data(<params>):
    url = f"<api_endpoint>"
    response = requests.get(url)
    return response.json() if response.status_code == 200 else None
$$;
```

---

## RAW Table Pattern

```sql
-- Transient table (no Time Travel overhead for landing zone)
CREATE OR REPLACE TRANSIENT TABLE RAW_<SOURCE>.RAW.<ENTITY> (
    JSON            VARIANT,        -- Raw API response
    INS_TS          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

---

## RAW Load Procedure

```sql
CREATE OR REPLACE PROCEDURE RAW_<SOURCE>.ETL.SP_LOAD_RAW_<ENTITY>()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Truncate and reload
    TRUNCATE TABLE RAW_<SOURCE>.RAW.<ENTITY>;
    
    INSERT INTO RAW_<SOURCE>.RAW.<ENTITY> (JSON)
    SELECT RAW_<SOURCE>.API.<ENTITY>_API(<params>);
    
    RETURN 'Load complete: ' || (SELECT COUNT(*) FROM RAW_<SOURCE>.RAW.<ENTITY>) || ' rows';
END;
$$;
```

---

## PSA Table Pattern

```sql
CREATE TABLE RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY> (
    -- Business Keys
    <business_key_cols>,
    
    -- Attributes (source data only)
    <attribute_cols>,
    
    -- Raw Payload
    JSON                VARIANT,
    
    -- Change Detection (SHA2 hash of value columns)
    HASH_DIFF           VARCHAR(64),
    
    -- Audit (INSERT-ONLY: only INS_TS needed)
    INS_TS              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) CHANGE_TRACKING = TRUE;
```

**CRITICAL: PSA is INSERT-ONLY**
- NO updates - every source change = new row
- NO `UPD_TS` column needed
- NO `EFFECTIVE_FROM`, `EFFECTIVE_TO`, `IS_CURRENT` columns
- NO surrogate keys
- Silver IL layer handles deduplication and SCD2 via HASH_DIFF comparison

---

## PSA Load Procedure (with hash check)

```sql
CREATE OR REPLACE PROCEDURE RAW_<SOURCE>.ETL.SP_LOAD_PSA_<ENTITY>()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    rows_inserted INTEGER;
BEGIN
    INSERT INTO RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY> (
        <business_key_cols>,
        <attribute_cols>,
        JSON,
        HASH_DIFF,
        INS_TS
    )
    SELECT 
        <flatten_json_to_columns>,
        JSON,
        SHA2(CONCAT_WS('|', <value_columns>)) AS HASH_DIFF,
        CURRENT_TIMESTAMP() AS INS_TS
    FROM RAW_<SOURCE>.RAW.<ENTITY> src
    -- Only insert if hash differs from latest PSA record for this key
    WHERE NOT EXISTS (
        SELECT 1 
        FROM RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY> psa
        WHERE psa.<pk_col> = src.<pk_col>
          AND psa.HASH_DIFF = SHA2(CONCAT_WS('|', <value_columns>))
          AND psa.INS_TS = (
              SELECT MAX(INS_TS) 
              FROM RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY> 
              WHERE <pk_col> = src.<pk_col>
          )
    );
    
    rows_inserted := SQLROWCOUNT;
    RETURN 'Inserted ' || rows_inserted || ' changed rows';
END;
$$;
```

---

## PSA Load Procedure (simple - no hash check)

Use when source provides full snapshots and you want complete audit trail:

```sql
CREATE OR REPLACE PROCEDURE RAW_<SOURCE>.ETL.SP_LOAD_PSA_<ENTITY>()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY> (
        <business_key_cols>,
        <attribute_cols>,
        JSON,
        HASH_DIFF,
        INS_TS
    )
    SELECT 
        <flatten_json_to_columns>,
        JSON,
        SHA2(CONCAT_WS('|', <value_columns>)) AS HASH_DIFF,
        CURRENT_TIMESTAMP()
    FROM RAW_<SOURCE>.RAW.<ENTITY>;
    
    RETURN 'Inserted ' || SQLROWCOUNT || ' rows';
END;
$$;
```

---

## ORPHAN Schema (Late-Arriving Dimensions)

### Purpose
Holds minimal placeholders when facts reference dimension members that don't exist yet.

### ORPHAN Table Template

```sql
CREATE SCHEMA IF NOT EXISTS RAW_<SOURCE>.ORPHAN;

CREATE TABLE RAW_<SOURCE>.ORPHAN.<ENTITY>_ORPHANS (
    <natural_key>       <datatype> NOT NULL,
    INS_TS              TIMESTAMP_NTZ NOT NULL
) CHANGE_TRACKING = TRUE;
```

### Orphan Detection Procedure

```sql
CREATE OR REPLACE PROCEDURE RAW_<SOURCE>.ETL.SP_DETECT_<ENTITY>_ORPHANS()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO RAW_<SOURCE>.ORPHAN.<ENTITY>_ORPHANS (<natural_key>, INS_TS)
    SELECT DISTINCT
        f.NK_<ENTITY_KEY>,
        CURRENT_TIMESTAMP()
    FROM <DOMAIN>_DB.IL.<FACT>_FACT f
    WHERE f.<ENTITY>_KEY IS NULL
      AND f.NK_<ENTITY_KEY> IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM RAW_<SOURCE>.ORPHAN.<ENTITY>_ORPHANS o
          WHERE o.<natural_key> = f.NK_<ENTITY_KEY>
      );
    
    RETURN 'Orphan detection complete';
END;
$$;
```

---

## File Locations
- `ETL/API/<Source>-<Entity>.sql` - UDF definitions
- `ETL/DDL/<Source>-RAW.sql` - RAW schema and table DDL
- `ETL/DDL/<Source>-PSA.sql` - PSA schema and table DDL
- `ETL/RAW-PSA/<Source>/RAW-PSA-<Entity>.sql` - Load procedures
