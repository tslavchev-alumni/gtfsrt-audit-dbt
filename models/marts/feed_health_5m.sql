-- Compute 5-minute bucketed GTFS-RT feed health for monitoring and trend analysis.
-- 1 row per (bucket_start_utc, feed_type).
-- Inputs:
--   - feed_minute_facts (minute-grain evidence)
--   - feed_health_thresholds (seeded contract thresholds)
-- Health logic:
--   1) pipeline staleness OR source staleness -> FAIL
--   2) high ingestion lag -> WARN
--   3) otherwise -> OK

{{ config(
    materialized='incremental',
    unique_key=['bucket_start_utc','feed_type']
) }}

with mf as (
  select * from {{ ref('feed_minute_facts') }}
),

bucketed as (
  select
    dateadd(
      'minute',
      5 * floor(date_part('minute', minute_utc) / 5),
      date_trunc('hour', minute_utc)
    ) as bucket_start_utc,
    dateadd(
      'minute', 5,
      dateadd(
        'minute',
        5 * floor(date_part('minute', minute_utc) / 5),
        date_trunc('hour', minute_utc)
      )
    ) as bucket_end_utc,
    feed_type,
    latest_fetch_ts_utc,
    latest_source_ts_utc
  from mf

  {% if is_incremental() %}
    where minute_utc >
      (select coalesce(max(bucket_start_utc), to_timestamp_ntz('1970-01-01'))
       from {{ this }})
  {% endif %}
),

asof_state as (
  select
    bucket_start_utc,
    bucket_end_utc,
    feed_type,
    max(latest_fetch_ts_utc)  as latest_fetch_ts_utc,
    max(latest_source_ts_utc) as latest_source_ts_utc
  from bucketed
  group by 1,2,3
),

thr as (
  select
    feed_type,
    max_ingestion_staleness_s,
    max_source_staleness_s,
    max_ingestion_lag_s
  from {{ ref('feed_health_thresholds') }}
)

select
  s.bucket_start_utc,
  s.bucket_end_utc,
  s.feed_type,
  s.latest_fetch_ts_utc,
  s.latest_source_ts_utc,

  datediff('second', s.latest_fetch_ts_utc, s.bucket_end_utc)  as seconds_since_last_fetch,
  datediff('second', s.latest_source_ts_utc, s.bucket_end_utc) as seconds_source_stale,
  datediff('second', s.latest_source_ts_utc, s.latest_fetch_ts_utc) as seconds_ingestion_lag,

  t.max_ingestion_staleness_s,
  t.max_source_staleness_s,
  t.max_ingestion_lag_s,

  case
    when t.max_ingestion_staleness_s is null
    or t.max_source_staleness_s is null
    or t.max_ingestion_lag_s is null
    then 'FAIL'
    when datediff('second', s.latest_fetch_ts_utc, s.bucket_end_utc) > t.max_ingestion_staleness_s then 'FAIL'
    when datediff('second', s.latest_source_ts_utc, s.bucket_end_utc) > t.max_source_staleness_s then 'FAIL'
    when datediff('second', s.latest_source_ts_utc, s.latest_fetch_ts_utc) > t.max_ingestion_lag_s then 'WARN'
    else 'OK'
  end as health_status,

  case
    when datediff('second', s.latest_fetch_ts_utc, s.bucket_end_utc) > t.max_ingestion_staleness_s then 'pipeline_stale'
    when datediff('second', s.latest_source_ts_utc, s.bucket_end_utc) > t.max_source_staleness_s then 'source_stale'
    when datediff('second', s.latest_source_ts_utc, s.latest_fetch_ts_utc) > t.max_ingestion_lag_s then 'ingestion_lag_high'
    when t.max_ingestion_staleness_s is null or t.max_source_staleness_s is null or t.max_ingestion_lag_s is null then 'missing_thresholds'
    else null
  end as primary_issue,
  current_timestamp() as model_built_ts_utc,
'{{ invocation_id }}' as dbt_invocation_id


from asof_state s
left join thr t
  on lower(trim(s.feed_type)) = lower(trim(t.feed_type))
