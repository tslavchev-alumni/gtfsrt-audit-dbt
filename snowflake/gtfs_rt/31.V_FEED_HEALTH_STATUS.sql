-- What is the current health status of each feed?
-- Grain: 1 row per feed_type.
-- Evaluate feed health using freshness and lag metrics against defined thresholds.
-- Produce a human-readable operational status (OK / WARN / FAIL).
-- Status reflects the latest available data at evaluation time.
-- This view is the primary semantic surface for feed health pre-dbt.
-- Time: UTC standardized across the board


create or replace view ANALYTICS.GTFS_RT.V_FEED_HEALTH_STATUS(
	FEED_TYPE,
	LATEST_FETCH_TS_UTC,
	SECONDS_SINCE_LAST_FETCH,
	LATEST_SOURCE_TS_UTC,
	SECONDS_SOURCE_STALE,
	SECONDS_INGESTION_LAG,
	EVALUATED_TS_UTC,
	MAX_INGESTION_STALENESS_S,
	MAX_SOURCE_STALENESS_S,
	MAX_INGESTION_LAG_S,
	HEALTH_STATUS,
	PRIMARY_ISSUE
) as
WITH snap AS ( -- Combine the latest per-feed freshness + lag metrics into a single snapshot per feed_type. Keep logic in one place
  SELECT
    i.feed_type,
    i.latest_fetch_ts_utc,
    i.seconds_since_last_fetch,
    s.latest_source_ts_utc,
    s.seconds_source_stale,
    l.seconds_ingestion_lag
  FROM ANALYTICS.GTFS_RT.V_FEED_INGESTION_FRESHNESS i
  LEFT JOIN ANALYTICS.GTFS_RT.V_FEED_SOURCE_FRESHNESS s USING (feed_type)
  LEFT JOIN ANALYTICS.GTFS_RT.V_FEED_INGESTION_LAG l USING (feed_type)
),
t AS ( -- Per-feed thresholds - configuration-as-data
  SELECT * FROM ANALYTICS.GTFS_RT.V_FEED_HEALTH_THRESHOLDS
)
SELECT
  snap.*,
  CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ AS evaluated_ts_utc,
  t.max_ingestion_staleness_s,
  t.max_source_staleness_s,
  t.max_ingestion_lag_s,

  CASE -- Staleness (ingestion/source) is treated as failure. Feed or ingestion not working. High ingestion lag is treated as warning.
    WHEN snap.seconds_since_last_fetch > t.max_ingestion_staleness_s THEN 'FAIL'
    WHEN snap.seconds_source_stale      > t.max_source_staleness_s   THEN 'FAIL'
    WHEN snap.seconds_ingestion_lag     > t.max_ingestion_lag_s      THEN 'WARN'
    ELSE 'OK'
  END AS health_status,

  CASE -- Expose the dominant failure mode for quick diagnosis.
    WHEN snap.seconds_since_last_fetch > t.max_ingestion_staleness_s THEN 'pipeline_stale'
    WHEN snap.seconds_source_stale      > t.max_source_staleness_s   THEN 'source_stale'
    WHEN snap.seconds_ingestion_lag     > t.max_ingestion_lag_s      THEN 'ingestion_lag_high'
    ELSE 'none'
  END AS primary_issue

FROM snap
JOIN t USING (feed_type);
