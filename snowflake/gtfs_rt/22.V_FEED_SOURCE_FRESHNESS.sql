create or replace view ANALYTICS.GTFS_RT.V_FEED_SOURCE_FRESHNESS(
	FEED_TYPE,
	LATEST_SOURCE_TS_UTC,
	SECONDS_SOURCE_STALE
) as
SELECT
  feed_type,
  MAX(source_header_ts_utc) AS latest_source_ts_utc,
  DATEDIFF(
    'second',
    MAX(source_header_ts_utc),
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ
  ) AS seconds_source_stale
FROM ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
WHERE source_header_ts_utc IS NOT NULL
GROUP BY feed_type;
