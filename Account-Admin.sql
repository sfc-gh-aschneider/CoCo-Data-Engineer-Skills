/*==============================================================================
  ACCOUNTADMIN SETUP SCRIPT
  
  Purpose: Pre-grant privileges so the demo can run entirely as SYSADMIN
  
  Run this ONCE as ACCOUNTADMIN before giving the demo to non-admin users.
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- 1. NETWORK & INTEGRATION PRIVILEGES
-- Required for: External API access (World Bank API, OWID GitHub)
-- =============================================================================
-- Allow SYSADMIN to create external access integrations
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE SYSADMIN;

-- =============================================================================
-- 2. DATA SHARING & MARKETPLACE PRIVILEGES
-- Required for: Publishing data products to Internal Marketplace
-- =============================================================================
-- Allow SYSADMIN to create shares
GRANT CREATE SHARE ON ACCOUNT TO ROLE SYSADMIN;
-- Allow SYSADMIN to create listings (marketplace publishing)
GRANT CREATE LISTING ON ACCOUNT TO ROLE SYSADMIN;
-- Allow SYSADMIN to import shares (viewing inbound shares)
GRANT IMPORT SHARE ON ACCOUNT TO ROLE SYSADMIN;

-- =============================================================================
-- 3. TASK EXECUTION PRIVILEGES
-- Required for: Running scheduled ETL tasks
-- =============================================================================
-- Allow SYSADMIN to execute tasks
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN;

-- =============================================================================
-- 4. DATA METRIC FUNCTION (DMF) PRIVILEGES
-- Required for: Attaching DMFs to tables/dynamic tables for data quality
-- =============================================================================
-- Allow SYSADMIN to attach and execute DMFs on tables
GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE SYSADMIN;
-- Allow SYSADMIN to view DQ monitoring results
GRANT APPLICATION ROLE SNOWFLAKE.DATA_QUALITY_MONITORING_VIEWER TO ROLE SYSADMIN;
-- Allow SYSADMIN to use system DMFs (SNOWFLAKE.CORE.NULL_COUNT, etc.)
GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER TO ROLE SYSADMIN;

-- =============================================================================
-- 5. SNOWFLAKE DATABASE ACCESS
-- Required for: Querying SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
-- =============================================================================

GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SYSADMIN;

-- =============================================================================
-- 6. CORTEX (Optional - for AI features)
-- =============================================================================
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- =============================================================================
-- VERIFICATION
-- =============================================================================
-- Check grants were applied
SHOW GRANTS TO ROLE SYSADMIN;
SELECT 'ACCOUNTADMIN setup complete. SYSADMIN can now run all tasks' AS STATUS;
