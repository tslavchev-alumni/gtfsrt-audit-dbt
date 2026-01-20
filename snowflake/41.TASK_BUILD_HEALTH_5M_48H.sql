-- Build 5-minute GTFS-RT feed health buckets for the last 48 hours.
-- Same as in TASK_BUILD_MINUTE_FACTS_48H - add newest 24 hours, refresh the previous 24 hour period.
-- This task rolls up minute-level feed facts into as-of snapshots.
-- Runs after TASK_BUILD_MINUTE_FACTS_48H to ensure minute facts are complete before computing 5-minute health.
-- All timestamps are in UTC.

create or replace task ANALYTICS.GTFS_RT.TASK_BUILD_HEALTH_5M_48H
	warehouse=WH_XS
	after ANALYTICS.GTFS_RT.TASK_BUILD_MINUTE_FACTS_48H
	as BEGIN
  LET now_utc       TIMESTAMP_NTZ := CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ;
  LET window_end    TIMESTAMP_NTZ := DATE_TRUNC('minute', :now_utc);
  LET window_start  TIMESTAMP_NTZ := DATEADD('hour', -48, :window_end);

  DELETE FROM ANALYTICS.GTFS_RT.FEED_HEALTH_5M
  WHERE bucket_start_utc >= :window_start
    AND bucket_start_utc <  :window_end;

  INSERT INTO ANALYTICS.GTFS_RT.FEED_HEALTH_5M
  WITH buckets AS (
    SELECT
      DATEADD('minute', 5 * seq4(), :window_start)     AS bucket_start_utc,
      DATEADD('minute', 5 * seq4() + 5, :window_start) AS bucket_end_utc
    FROM TABLE(GENERATOR(ROWCOUNT => 576))
  ),
  feeds AS (
    SELECT COLUMN1::STRING AS feed_type
    FROM VALUES ('vehicles'), ('trips'), ('alerts')
  ),
  asof_state AS (   -- For each feed and bucket, select the latest known minute-level state prior to the bucket end (AS-OF snapshot).
    SELECT
      f.feed_type,
      b.bucket_start_utc,
      b.bucket_end_utc,
      MAX(m.latest_fetch_ts_utc)  AS latest_fetch_ts_utc,
      MAX(m.latest_source_ts_utc) AS latest_source_ts_utc
    FROM buckets b
    CROSS JOIN feeds f
    LEFT JOIN ANALYTICS.GTFS_RT.FEED_MINUTE_FACTS m
      ON m.feed_type = f.feed_type
     AND m.minute_utc < b.bucket_end_utc
    GROUP BY f.feed_type, b.bucket_start_utc, b.bucket_end_utc
  ),
  metrics AS (
    SELECT
      feed_type,
      bucket_start_utc,
      bucket_end_utc,
      latest_fetch_ts_utc,
      latest_source_ts_utc,
      DATEDIFF('second', latest_fetch_ts_utc, bucket_end_utc) AS seconds_since_last_fetch,
      DATEDIFF('second', latest_source_ts_utc, bucket_end_utc) AS seconds_source_stale,
      DATEDIFF('second', latest_source_ts_utc, latest_fetch_ts_utc) AS seconds_ingestion_lag
    FROM asof_state
    WHERE latest_fetch_ts_utc IS NOT NULL
  )
  SELECT
    m.bucket_start_utc,
    m.bucket_end_utc,
    m.feed_type,
    m.latest_fetch_ts_utc,
    m.latest_source_ts_utc,
    m.seconds_since_last_fetch,
    m.seconds_source_stale,
    m.seconds_ingestion_lag,
    CASE
      WHEN m.seconds_since_last_fetch > t.max_ingestion_staleness_s THEN 'FAIL'
      WHEN m.seconds_source_stale      > t.max_source_staleness_s   THEN 'FAIL'
      WHEN m.seconds_ingestion_lag     > t.max_ingestion_lag_s      THEN 'WARN'
      ELSE 'OK'
    END AS health_status,
    CASE
      WHEN m.seconds_since_last_fetch > t.max_ingestion_staleness_s THEN 'pipeline_stale'
      WHEN m.seconds_source_stale      > t.max_source_staleness_s   THEN 'source_stale'
      WHEN m.seconds_ingestion_lag     > t.max_ingestion_lag_s      THEN 'ingestion_lag_high'
      ELSE NULL
    END AS primary_issue,
    :now_utc AS created_ts_utc
  FROM metrics m
  JOIN ANALYTICS.GTFS_RT.V_FEED_HEALTH_THRESHOLDS t
    ON t.feed_type = m.feed_type;

END;
