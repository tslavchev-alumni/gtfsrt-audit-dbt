-- What thresholds define acceptable feed health?
-- Grain: 1 row per feed_type
-- Centralize health thresholds as data, not embedded logic.
-- Provide a single, inspectable contract for pre-dbt downstream health evaluation.
-- This view does not evaluate status. It only defines limits.

create or replace view ANALYTICS.GTFS_RT.V_FEED_HEALTH_THRESHOLDS(
	FEED_TYPE,
	MAX_INGESTION_STALENESS_S,
	MAX_SOURCE_STALENESS_S,
	MAX_INGESTION_LAG_S
) as
SELECT * FROM (
  SELECT 'vehicles' AS feed_type, 180 AS max_ingestion_staleness_s, 300 AS max_source_staleness_s, 30 AS max_ingestion_lag_s
  UNION ALL
  SELECT 'trips',                180,                           300,                         30
  UNION ALL
  SELECT 'alerts',               300,                           900,                         120
);
