import json
import logging
from typing import Any, Dict

from config import load_config
from gtfsrt_parse import parse_feed, extract_source_header_ts, utc_stamp, dt_from_ts
from http_utils import fetch_bytes
from s3_writer import build_jsonl_lines, s3_key, put_jsonl


LOG_LEVEL = "INFO"
logging.basicConfig(level=LOG_LEVEL, format="%(levelname)s %(message)s")
logger = logging.getLogger(__name__)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    cfg = load_config()

    ts = utc_stamp()
    dt = dt_from_ts(ts)

    results: Dict[str, Any] = {}
    errors: Dict[str, str] = {}

    ok_count = 0

    for feed_type, url in cfg.urls.items():
        try:
            logger.info("Fetching feed=%s", feed_type)
            pb = fetch_bytes(url, timeout_seconds=cfg.timeout_seconds)

            feed = parse_feed(pb)
            source_header_ts = extract_source_header_ts(feed)

            body = build_jsonl_lines(
                feed_type=feed_type,
                entities=list(feed.entity),
                ts=ts,
                source_header_ts=source_header_ts,
            )

            key = s3_key(cfg.s3_prefix, feed_type, dt, ts)
            put_jsonl(cfg.bucket, key, body)

            results[feed_type] = {
                "entities": len(feed.entity),
                "key": key,
                "pb_bytes": len(pb),
                "jsonl_bytes": len(body),
            }
            ok_count += 1
            logger.info("Wrote feed=%s entities=%d key=%s", feed_type, len(feed.entity), key)

        except Exception as e:
            msg = f"{type(e).__name__}: {e}"
            errors[feed_type] = msg
            logger.exception("Failed feed=%s (%s)", feed_type, msg)

    # Failure policy:
    # - If all feeds failed: hard failure so alarms/schedules see it.
    # - If some failed: return partial success with errors included.
    if ok_count == 0:
        return {"statusCode": 500, "body": json.dumps({"results": results, "errors": errors})}

    if errors:
        return {"statusCode": 207, "body": json.dumps({"results": results, "errors": errors})}

    return {"statusCode": 200, "body": json.dumps({"results": results})}