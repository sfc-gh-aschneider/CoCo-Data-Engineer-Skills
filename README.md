# CoCo-Data-Engineer-Skills
CoCo Data Engineering Skills Project

# Snowflake Data Engineering Spec

A template-driven framework for building production-ready data products in Snowflake using Dynamic Tables, External Access Integrations, and Snowflake Intelligence.

## Architecture

```
Bronze (RAW + PSA)     Silver (IL)           Gold (PL)           Share
─────────────────────────────────────────────────────────────────────────
RAW_<SOURCE>           <DOMAIN>_DB           <DOMAIN>_DB         Internal
├── .API (UDFs)        └── .IL               ├── .PL             Marketplace
├── .RAW (landing)         ├── *_DIM DT      │   ├── *_DIM       Listing
├── .PSA (staging)         └── *_FACT DT     │   ├── *_FACT      
├── .ORPHAN                                  │   └── RPT_*       
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

1. Copy this spec folder to your Snowsight workspace
2. Replace `<DOMAIN>`, `<SOURCE>`, `<ENTITY>` placeholders
3. Build layers sequentially: Bronze → Silver → Gold → Share → Tasks → DQ → Intelligence
4. Run `ETL/DQ/Domain-DQ-Validation.sql` to verify all checks pass

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
├── DQ/<Source>-DQ.sql, Domain-DQ-Validation.sql
└── Intelligence/Semantic-View.sql, Agent-Setup.sql
```

## Requirements

- Snowflake Enterprise Edition (for DMFs)
- ACCOUNTADMIN for External Access Integrations
- Warehouse for ETL tasks

## License

MIT
