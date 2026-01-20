-- How far behind is ingestion relative to source?
-- 1 row per feed type
-- Everything comes via the canonical contract / Silver boundary ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
-- UTC standardized timezone across the board
-- Lag = fetch_ts - source_header_ts (time between producer-reported timestamp and our ingestion timestamp)
-- Rows without source_header_ts are excluded.

create or replace view ANALYTICS.GTFS_RT.V_FEED_INGESTION_LAG(
	FEED_TYPE,
	LATEST_FETCH_TS_UTC,
	LATEST_SOURCE_TS_UTC,
	SECONDS_INGESTION_LAG
) as
SELECT
  feed_type,
  MAX(fetch_ts_utc) AS latest_fetch_ts_utc,
  MAX(source_header_ts_utc) AS latest_source_ts_utc,
  DATEDIFF('second', MAX(source_header_ts_utc), MAX(fetch_ts_utc)) AS seconds_ingestion_lag
FROM ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
WHERE source_header_ts_utc IS NOT NULL
GROUP BY feed_type;
