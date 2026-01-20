# Architecture Overview

## High-level flow
Lambda -> S3 -> Snowflake (canonical views + tasks) -> dbt -> semantic layer (Cortex)

## Repository structure
- ingestion/        # AWS Lambda code (GTFS-RT ingestion → JSONL)
- snowflake/        # Pre-dbt Snowflake objects (views, tasks, semantic view)
- models/           # dbt models (minute facts, 5-minute health, marts)
- seeds/            # dbt seeds (health thresholds)
- tests/            # dbt data tests
- macros/           # dbt macros (schema behavior)

## Ingestion (AWS Lambda)
- Writes append-only JSONL files to S3
- One JSON object per GTFS-RT entity
- No direct coupling to Snowflake

Relevant file:
- [ingestion/lambda_function.py](./ingestion/lambda_function.py)

## Snowflake
- S3 files treated as raw evidence
- Canonical contract defined via views
- Minute and 5-minute health facts built via tasks (pre-dbt)

Relevant files:
- snowflake/gtfs_rt/V_ENTITIES_CANONICAL.sql
- snowflake/tasks/TASK_BUILD_MINUTE_FACTS_48H.sql
- snowflake/tasks/TASK_BUILD_HEALTH_5M_48H.sql

## dbt
- Consumes canonical Snowflake views
- Produces minute and 5-minute health facts
- Applies contract tests and documentation via YAML

Relevant folders:
- models/
- seeds/
- tests/

## Semantic layer
- Snowflake semantic view for Cortex Analyst
- Built on 5-minute health facts

Relevant files:
- snowflake/semantic/GTFS_RT_FEED_HEALTH.sql
