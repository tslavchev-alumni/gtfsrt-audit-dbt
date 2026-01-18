## 2026-01-16 - API ingestion (Lambda) published to repository

What changed:
- Refactored GTFS-RT ingestion Lambda into 5 files (config, http_utils, parser, writer, handler)
- Added per-feed failure isolation (partial success allowed; fail only if all feeds fail)
- Introduced env-based configuration (bucket, prefix, timeout)
- Added structured logging for fetch/write per feed
- Kept JSONL schema and S3 key structure identical to previous version
- Downloaded deployed ZIP and synced source files to repo (no vendored deps)

Operational steps:
- Verified behavior via Lambda test + CloudWatch logs
- Published Lambda version for rollback

- Set environment variables in Lambda configuration

Why:
- Show API ingestion
- Goal: make boundaries inspectable without overengineering

## 2026-01-18 - Reviewed S3 -> snowflake pipe
- S3 bucket defined as snowflake stage
- Pipe in snowflake auto-ingests new files in the stage *one JSON element per row*.
