# Gold Layer (Presentation)

## Purpose
Business-ready views for consumption. Simple projections from Silver IL.
**NO transformations here** - just filtering and column selection.

---

## Schema
`<DOMAIN>_DB.PL` - Views over IL tables

---

## View Patterns

### Current-Only Dimension View
```sql
CREATE OR REPLACE VIEW <DOMAIN>_DB.PL.<ENTITY>_DIM AS
SELECT 
    <ENTITY>_KEY,
    NK_<ATTRIBUTE>,
    <attr_1>,
    <attr_2>
FROM <DOMAIN>_DB.IL.<ENTITY>_DIM
WHERE IS_CURRENT = TRUE;
```

### Fact View (Rename/Alias Columns for Business Users)
```sql
CREATE OR REPLACE VIEW <DOMAIN>_DB.PL.<ENTITY>_FACT AS
SELECT 
    COUNTRY_KEY,
    YEAR,
    <measure> AS <business_friendly_name>,
    <measure>_GROWTH_PCT AS <business_friendly_name>_GROWTH
FROM <DOMAIN>_DB.IL.<ENTITY>_FACT;
```

### Report View (Pre-Joined Star Schema)
```sql
CREATE OR REPLACE VIEW <DOMAIN>_DB.PL.RPT_<REPORT_NAME> AS
SELECT 
    d.<dim_attr_1>,
    d.<dim_attr_2>,
    f.<measure_1>,
    f.<measure_2>
FROM <DOMAIN>_DB.IL.<ENTITY>_FACT f
JOIN <DOMAIN>_DB.IL.<DIM>_DIM d 
    ON f.<DIM>_KEY = d.<DIM>_KEY
WHERE d.IS_CURRENT = TRUE;
```

---

## Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Dimension views | `<ENTITY>_DIM` | `COUNTRY_DIM` |
| Fact views | `<ENTITY>_FACT` | `ECONOMIC_FACT` |
| Report views | `RPT_<PURPOSE>` | `RPT_COUNTRY_SUMMARY` |

---

## File Locations
- `ETL/IL-PL/PL-<Entity>.sql` - Individual PL views
- `ETL/IL-PL/PL-Star-Schema.sql` - All PL views together
