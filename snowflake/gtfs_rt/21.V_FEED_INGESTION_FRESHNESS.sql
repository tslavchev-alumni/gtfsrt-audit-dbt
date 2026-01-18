-- Is my ingestion running?
-- 1 row per feed type
-- Everything comes via the canonical contract/Silver boundary ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
-- UTC standardized timezone across the board

create or replace view ANALYTICS.GTFS_RT.V_FEED_INGESTION_FRESHNESS(
	FEED_TYPE,
	LATEST_FETCH_TS_UTC,
	SECONDS_SINCE_LAST_FETCH
) as
SELECT
  feed_type,
  MAX(fetch_ts_utc) AS latest_fetch_ts_utc,
  DATEDIFF(
    'second',
    MAX(fetch_ts_utc),
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ
  ) AS seconds_since_last_fetch
FROM ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
GROUP BY feed_type;
