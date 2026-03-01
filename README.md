# CoCo-Data-Engineer-Skills
CoCo Data Engineering Skills Project

# Snowflake Data Engineering Spec

A template-driven framework for building production-ready data products in Snowflake using Dynamic Tables, External Access Integrations, and Snowflake Intelligence.

## Architecture

```
Bronze (RAW + PSA)     Silver (IL)           Gold (PL)           Share
─────────────────────────────────────────────────────────────────────────
RAW_<SOURCE>           <DOMAIN>_DB           <DOMAIN>_DB         Internal
├── .API (UDFs)        ├── .IL               ├── .PL             Marketplace
├── .RAW (landing)     │   ├── *_DIM DT      │   ├── *_DIM       Listing
├── .PSA (staging)     │   └── *_FACT DT     │   ├── *_FACT      
├── .ORPHAN            └── .DQ (DMFs)        │   └── RPT_*       
├── .DQ (DMFs)                               └── .SHARE (secure)
└── .ETL (procs)
```

## Layers

| Layer | Spec File | Purpose |
|-------|-----------|---------|
| **Config** | `00-Config.md` | Environment variables (schedules, warehouses, DT lag) |
| **Standards** | `01-Standards.md` | Naming conventions, folder structure, key rules |
| **Bronze** | `02-Bronze.md` | API UDFs, RAW tables, PSA tables (insert-only), ORPHAN handling |
| **Silver** | `03-Silver.md` | Dynamic Tables with SCD Type 2 dims & facts |
| **Gold** | `04-Gold.md` | Business-friendly views (no transformations) |
| **Share** | `05-Share.md` | Secure views + Organization Listing for Internal Marketplace |
| **Tasks** | `06-Tasks.md` | Task orchestration (RAW → PSA → DT refresh → Orphan detection) |
| **Data Quality** | `07-DataQuality.md` | Custom DMFs + validation queries |
| **Intelligence** | `08-Intelligence.sql` | Semantic View + Cortex Agent for natural language queries |


## Usage

1. Copy this spec folder to your Snowsight Workspace
2. Update `00-Config.md` with your values:
   - `DOMAIN` - your domain name (e.g., `"SALES"`, `"FINANCE"`)
   - `BATCH_NAME` - task prefix (e.g., `"DAILY"`, `"HOURLY"`)
   - `BATCH_SCHEDULE` - when ETL runs
   - `ETL_WAREHOUSE` - warehouse for tasks
3. Run as **SYSADMIN**. First execute `Account-Admin.sql` to grant required privileges
4. Open **Cortex Code** and describe your build. See `CoCo-WorldBank-Prompt.txt` for an example prompt

## File Structure

```
ETL/
├── API/<Source>-<Entity>.sql
├── DDL/<Source>-RAW.sql, <Source>-PSA.sql
├── RAW-PSA/<Source>/RAW-PSA-<Entity>.sql
├── PSA-IL/PSA-IL-<Entity>-Dim.sql, PSA-IL-<Entity>-Fact.sql
├── IL-PL/PL-Star-Schema.sql
├── Share/Share-Listing.sql
├── Tasks/Tasks.sql
├── DQ/<Source>-DQ.sql, <Domain>-DQ.sql, Domain-DQ-Validation.sql
└── Intelligence/Semantic-View.sql, Agent-Setup.sql
```

## Requirements

- Snowflake Enterprise Edition (for DMFs)
- ACCOUNTADMIN to allow External Access Integrations (if required)

