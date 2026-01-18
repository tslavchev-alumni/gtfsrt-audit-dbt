-- Build minute-grain feed facts for the last 48 hours.
-- Task runs every 24 hours. So it calculates the data for newest 24-hour period and REcalculates data for the previous 24 hour period.
-- This allows for seemless error correction and fixes missed runs without human attention
-- Grain: 1 row per (minute_utc, feed_type)
-- Everything comes via the canonical contract / Silver boundary ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
-- Provides the base layer for downstream rollups (e.g., 5-minute health buckets).
-- Time: UTC standardized across the board. 10 UTC assumed to be the day reset for a public transportation system.

create or replace task ANALYTICS.GTFS_RT.TASK_BUILD_MINUTE_FACTS_48H
	warehouse=WH_XS
	schedule='USING CRON 0 10 * * * UTC'
	as BEGIN
  LET now_utc       TIMESTAMP_NTZ := CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ;
  LET window_end    TIMESTAMP_NTZ := DATE_TRUNC('minute', :now_utc);
  LET window_start  TIMESTAMP_NTZ := DATEADD('hour', -48, :window_end);

  -- Idempotent rebuild for the rolling window
  DELETE FROM ANALYTICS.GTFS_RT.FEED_MINUTE_FACTS
  WHERE minute_utc >= :window_start
    AND minute_utc <  :window_end;

  INSERT INTO ANALYTICS.GTFS_RT.FEED_MINUTE_FACTS
  SELECT
    DATE_TRUNC('minute', fetch_ts_utc) AS minute_utc,
    feed_type,
    MAX(fetch_ts_utc) AS latest_fetch_ts_utc,
    MAX(source_header_ts_utc) AS latest_source_ts_utc,
    DATEDIFF('second', MAX(source_header_ts_utc), MAX(fetch_ts_utc)) AS seconds_ingestion_lag,
    :now_utc AS created_ts_utc
  FROM ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL
  WHERE fetch_ts_utc >= :window_start
    AND fetch_ts_utc <  :window_end
    AND source_header_ts_utc IS NOT NULL
  GROUP BY 1, 2;
END;
