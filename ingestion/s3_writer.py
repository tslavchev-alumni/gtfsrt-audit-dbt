import json
from typing import Any, Dict, List, Optional

import boto3
from google.protobuf.json_format import MessageToDict

s3 = boto3.client("s3")


def build_jsonl_lines(
    feed_type: str,
    entities: List[Any],
    ts: str,
    source_header_ts: Optional[int],
) -> bytes:
    # JSONL: one line per entity
    lines = []
    for ent in entities:
        ent_dict = MessageToDict(ent, preserving_proto_field_name=True)
        entity_id = getattr(ent, "id", None)

        record = {
            "fetch_ts": ts,
            "feed_type": feed_type,
            "source_header_ts": source_header_ts,
            "entity_id": entity_id,
            "payload": ent_dict,
        }
        lines.append(json.dumps(record))

    return ("\n".join(lines) + "\n").encode("utf-8")


def s3_key(s3_prefix: str, feed_type: str, dt: str, ts: str) -> str:
    return f"{s3_prefix}/{feed_type}/dt={dt}/{feed_type}_{ts}.jsonl"


def put_jsonl(bucket: str, key: str, body: bytes) -> None:
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=body,
        ContentType="application/x-ndjson",
    )