# Silver Layer (Integration)

## Purpose
Business-ready dimensional model. Dynamic Tables with full SCD Type 2 structure.
**ALL dimensions use Type 2** - even stable ones (no overhead, future-proof).

**SCD2 is generated HERE** from Bronze PSA's insert-only history.

---

## Schema
`<DOMAIN>_DB.IL` - Dynamic Tables (dimensions + facts)

---

## Dynamic Table Settings

| Setting | Dimensions | Facts |
|---------|------------|-------|
| TARGET_LAG | `'DOWNSTREAM'` | `'1 hour'` |
| REFRESH_MODE | `AUTO` | `AUTO` |
| INITIALIZE | `ON_CREATE` | `ON_CREATE` |
| WAREHOUSE | `ETL_WH` | `ETL_WH` |

---

## Surrogate Key Rules

| Key | Purpose | Generation |
|-----|---------|------------|
| `<ENTITY>_T1_SK` | Same for ALL versions of same natural key | `DENSE_RANK()` |
| `<ENTITY>_T2_SK` | Unique per version (increments with each change) | `ROW_NUMBER()` |
| `<ENTITY>_KEY` | Alias to T1_SK by default | - |

**CRITICAL:**
- Order by `MIN(INS_TS)` then natural key - keeps keys stable across updates
- Generate keys IN THE DIMENSION, never regenerate in facts
- Use INTEGER, NOT MD5/hash for surrogate keys

---

## CTE Pattern (MANDATORY)

### Dimensions
```
1. FIRST_SEEN   → MIN(INS_TS) per natural key (for stable surrogate keys)
2. DEDUPED      → Get latest record per natural key from PSA (insert-only source)
3. SOURCE       → Union PSA + ORPHAN placeholders
4. CLEANSED     → Data quality fixes (TRIM, NULLIF, COALESCE, UPPER/LOWER)
5. DERIVED      → Calculated attributes, business logic, CASE expressions
6. Final SELECT → Surrogate keys, SCD2 columns, final projection
```

### Facts
```
1. SOURCE       → Get latest PSA record per key (QUALIFY ROW_NUMBER)
2. CLEANSED     → Data quality fixes + error handling
3. DERIVED      → Calculated measures, LAG/LEAD, growth rates, ratios
4. Final SELECT → Dimension LEFT JOINs for surrogate keys, final projection
```

**Skip CTEs if not needed** (simple dims may only need FIRST_SEEN + DEDUPED)

---

## Dimension Dynamic Table Template

