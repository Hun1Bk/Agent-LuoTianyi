"""Start the local mock server, run both clients, and write a comparison report."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

import requests
from compare_client_behavior import compare

ROOT = Path(__file__).resolve().parents[2]
SERVER_DIR = ROOT / "server"
PYTHON_CLIENT = SERVER_DIR / "scripts" / "client_behavior_python.py"
GODOT_PROJECT = ROOT / "client-godot"
GODOT_SCRIPT = "res://tests/run_client_behavior_comparison.gd"


def _wait_for_server(url: str, process: subprocess.Popen[str]) -> None:
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"mock server exited with code {process.returncode}")
        try:
            response = requests.get(url + "/auth/public_key", timeout=0.5)
            if response.status_code == 200:
                return
        except requests.RequestException:
            pass
        time.sleep(0.1)
    raise TimeoutError(f"mock server did not become ready: {url}")


def _run(command: list[str], *, cwd: Path, label: str, env: dict[str, str] | None = None) -> None:
    result = subprocess.run(
        command, cwd=cwd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120
    )
    if result.stdout:
        print(f"[{label} stdout]\n{result.stdout}", end="")
    if result.stderr:
        print(f"[{label} stderr]\n{result.stderr}", end="")
    if result.returncode != 0:
        raise RuntimeError(f"{label} exited with code {result.returncode}")


def _find_godot(explicit: str | None) -> str:
    if explicit:
        return explicit
    for candidate in ("godot", "godot4"):
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    raise FileNotFoundError("Godot executable not found; pass --godot <path>")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run identical Python and Godot behavior scripts against the local mock server"
    )
    parser.add_argument("--godot", help="Godot 4 executable; otherwise godot/godot4 is searched on PATH")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=60030)
    parser.add_argument("--username", default="behavior-comparison")
    parser.add_argument("--output-dir", type=Path, default=SERVER_DIR / "artifacts" / "client-behavior")
    args = parser.parse_args()
    try:
        godot = _find_godot(args.godot)
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    args.output_dir.mkdir(parents=True, exist_ok=True)
    server_url = f"http://{args.host}:{args.port}"
    server_log = args.output_dir / "server.jsonl"
    python_log = args.output_dir / "python.jsonl"
    godot_log = args.output_dir / "godot.jsonl"
    report = args.output_dir / "comparison.json"
    for path in (server_log, python_log, godot_log, report):
        path.unlink(missing_ok=True)

    server_process = subprocess.Popen(
        [
            sys.executable,
            str(SERVER_DIR / "local_mock_server.py"),
            "--host",
            args.host,
            "--port",
            str(args.port),
            "--log-file",
            str(server_log),
        ],
        cwd=SERVER_DIR,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        _wait_for_server(server_url, server_process)
        _run(
            [
                sys.executable,
                str(PYTHON_CLIENT),
                "--server",
                server_url,
                "--username",
                args.username,
                "--log-file",
                str(python_log),
            ],
            cwd=SERVER_DIR,
            label="python-client",
        )
        _run(
            [
                godot,
                "--headless",
                "--path",
                str(GODOT_PROJECT),
                "--script",
                GODOT_SCRIPT,
                "--",
                "--server",
                server_url,
                "--username",
                args.username,
                "--log-file",
                str(godot_log),
            ],
            cwd=GODOT_PROJECT,
            label="godot-client",
        )
    finally:
        server_process.terminate()
        try:
            server_process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server_process.kill()
            server_process.wait(timeout=5)

    result = compare(python_log, godot_log)
    report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"server log: {server_log}")
    print(f"python log: {python_log}")
    print(f"godot log: {godot_log}")
    print(f"comparison report: {report}")
    print(f"behavior equal: {result['equal']} ({len(result['differences'])} differences)")
    return 0 if result["equal"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
