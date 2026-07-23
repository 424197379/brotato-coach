from __future__ import annotations

import hashlib
import json
import math
from typing import Any


VOLATILE_KEYS = {
    "captured_at_utc",
    "local_path",
    "path",
    "run_uid",
    "steam_id",
    "player_name",
}


def normalize(value: Any) -> Any:
    if isinstance(value, dict):
        return {
            str(key): normalize(value[key])
            for key in sorted(value.keys(), key=lambda item: str(item))
            if str(key) not in VOLATILE_KEYS
        }
    if isinstance(value, list):
        return [normalize(item) for item in value]
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            return None
        return value
    return value


def canonical_json(value: Any) -> str:
    return json.dumps(
        normalize(value),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )


def fingerprint(value: Any) -> str:
    payload = canonical_json(value).encode("utf-8")
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def stable_report_id(sample_id: str, snapshot_fingerprint: str) -> str:
    seed = f"{sample_id}|{snapshot_fingerprint}".encode("utf-8")
    return "report-" + hashlib.sha256(seed).hexdigest()[:16]