```sql
CREATE DYNAMIC TABLE <DOMAIN>_DB.IL.<ENTITY>_DIM
    TARGET_LAG = 'DOWNSTREAM'
    WAREHOUSE = ETL_WH
AS
-- CTE 1: Stable key ordering (spans PSA + ORPHAN for late-arriving dims)
WITH FIRST_SEEN AS (
    SELECT <natural_key>, MIN(INS_TS) AS FIRST_INS_TS
    FROM (
        SELECT <natural_key>, INS_TS FROM RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY>
        UNION ALL
        SELECT <natural_key>, INS_TS FROM RAW_<SOURCE>.ORPHAN.<ENTITY>_ORPHANS
    )
    GROUP BY <natural_key>
),

-- CTE 2: Dedupe PSA to latest record per natural key (PSA is insert-only)
DEDUPED AS (
    SELECT *
    FROM RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY>
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY <natural_key> 
        ORDER BY INS_TS DESC
    ) = 1
),

-- CTE 3: Union real data + orphan placeholders
SOURCE AS (
    SELECT 
        <natural_key>,
        <attr_1>,
        <attr_2>,
        INS_TS,
        FALSE AS IS_ORPHAN
    FROM DEDUPED
    
    UNION ALL
    
    -- Orphans with placeholder attributes (only where no real data exists)
    SELECT 
        o.<natural_key>,
        'Unknown' AS <attr_1>,
        'Unknown' AS <attr_2>,
        o.INS_TS,
        TRUE AS IS_ORPHAN
    FROM RAW_<SOURCE>.ORPHAN.<ENTITY>_ORPHANS o
    WHERE NOT EXISTS (
        SELECT 1 FROM RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY> p
        WHERE p.<natural_key> = o.<natural_key>
    )
),

-- CTE 4: Data quality fixes (skip if not needed)
CLEANSED AS (
    SELECT
        <natural_key>,
        TRIM(UPPER(<attr_1>)) AS <attr_1>,
        COALESCE(<attr_2>, 'Unknown') AS <attr_2>,
        INS_TS,
        IS_ORPHAN
    FROM SOURCE
),

-- CTE 5: Calculated attributes (skip if not needed)
DERIVED AS (
    SELECT
        *,
        CASE WHEN <condition> THEN 'Category A' ELSE 'Category B' END AS <derived_attr>
    FROM CLEANSED
)

-- Final SELECT: Surrogate keys + SCD2 columns
SELECT
    -- T1_SK: Same for ALL versions of same natural key
    DENSE_RANK() OVER (ORDER BY fs.FIRST_INS_TS, d.<natural_key>) AS <ENTITY>_T1_SK,
    -- T2_SK: Unique per version
    ROW_NUMBER() OVER (ORDER BY fs.FIRST_INS_TS, d.<natural_key>, d.INS_TS) AS <ENTITY>_T2_SK,
    -- KEY: Alias to T1 by default
    DENSE_RANK() OVER (ORDER BY fs.FIRST_INS_TS, d.<natural_key>) AS <ENTITY>_KEY,
    
    -- Natural Key
    d.<natural_key> AS NK_<ATTRIBUTE>,
    
    -- Attributes
    d.<attr_1>,
    d.<attr_2>,
    d.<derived_attr>,
    
    -- Orphan tracking
    d.IS_ORPHAN,
    
    -- SCD2 Metadata (generated here from PSA INS_TS)
    d.INS_TS AS EFFECTIVE_FROM,
    '9999-12-31'::TIMESTAMP_NTZ AS EFFECTIVE_TO,
    TRUE AS IS_CURRENT
    
FROM DERIVED d
JOIN FIRST_SEEN fs ON d.<natural_key> = fs.<natural_key>;
```

---

## Dimension with Full SCD2 History

If you need to track ALL versions (not just current), use this pattern:

```sql
-- CTE 2 alternative: Keep all PSA rows, add version number
VERSIONED AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY <natural_key> 
            ORDER BY INS_TS
        ) AS VERSION_NUM,
        LEAD(INS_TS) OVER (
            PARTITION BY <natural_key> 
            ORDER BY INS_TS
        ) AS NEXT_INS_TS
    FROM RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY>
)

-- In final SELECT:
SELECT
    ...
    d.INS_TS AS EFFECTIVE_FROM,
    COALESCE(d.NEXT_INS_TS, '9999-12-31'::TIMESTAMP_NTZ) AS EFFECTIVE_TO,
    CASE WHEN d.NEXT_INS_TS IS NULL THEN TRUE ELSE FALSE END AS IS_CURRENT
FROM VERSIONED d
...
```

---

## Fact Dynamic Table Template

```sql
CREATE DYNAMIC TABLE <DOMAIN>_DB.IL.<ENTITY>_FACT
    TARGET_LAG = '1 hour'
    WAREHOUSE = ETL_WH
AS
-- CTE 1: Get latest PSA record per key (PSA is insert-only)
WITH SOURCE AS (
    SELECT *
    FROM RAW_<SOURCE>.PSA.<SOURCE>_<ENTITY>
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY <pk_cols> 
        ORDER BY INS_TS DESC
    ) = 1
),

-- CTE 2: Data quality fixes (skip if not needed)
CLEANSED AS (
    SELECT
        <natural_key_cols>,
        NULLIF(<measure>, 0) AS <measure>,
        <other_cols>
    FROM SOURCE
),

-- CTE 3: Calculated measures (skip if not needed)
DERIVED AS (
    SELECT
        *,
        LAG(<measure>) OVER (PARTITION BY <entity_key> ORDER BY <time_col>) AS PREV_<measure>,
        ROUND((<measure> - PREV_<measure>) / NULLIF(PREV_<measure>, 0) * 100, 2) AS <measure>_GROWTH_PCT,
        ROUND(<measure_a> / NULLIF(<measure_b>, 0), 4) AS <ratio_name>
    FROM CLEANSED
)

-- Final SELECT: Dimension keys via LEFT JOIN
SELECT
    c.COUNTRY_KEY,
    d.YEAR,
    d.<entity_key> AS NK_<ENTITY_KEY>,
    d.<measure>,
    d.PREV_<measure>,
    d.<measure>_GROWTH_PCT,
    d.<ratio_name>

FROM DERIVED d
LEFT JOIN <DOMAIN>_DB.IL.COUNTRY_DIM c 
    ON d.<country_key> = c.NK_<COUNTRY_KEY>
    AND c.IS_CURRENT = TRUE;
```

