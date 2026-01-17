-- This is the only place that reads raw

create or replace view ANALYTICS.GTFS_RT.V_ENTITIES_CANONICAL(
	FEED_TYPE,
	ENTITY_ID,
	FETCH_TS_TZ,
	FETCH_TS_UTC,
	SOURCE_HEADER_TS_TZ,
	SOURCE_HEADER_TS_UTC,
	LOAD_TS_UTC,
	LOAD_TS,
	FILENAME,
	FILE_ROW_NUMBER,
	RAW
) as
SELECT
  RAW:feed_type::STRING  AS feed_type,
  RAW:entity_id::STRING  AS entity_id,

  /* ---- Canonical UTC timestamps (NTZ) ---- */

  -- Lambda writes ISO-8601 UTC like 2025-12-22T22:08:01Z
  TO_TIMESTAMP_TZ(RAW:fetch_ts::STRING)                                         AS fetch_ts_tz,
  CONVERT_TIMEZONE('UTC', TO_TIMESTAMP_TZ(RAW:fetch_ts::STRING))::TIMESTAMP_NTZ AS fetch_ts_utc,

  -- GTFS-RT header timestamp is epoch seconds (UTC)
  IFF(
    RAW:source_header_ts IS NULL,
    NULL,
    TO_TIMESTAMP_TZ(TO_NUMBER(RAW:source_header_ts))
  )                                                                             AS source_header_ts_tz,

  IFF(
    RAW:source_header_ts IS NULL,
    NULL,
    CONVERT_TIMEZONE('UTC', TO_TIMESTAMP_TZ(TO_NUMBER(RAW:source_header_ts)))::TIMESTAMP_NTZ
  )                                                                             AS source_header_ts_utc,

  -- Snowpipe/ingest timestamp normalized to UTC NTZ
  CONVERT_TIMEZONE('UTC', LOAD_TS)::TIMESTAMP_NTZ                               AS load_ts_utc,

  /* ---- Original metadata ---- */
  LOAD_TS,
  FILENAME,
  FILE_ROW_NUMBER,
  RAW AS raw
FROM RAW.GTFS_RT.GTFSRT_ENTITIES;
