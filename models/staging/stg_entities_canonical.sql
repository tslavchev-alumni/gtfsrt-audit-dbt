-- Expose the canonical GTFS-RT entity contract (Silver) from the pre-dbt Snowflake phase to dbt.
-- 1 row per entity record (JSONL line).
-- This model contains no business logic. Aggregations and health logic follow downstream.

{{ config(materialized='view') }}

select
  feed_type,
  entity_id,
  fetch_ts_utc,
  source_header_ts_utc,
  load_ts,
  raw as payload
from ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