---

## Multi-Source Dimension Pattern

```sql
-- Dedupe each source first, then merge
WITH SRC1_LATEST AS (
    SELECT * FROM RAW_SOURCE1.PSA.<ENTITY>
    QUALIFY ROW_NUMBER() OVER (PARTITION BY <natural_key> ORDER BY INS_TS DESC) = 1
),
SRC2_LATEST AS (
    SELECT * FROM RAW_SOURCE2.PSA.<ENTITY>
    QUALIFY ROW_NUMBER() OVER (PARTITION BY <natural_key> ORDER BY INS_TS DESC) = 1
),
MERGED AS (
    SELECT
        COALESCE(s1.<natural_key>, s2.<natural_key>) AS <natural_key>,
        COALESCE(s1.<attr>, s2.<attr>) AS <attr>,
        CASE 
            WHEN s1.<natural_key> IS NOT NULL THEN 'SOURCE_1'
            ELSE 'SOURCE_2'
        END AS PRIMARY_SOURCE,
        GREATEST(COALESCE(s1.INS_TS, '1900-01-01'), COALESCE(s2.INS_TS, '1900-01-01')) AS INS_TS
    FROM SRC1_LATEST s1
    FULL OUTER JOIN SRC2_LATEST s2
        ON s1.<natural_key> = s2.<natural_key>
)
-- Continue with FIRST_SEEN spanning ALL sources
```

---

## Error Handling (in CLEANSED CTE)

| Function | Purpose | Example |
|----------|---------|---------|
| `TRY_TO_NUMBER()` | Safe numeric conversion | `TRY_TO_NUMBER(string_col)` |
| `TRY_TO_DATE()` | Safe date parsing | `TRY_TO_DATE(string_col, 'YYYY-MM-DD')` |
| `TRY_CAST()` | General safe casting | `TRY_CAST(col AS INTEGER)` |
| `NULLIF()` | Convert sentinel to NULL | `NULLIF(value, -1)` |
| `DIV0NULL()` | Safe division | `DIV0NULL(a, b)` |
| `COALESCE()` | Default values | `COALESCE(val, 'Unknown')` |

---

## Time Dimension Strategy

| Grain | Approach | Example |
|-------|----------|---------|
| Year | Degenerate dimension (column in fact) | `YEAR INTEGER` in fact table |
| Day | DATE_DIM with surrogate key | `DATE_KEY` joins to `DATE_DIM` |

### DATE_DIM Template (for day-grain facts)

```sql
CREATE DYNAMIC TABLE <DOMAIN>_DB.IL.DATE_DIM
    TARGET_LAG = 'DOWNSTREAM'
    WAREHOUSE = ETL_WH
AS
WITH DATE_SPINE AS (
    SELECT DATEADD(DAY, SEQ4(), '2000-01-01'::DATE) AS CALENDAR_DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 36525))  -- ~100 years
)
SELECT
    ROW_NUMBER() OVER (ORDER BY CALENDAR_DATE) AS DATE_KEY,
    CALENDAR_DATE,
    YEAR(CALENDAR_DATE) AS YEAR,
    QUARTER(CALENDAR_DATE) AS QUARTER,
    MONTH(CALENDAR_DATE) AS MONTH,
    MONTHNAME(CALENDAR_DATE) AS MONTH_NAME,
    WEEK(CALENDAR_DATE) AS WEEK_OF_YEAR,
    DAYOFWEEK(CALENDAR_DATE) AS DAY_OF_WEEK,
    DAYNAME(CALENDAR_DATE) AS DAY_NAME,
    DAYOFMONTH(CALENDAR_DATE) AS DAY_OF_MONTH,
    DAYOFYEAR(CALENDAR_DATE) AS DAY_OF_YEAR,
    CASE WHEN DAYOFWEEK(CALENDAR_DATE) IN (0, 6) THEN TRUE ELSE FALSE END AS IS_WEEKEND,
    CALENDAR_DATE AS EFFECTIVE_FROM,
    '9999-12-31'::DATE AS EFFECTIVE_TO,
    TRUE AS IS_CURRENT
FROM DATE_SPINE;
```

