import json
import os
from dataclasses import dataclass
from typing import Dict


DEFAULT_URLS = {
    "vehicles": "https://www.metrostlouis.org/RealTimeData/StlRealTimeVehicles.pb",
    "trips":    "https://www.metrostlouis.org/RealTimeData/StlRealTimeTrips.pb",
    "alerts":   "https://www.metrostlouis.org/RealTimeData/StlRealTimeAlerts.pb",
}


@dataclass(frozen=True)
class Config:
    bucket: str
    timeout_seconds: int
    urls: Dict[str, str]
    s3_prefix: str  # keep as "jsonl" to preserve your existing layout


def load_config() -> Config:
    bucket = os.getenv("S3_BUCKET", "metro-gtfsrt-audit-v0")
    timeout_seconds = int(os.getenv("HTTP_TIMEOUT_SECONDS", "20"))
    s3_prefix = os.getenv("S3_PREFIX", "jsonl")

    urls = DEFAULT_URLS
    urls_json = os.getenv("FEED_URLS_JSON")
    if urls_json:
        parsed = json.loads(urls_json)
        if not isinstance(parsed, dict) or not parsed:
            raise ValueError("FEED_URLS_JSON must be a non-empty JSON object.")
        urls = parsed

    return Config(
        bucket=bucket,
        timeout_seconds=timeout_seconds,
        urls=urls,
        s3_prefix=s3_prefix,
    )