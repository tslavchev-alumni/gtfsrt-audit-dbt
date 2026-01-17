from datetime import datetime, timezone
from typing import Optional, Tuple

import gtfs_realtime_pb2


def parse_feed(pb: bytes) -> gtfs_realtime_pb2.FeedMessage:
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(pb)
    return feed


def extract_source_header_ts(feed: gtfs_realtime_pb2.FeedMessage) -> Optional[int]:
    try:
        if feed.header and feed.header.timestamp:
            return int(feed.header.timestamp)
    except Exception:
        return None
    return None


def utc_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def dt_from_ts(ts: str) -> str:
    return ts[:10]