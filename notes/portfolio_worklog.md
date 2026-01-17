## 2026-01-16 — Ingestion refactor
- Split Lambda into 5 files (config, http_utils, parser, writer, handler)
- Added per-feed failure isolation (partial success allowed)
- Kept JSONL schema + S3 keys identical
- Switched to env-based config (S3_BUCKET, TIMEOUT)
- Verified prod via Lambda version + S3 output
- Synced deployed ZIP → repo (source only, no vendored deps)

Why:
- Showing API ingestion
