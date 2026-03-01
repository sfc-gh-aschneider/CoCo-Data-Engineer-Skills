# Snowflake Intelligence (Semantic View + Agent)

## Purpose
Enable natural language querying of the data product via Snowflake Intelligence.

---

## Schema
`<DOMAIN>_DB.PL` - Semantic View alongside PL views

---

## Semantic View Template

```sql
CREATE OR REPLACE SEMANTIC VIEW <DOMAIN>_DB.PL.<SEMANTIC_VIEW_NAME>

  TABLES (
    <dim_alias> AS <DOMAIN>_DB.IL.<DIM>_DIM
      PRIMARY KEY (<DIM>_KEY)
      COMMENT = '<Dimension description>',
    <fact_alias> AS <DOMAIN>_DB.IL.<FACT>_FACT
      PRIMARY KEY (<DIM>_KEY, <degenerate_dim>)
      COMMENT = '<Fact description>'
  )

  RELATIONSHIPS (
    <fact_alias> (<DIM>_KEY) REFERENCES <dim_alias>
  )

  FACTS (
    -- Syntax: <alias>.<new_name> AS <SOURCE_COLUMN>
    -- These become the raw columns available for aggregation in METRICS
    <fact_alias>.<alias_name> AS <SOURCE_COLUMN>
  )

  DIMENSIONS (
    -- Dimension attributes for grouping/filtering
    <dim_alias>.<attribute> AS <ALIAS>
      WITH SYNONYMS = ('<synonym1>', '<synonym2>')
      COMMENT = '<Description>',
    <fact_alias>.<degenerate_dim> AS <ALIAS>
      WITH SYNONYMS = ('<synonym1>', '<synonym2>')
      COMMENT = '<Description>'
  )

  METRICS (
    -- Pre-defined calculations users can query by name
    <fact_alias>.<metric_name> AS <AGGREGATION>(<fact_alias>.<column>)
      WITH SYNONYMS = ('<business_term1>', '<business_term2>')
      COMMENT = '<Description>'
  )

  COMMENT = '<Description of the semantic view and its purpose>'
  
  AI_SQL_GENERATION '<Instructions for SQL generation: ordering, limits, formatting>'
  
  AI_QUESTION_CATEGORIZATION '<Scope definition: what topics this data covers and how to handle out-of-scope questions>';
```

---

## Agent Creation

```sql
CREATE OR REPLACE AGENT <DOMAIN>_DB.PL.<AGENT_NAME>
  COMMENT = '<Description of what the agent can answer>'
  PROFILE = '{"display_name": "<Display Name>", "color": "<color>"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-3-5-sonnet
  
  instructions:
    response: "<Instructions for formatting responses>"
    system: "<System prompt describing the agent's role and data scope>"
    sample_questions:
      - question: "<Example question 1>"
        answer: "<Example response 1>"
  
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "<ToolName>"
        description: "<Tool description>"
  
  tool_resources:
    <ToolName>:
      semantic_view: "<DOMAIN>_DB.PL.<SEMANTIC_VIEW_NAME>"
  $$;
```

### Add Agent to Snowflake Intelligence

```sql
-- Makes agent visible in Snowflake Intelligence interface
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT 
  ADD AGENT <DOMAIN>_DB.PL.<AGENT_NAME>;
```

---

## Grant Access

```sql
-- Grant access for users to query via agent
GRANT REFERENCES, SELECT ON SEMANTIC VIEW <DOMAIN>_DB.PL.<SEMANTIC_VIEW_NAME> TO ROLE <CONSUMER_ROLE>;
```

---

## File Locations
- `ETL/Intelligence/Semantic-View.sql` - Semantic view DDL
- `ETL/Intelligence/Agent-Setup.sql` - Agent configuration SQL

---

## Validation

```sql
-- Verify semantic view created
SHOW SEMANTIC VIEWS IN SCHEMA <DOMAIN>_DB.PL;

-- Verify dimensions and metrics
SHOW SEMANTIC DIMENSIONS IN <DOMAIN>_DB.PL.<SEMANTIC_VIEW_NAME>;
SHOW SEMANTIC METRICS IN <DOMAIN>_DB.PL.<SEMANTIC_VIEW_NAME>;

-- Test query via semantic view
SELECT * FROM SEMANTIC_VIEW(
  <DOMAIN>_DB.PL.<SEMANTIC_VIEW_NAME>
  DIMENSIONS <dim_alias>.<attribute>, <fact_alias>.<degenerate_dim>
  METRICS <fact_alias>.<metric_name>
) LIMIT 10;
```

---

## Key Concepts

| Concept | Purpose |
|---------|---------|
| **TABLES** | Register IL tables (dims + facts) with primary keys |
| **RELATIONSHIPS** | Define foreign key joins between fact and dimensions |
| **FACTS** | Raw columns available for aggregation |
| **DIMENSIONS** | Columns for grouping, filtering, slicing |
| **METRICS** | Pre-defined aggregations with business-friendly names |
| **SYNONYMS** | Alternative terms users might use in natural language |
| **AI_SQL_GENERATION** | Instructions for how the AI should format queries |
| **AI_QUESTION_CATEGORIZATION** | Defines scope and handles off-topic questions |
