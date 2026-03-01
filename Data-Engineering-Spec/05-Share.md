# Share Layer (Internal Marketplace)

## Purpose
Publish data products to internal marketplace via Organization Listings.

---

## Prerequisites

1. **SHARE Schema** with Secure Views
2. **Share object** granting access
3. **Organization Listing** for discovery

---

## Secure View Pattern

```sql
-- Create dedicated SHARE schema
CREATE SCHEMA IF NOT EXISTS <DOMAIN>_DB.SHARE;

-- Create SECURE views (required for sharing)
CREATE OR REPLACE SECURE VIEW <DOMAIN>_DB.SHARE.<ENTITY>_DIM AS
SELECT * FROM <DOMAIN>_DB.IL.<ENTITY>_DIM;

CREATE OR REPLACE SECURE VIEW <DOMAIN>_DB.SHARE.<ENTITY>_FACT AS
SELECT * FROM <DOMAIN>_DB.IL.<ENTITY>_FACT;
```

---

## Share Object

```sql
-- Create the share
CREATE OR REPLACE SHARE <SHARE_NAME>;

-- Grant access to database and schema
GRANT USAGE ON DATABASE <DOMAIN>_DB TO SHARE <SHARE_NAME>;
GRANT USAGE ON SCHEMA <DOMAIN>_DB.SHARE TO SHARE <SHARE_NAME>;

-- Grant SELECT on secure views
GRANT SELECT ON VIEW <DOMAIN>_DB.SHARE.<ENTITY>_DIM TO SHARE <SHARE_NAME>;
GRANT SELECT ON VIEW <DOMAIN>_DB.SHARE.<ENTITY>_FACT TO SHARE <SHARE_NAME>;
```

---

## Organization Listing Template

**CRITICAL: Use `CREATE ORGANIZATION LISTING`, NOT `CREATE LISTING`**

```sql
CREATE ORGANIZATION LISTING <LISTING_NAME>
SHARE <SHARE_NAME> AS
$$
title: "<Title>"
subtitle: "<Subtitle - brief tagline>"
description: |
  ## Business Description
  <1-2 paragraph description of the data product, its purpose, and value proposition>
  
  **Use Cases:** <comma-separated list of primary use cases>
  
  **Data Sources:** <list of source systems and what they provide>
  
  ## Data Dictionary
  
  **<ENTITY>_DIM:** <column1> (<description>), <column2> (<description>), ...
  
  **<ENTITY>_FACT:** <column1> (<description>), <column2> (<description>), ...

organization_profile: "INTERNAL"
organization_targets:
  access:
    - account: "<account_name>"
      roles:
        - "<role>"
support_contact: "<email>"
approver_contact: "<email>"
locations:
  access_regions:
    - name: "PUBLIC.<snowflake_region>"

usage_examples:
  - title: "<Example 1 Title>"
    description: "<What this query demonstrates>"
    query: "SELECT ... FROM <DOMAIN>_DB.SHARE.<ENTITY>_FACT f JOIN <DOMAIN>_DB.SHARE.<ENTITY>_DIM d ON ... WHERE ... LIMIT 10"
  - title: "<Example 2 Title>"
    description: "<What this query demonstrates>"
    query: "SELECT ... FROM <DOMAIN>_DB.SHARE.<ENTITY>_FACT f JOIN <DOMAIN>_DB.SHARE.<ENTITY>_DIM d ON ... GROUP BY ..."
  - title: "<Example 3 Title>"
    description: "<What this query demonstrates>"
    query: "SELECT ... FROM <DOMAIN>_DB.SHARE.<ENTITY>_FACT f JOIN <DOMAIN>_DB.SHARE.<ENTITY>_DIM d ON ... ORDER BY ..."
$$;
```

---

## Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `title` | Listing display name | `"Sales Analytics Data Product"` |
| `subtitle` | Brief tagline | `"Revenue and customer metrics from CRM"` |
| `description` | Business description + data dictionary (use \| for multiline) | See template above |
| `organization_profile` | Must be `"INTERNAL"` for org-only | `"INTERNAL"` |
| `organization_targets.access` | Who can access | Account + roles |
| `support_contact` | Support email | `"data-team@company.com"` |
| `approver_contact` | Approver email | `"data-owner@company.com"` |
| `locations.access_regions.name` | Region format | `"PUBLIC.AWS_US_WEST_2"` |
| `usage_examples` | Quick start SQL examples (use fully qualified names) | See template above |

---

## Description Best Practices

The `description` field should include:

1. **Business Description**
   - What the data product is and why it exists
   - Primary use cases (ESG reporting, analytics, compliance, etc.)
   - Data sources and refresh frequency

2. **Data Dictionary**
   - Key columns in each shared view
   - Data types and units (USD, tonnes, percentages)
   - Foreign key relationships

---

## Usage Examples Best Practices

- **Always use fully qualified names** (`<DOMAIN>_DB.SHARE.<TABLE>`)
- Include 2-3 examples covering common query patterns:
  - Simple lookup/filter query
  - Aggregation with GROUP BY
  - Time-series or trend analysis
- Keep queries concise but functional

---

## Helper Queries

```sql
-- Get current region
SELECT CURRENT_REGION();

-- Get account name
SELECT CURRENT_ACCOUNT_NAME();

-- List existing shares
SHOW SHARES;

-- List existing listings
SHOW ORGANIZATION LISTINGS;
```

---

## Listing Types Comparison

| Type | Command | Visibility | Use Case |
|------|---------|------------|----------|
| **Organization** | `CREATE ORGANIZATION LISTING` | Internal org only | Internal data products |
| **Public** | `CREATE LISTING` | Public marketplace | External data products |

---

## Troubleshooting

### "Cannot share non-secure view"
```sql
-- Views must be SECURE for sharing
CREATE OR REPLACE SECURE VIEW ...
```

### "Listing not visible"
- Check `organization_targets.discovery` includes correct accounts/roles
- Verify `organization_profile: "INTERNAL"` is set

### Region format
```sql
-- Region must be prefixed with "PUBLIC."
-- Wrong: AWS_US_WEST_2
-- Right: PUBLIC.AWS_US_WEST_2
```
