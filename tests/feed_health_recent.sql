-- Fail if we haven't produced any feed health data recently

select 1
where not exists (
  select 1
  from ANALYTICS.DBT_GTFS_RT.FEED_HEALTH_5M
  where bucket_end_utc >= dateadd('minute', -15, current_timestamp())
)