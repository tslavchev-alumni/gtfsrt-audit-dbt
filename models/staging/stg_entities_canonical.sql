{{ config(materialized='view') }}

select
  feed_type,
  entity_id,
  fetch_ts_utc,
  source_header_ts_utc,
  load_ts,
  raw as payload
from ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
