# GTFS-Realtime Feed Health Audit

This repository contains an end-to-end data pipeline for ingesting, normalizing, and evaluating the operational health of GTFS-Realtime (GTFS-RT) feeds.

The project is presented as a portfolio artifact and includes:
- API ingestion code
- warehouse-native Snowflake logic
- dbt models, tests, and documentation
- a Snowflake semantic layer for exploration

The focus of the project is data engineering mechanics: contract boundaries, incremental state management, and operational correctness. The use case (GTFS-RT feed health) is intentionally narrow and serves as a forcing function rather than a business outcome.

## What’s in this repository

- **Ingestion (AWS Lambda)**  
  Polls GTFS-RT endpoints and writes append-only JSONL audit records to S3.

- **Snowflake**  
  Canonical views, scheduled tasks, and health logic implemented directly in Snowflake to establish stable contracts and warehouse-native baselines.

- **dbt Cloud**  
  Declarative transformations, incremental models, tests, and documentation built on top of Snowflake canonical views.

- **Semantic layer**  
  A Snowflake semantic view enabling natural-language exploration of feed health metrics via Cortex Analyst.

## How to navigate this project

- **System structure and file locations**:  
  See [architecture.md](./architecture.md).

- **Design rationale, tradeoffs, and lessons learned**:  
  See [portfolio.md](./portfolio.md).

This project intentionally does not include dashboards, business KPIs, or continuous streaming infrastructure. The scope is limited to building a reliable, explainable data pipeline rather than a full analytics product.
