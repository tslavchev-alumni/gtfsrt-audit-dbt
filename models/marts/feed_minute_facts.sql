-- Build minute-grain feed facts used as the base for 5-minute health rollups.
-- 1 row per (minute_utc, feed_type).
-- Input: stg_entities_canonical.
-- latest_fetch_ts_utc: latest fetch timestamp observed within the minute.
-- latest_source_ts_utc: latest producer timestamp observed within the minute.
-- seconds_ingestion_lag: latest_fetch_ts_utc - latest_source_ts_utc (seconds).
-- Excludes rows missing source_header_ts_utc to keep lag/freshness metrics comparable.
-- Incremental: only processes minutes newer than the max(minute_utc) already built.

{{ config(
    materialized='incremental',
    unique_key=['minute_utc','feed_type']
) }}

with src as (
  select
    date_trunc('minute', fetch_ts_utc) as minute_utc,
    feed_type,
    fetch_ts_utc,
    source_header_ts_utc
  from {{ ref('stg_entities_canonical') }}
  where source_header_ts_utc is not null

  {% if is_incremental() %}
    and date_trunc('minute', fetch_ts_utc) >
      (select coalesce(max(minute_utc), to_timestamp_ntz('1970-01-01'))
       from {{ this }})
  {% endif %}
)

select
  minute_utc,
  feed_type,
  max(fetch_ts_utc) as latest_fetch_ts_utc,
  max(source_header_ts_utc) as latest_source_ts_utc,
  datediff('second', max(source_header_ts_utc), max(fetch_ts_utc)) as seconds_ingestion_lag,
  current_timestamp() as model_built_ts_utc,
  '{{ invocation_id }}' as dbt_invocation_id
from src
group by 1,2
