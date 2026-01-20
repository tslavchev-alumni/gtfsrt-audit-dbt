# Architecture Overview

This document serves as a navigational overview of the repository, pointing to the primary components and their roles in the system. Detailed design rationale lives in [portfolio.md](./portfolio.md).

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
- [snowflake/gtfs_rt/10.V_ENTITIES_CANONICAL.sql](./snowflake/gtfs_rt/10.V_ENTITIES_CANONICAL.sql)
- [snowflake/gtfs_rt/40.TASK_BUILD_MINUTE_FACTS_48H.sql](./snowflake/gtfs_rt/40.TASK_BUILD_MINUTE_FACTS_48H.sql)
- [snowflake/gtfs_rt/41.TASK_BUILD_HEALTH_5M_48H.sql](./snowflake/gtfs_rt/41.TASK_BUILD_HEALTH_5M_48H.sql)

## dbt
- Consumes canonical Snowflake views
- Produces minute and 5-minute health facts
- Applies contract tests and documentation via YAML

Relevant folders:
- [models/](./models/)
- [seeds/](./seeds/)
- [tests/](./tests/)

## Semantic layer
- Snowflake semantic view for Cortex Analyst
- Built on 5-minute health facts

Relevant files:
- [snowflake/gtfs_rt/50.SEMANTIC_VIEW_GTFS_RT_FEED_HEALTH.sql](./snowflake/gtfs_rt/50.SEMANTIC_VIEW_GTFS_RT_FEED_HEALTH.sql)
