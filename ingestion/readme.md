# GTFS-RT Ingestion Lambda

AWS Lambda that polls GTFS-Realtime protobuf feeds and writes append-only JSONL audit records to S3.

- One JSON line per entity per fetch
- No business logic during ingestion
- Per-feed failure isolation (partial success allowed)

Configuration via environment variables:
- S3_BUCKET
- HTTP_TIMEOUT_SECONDS
- S3_PREFIX
- FEED_URLS_JSON (optional)

This folder mirrors the deployed Lambda source files.
