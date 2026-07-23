from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


NATIVE_NAN_RE = re.compile(r"(?<![A-Za-z0-9_\"'])nan(?![A-Za-z0-9_\"'])")


def _replace_native_nan_outside_strings(text: str) -> str:
    result: list[str] = []
    in_string = False
    escaped = False
    index = 0

    while index < len(text):
        char = text[index]
        if in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == '"':
            in_string = True
            result.append(char)
            index += 1
            continue

        match = NATIVE_NAN_RE.match(text, index)
        if match:
            result.append("null")
            index = match.end()
            continue

        result.append(char)
        index += 1

    return "".join(result)


def load_json(path: Path, allow_native_nan: bool = False) -> Any:
    text = path.read_text(encoding="utf-8")
    if allow_native_nan:
        text = _replace_native_nan_outside_strings(text)
    return json.loads(text)


def load_events_jsonl(path: str | Path) -> dict[str, Any]:
    """Load coach event JSONL with recoverable corruption handling.

    The recorder contract treats the last line as disposable if a crash leaves
    it truncated. Middle-line parse failures are skipped and reported so later
    tests can assert the exact loss without rejecting the whole event log.
    """

    event_path = Path(path)
    events: list[dict[str, Any]] = []
    warnings: list[str] = []
    skipped_lines: list[int] = []
    skipped_sequences: list[Any] = []

    lines = event_path.read_text(encoding="utf-8-sig").splitlines()
    for index, line in enumerate(lines):
        line_number = index + 1
        if not line.strip():
            continue
        try:
            parsed = json.loads(line)
        except json.JSONDecodeError as exc:
            if index == len(lines) - 1:
                warnings.append("truncated_tail")
            else:
                warnings.append("invalid_jsonl_event")
                skipped_lines.append(line_number)
                skipped_sequences.append(_extract_sequence_hint(line))
            continue
        if isinstance(parsed, dict):
            events.append(parsed)
        else:
            if index == len(lines) - 1:
                warnings.append("truncated_tail")
            else:
                warnings.append("invalid_jsonl_event")
                skipped_lines.append(line_number)

    sequence_gaps = _sequence_gaps(events)
    if sequence_gaps:
        warnings.append("sequence_gap")

    return {
        "events": events,
        "data_quality": {
            "warnings": _stable_unique(warnings),
            "skipped_lines": skipped_lines,
            "skipped_sequences": [
                value for value in skipped_sequences if value is not None
            ],
            "sequence_gaps": sequence_gaps,
        },
    }


def load_fixture(fixture_path: str | Path) -> dict[str, Any]:
    root = Path(fixture_path)
    if not root.exists() or not root.is_dir():
        raise FileNotFoundError(f"fixture directory not found: {root}")

    loaded: dict[str, Any] = {
        "fixture_path": str(root),
        "sample_id": root.name,
        "kind": "unknown",
        "warnings": [],
    }

    snapshot_path = root / "coach-snapshot.json"
    timeline_path = root / "run-timeline.json"
    assertions_path = root / "assertions.json"
    native_brotato_path = root / "source-brotato-state.json"
    runtracker_path = root / "source-runtracker.json"

    if snapshot_path.exists():
        loaded["kind"] = "snapshot"
        loaded["snapshot"] = load_json(snapshot_path)
    if timeline_path.exists():
        loaded["kind"] = "timeline"
        loaded["timeline"] = load_json(timeline_path)
    if assertions_path.exists():
        loaded["assertions"] = load_json(assertions_path)
    if native_brotato_path.exists():
        loaded["native_brotato"] = load_json(native_brotato_path, allow_native_nan=True)
        loaded["warnings"].append("native_brotato_json_loaded_with_nan_compat")
    if runtracker_path.exists():
        loaded["runtracker"] = load_json(runtracker_path)

    if loaded["kind"] == "unknown":
        raise ValueError(f"fixture has no supported standard input: {root}")

    return loaded


def _extract_sequence_hint(line: str) -> Any:
    match = re.search(r'"sequence"\s*:\s*(-?\d+)', line)
    if match:
        return int(match.group(1))
    return None


def _sequence_gaps(events: list[dict[str, Any]]) -> list[dict[str, int]]:
    sequences = [
        event.get("sequence")
        for event in events
        if isinstance(event.get("sequence"), int)
    ]
    if len(sequences) < 2:
        return []

    gaps: list[dict[str, int]] = []
    for previous, current in zip(sequences, sequences[1:]):
        if current > previous + 1:
            gaps.append({"after": previous, "before": current})
    return gaps


def _stable_unique(values: list[str]) -> list[str]:
    seen: set[str] = set()
    unique: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            unique.append(value)
    return unique
