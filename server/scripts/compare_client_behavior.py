"""Compare normalized Python and Godot behavior logs."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

_REDACTED = re.compile(r"^<redacted(?:\s|>)")
_DYNAMIC_PATH = re.compile(r"(/dynamics/)([^/?]+)(/comments)")
_VOLATILE_KEYS = {"client_msg_id", "reply_to", "id", "uuid", "dynamic_id", "server_ts", "ts"}


def _canonical(value: Any, key: str = "") -> Any:
    if isinstance(value, dict):
        return {str(k): _canonical(v, str(k)) for k, v in sorted(value.items())}
    if isinstance(value, list):
        return [_canonical(item, key) for item in value]
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)) and float(value).is_integer():
        return int(value)
    if isinstance(value, str) and (key in _VOLATILE_KEYS or _REDACTED.match(value)):
        return "<volatile>"
    return value


def _record(record: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {
        "step": record.get("step"),
        "direction": record.get("direction"),
        "transport": record.get("transport"),
    }
    for field in ("method", "status", "event_type", "result", "error"):
        if field in record:
            result[field] = record[field]
    if "path" in record:
        result["path"] = _DYNAMIC_PATH.sub(r"\1<id>\3", str(record["path"]))
    for field in ("request_payload", "response_payload", "payload"):
        if field in record:
            result[field] = _canonical(record[field], field)
    for field in ("client_msg_id", "reply_to"):
        if field in record:
            result[field] = "<present>" if record[field] else None
    return result


def _read(path: Path) -> list[dict[str, Any]]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if row.get("kind") == "client_test" and row.get("transport") != "runner":
            rows.append(row)
    return rows


def compare(python_path: Path, godot_path: Path) -> dict[str, Any]:
    python_rows = _read(python_path)
    godot_rows = _read(godot_path)
    left = [_record(row) for row in python_rows]
    right = [_record(row) for row in godot_rows]
    differences = []
    for index in range(max(len(left), len(right))):
        a = left[index] if index < len(left) else None
        b = right[index] if index < len(right) else None
        if a != b:
            differences.append({"index": index, "python": a, "godot": b})
    return {
        "equal": not differences,
        "python_records": len(left),
        "godot_records": len(right),
        "differences": differences,
        "python_steps": [row["step"] for row in python_rows],
        "godot_steps": [row["step"] for row in godot_rows],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare Python and Godot local client behavior JSONL files")
    parser.add_argument("--python-log", type=Path, required=True)
    parser.add_argument("--godot-log", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = compare(args.python_log, args.godot_log)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: result[key] for key in ("equal", "python_records", "godot_records", "differences")}, ensure_ascii=False, indent=2))
    return 0 if result["equal"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