---

## Star Schema Query Example

```sql
-- Example: Join fact to dimensions for reporting
SELECT 
    c.COUNTRY_NAME,
    c.REGION,
    f.YEAR,
    f.GDP,
    f.GDP_GROWTH_PCT,
    f.CO2_PER_CAPITA
FROM <DOMAIN>_DB.IL.ECONOMIC_FACT f
LEFT JOIN <DOMAIN>_DB.IL.COUNTRY_DIM c 
    ON f.COUNTRY_KEY = c.COUNTRY_KEY
    AND c.IS_CURRENT = TRUE
WHERE f.YEAR >= 2020
ORDER BY c.COUNTRY_NAME, f.YEAR;
```

---

## Conformance Lookups (LKP)

Use lookup tables to map different source representations to canonical values.

### When to Use

| Approach | When to Use |
|----------|-------------|
| **LKP Table** | Many values, multiple sources, mappings change, need audit trail |
| **Inline CASE** | Few values (<5), stable, single source, simple transform |

### Naming Convention
`<DOMAIN>_DB.IL.<ENTITY>_LKP`

### LKP Table Template

```sql
CREATE TABLE <DOMAIN>_DB.IL.<ENTITY>_LKP (
    SOURCE_SYSTEM       VARCHAR NOT NULL,      -- 'SOURCE_1', 'SOURCE_2'
    SOURCE_VALUE        VARCHAR NOT NULL,      -- Original value
    CANONICAL_<ATTR>    <datatype> NOT NULL,   -- Conformed value
    INS_TS              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    CONSTRAINT UK_<ENTITY>_LKP UNIQUE (SOURCE_SYSTEM, SOURCE_VALUE)
);
```

### Example: Round Conformance

```sql
-- Two sources with different round representations:
-- Source 1: ROUND_ID (Integer: 0, 1, 2, ... 27, 28)
-- Source 2: ROUND_NAME (String: '1', '2', ... 'Preliminary Final', 'Grand Final')

CREATE TABLE AFL_DB.IL.ROUND_LKP (
    SOURCE_SYSTEM       VARCHAR NOT NULL,
    SOURCE_VALUE        VARCHAR NOT NULL,
    CANONICAL_ROUND_ID  INTEGER NOT NULL,
    CANONICAL_ROUND_NAME VARCHAR NOT NULL,
    INS_TS              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    CONSTRAINT UK_ROUND_LKP UNIQUE (SOURCE_SYSTEM, SOURCE_VALUE)
);

-- Populate mappings
INSERT INTO AFL_DB.IL.ROUND_LKP (SOURCE_SYSTEM, SOURCE_VALUE, CANONICAL_ROUND_ID, CANONICAL_ROUND_NAME)
VALUES
    ('FOOTYWIRE', '0', 0, 'Opening Round'),
    ('FOOTYWIRE', '1', 1, 'Round 1'),
    ('FOOTYWIRE', '27', 27, 'Preliminary Final'),
    ('AFL_TABLES', 'Opening Round', 0, 'Opening Round'),
    ('AFL_TABLES', 'Round 1', 1, 'Round 1'),
    ('AFL_TABLES', 'Preliminary Final', 27, 'Preliminary Final');
```

### Using LKP in Fact DT

```sql
-- In DERIVED or final SELECT CTE
LEFT JOIN <DOMAIN>_DB.IL.<ENTITY>_LKP lkp
    ON lkp.SOURCE_SYSTEM = '<SOURCE_NAME>'
    AND lkp.SOURCE_VALUE = src.<source_column>
```

### File Location
- `ETL/PSA-IL/IL-<Entity>-LKP.sql` - Lookup table DDL and seed data

---

## File Locations
- `ETL/PSA-IL/PSA-IL-<Entity>-Dim.sql` - Dimension Dynamic Tables
- `ETL/PSA-IL/PSA-IL-<Entity>-Fact.sql` - Fact Dynamic Tables
- `ETL/PSA-IL/IL-<Entity>-LKP.sql` - Conformance Lookup Tables
