-- Is the source feed updating?
-- 1 row per feed type
-- Everything comes via the canonical contract / Silver boundary ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
-- UTC standardized timezone across the board
-- Uses GTFS-RT FeedHeader.timestamp (source_header_ts) when present.
-- Rows without source_header_ts are excluded.

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
