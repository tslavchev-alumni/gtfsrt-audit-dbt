This repository contains the dbt project for a GTFS-Realtime feed health monitoring pipeline.

This project is presented as a portfolio artifact. While this repository contains only the dbt code, the system was implemented and evaluated across multiple execution environments, which are described below for context.

# GTFS-Realtime Feed Health Audit

This project implements a production-style data pipeline to ingest, monitor, and evaluate the health of GTFS-Realtime feeds using AWS, Snowflake, and dbt Cloud.

The purpose of the project is to demonstrate data engineering fundamentals: high-frequency ingestion, contract-driven transformations, incremental modeling, and scheduled operation of analytics pipelines. While the use case is public transit real-time feeds, the architecture generalizes to any near-real-time operational data.

Data is ingested by an AWS Lambda function that polls GTFS-RT APIs (vehicles, trips, alerts) and writes append-only JSONL audit records to S3. Snowflake ingests these raw records into a RAW table with time-bounded retention.

A Snowflake canonical view provides a stable contract for downstream analytics by normalizing timestamps and column semantics. This view intentionally decouples ingestion from analytical modeling.

Transformations are implemented in dbt and written to the ANALYTICS.DBT_GTFS_RT schema. The analytics layer consists of a minute-level fact table that summarizes feed activity and a 5-minute incremental aggregation that computes feed health metrics such as fetch freshness, source staleness, and ingestion lag. Configurable thresholds are stored as seeded reference data and used to classify health status and primary failure modes.

Data quality is enforced using dbt tests. Key dimensions are checked for non-null values, health status values are constrained to an explicit set, and incremental models are designed to fail loudly if contracts are violated.

Transformations are scheduled via dbt Cloud to run daily at 10:00 UTC. The scheduled job builds the full dependency graph around the feed health model and executes associated tests. Each run records build timestamps and invocation identifiers to support operational traceability.

This project focuses on data engineering mechanics and operational correctness. It does not attempt to build dashboards, perform predictive analytics, or replace upstream GTFS tooling. Those are intentional non-goals.

Built as a portfolio project to demonstrate data engineering readiness using modern cloud tooling. For a deeper discussion of system design decisions, architecture evolution, and lessons learned, see [portfolio.md](./portfolio.md).
