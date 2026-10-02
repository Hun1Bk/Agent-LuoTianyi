"""Run the shared local protocol behavior sequence with the Python transport.

The script deliberately talks to the wire protocol directly.  It is useful for
comparing the Python and Godot clients without importing either client's GUI or
production runtime.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import sys
import time
import uuid
from pathlib import Path
from typing import Any
from urllib.parse import quote, urljoin

import requests
from websockets.sync.client import connect

PASSWORD = base64.b64encode(b"local-password").decode("ascii")
IMAGE = base64.b64encode(b"local-image").decode("ascii")


def _now_ms() -> int:
    return int(time.time() * 1000)


def _redact(value: Any, key: str = "") -> Any:
    normalized = key.lower()
    if isinstance(value, dict):
        return {str(item_key): _redact(item_value, str(item_key)) for item_key, item_value in value.items()}
    if isinstance(value, list):
        return [_redact(item, key) for item in value]
    if isinstance(value, str) and (
        normalized
        in {"password", "new_password", "token", "login_token", "message_token", "authorization", "public_key"}
        or "token" in normalized
        or normalized.endswith("_base64")
        or normalized == "audio"
    ):
        digest = hashlib.sha256(value.encode("utf-8")).hexdigest()[:12]
        return f"<redacted len={len(value)} sha256={digest}>"
    return value


class Recorder:
    def __init__(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self._file = path.open("w", encoding="utf-8")

    def emit(self, **fields: Any) -> None:
        record = {"ts": _now_ms(), "kind": "client_test", "client": "python", **fields}
        self._file.write(json.dumps(_redact(record), ensure_ascii=False, separators=(",", ":")) + "\n")
        self._file.flush()

    def close(self) -> None:
        self._file.close()


def _url(server: str, path: str) -> str:
    return urljoin(server.rstrip("/") + "/", path.lstrip("/"))


class BehaviorClient:
    def __init__(self, server: str, username: str, recorder: Recorder) -> None:
        self.server = server.rstrip("/")
        self.username = username
        self.recorder = recorder
        self.http = requests.Session()
        self.message_token = ""
        self.login_token = ""
        self.websocket = None

    def http_call(
        self,
        step: str,
        method: str,
        path: str,
        body: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
        expected_status: int = 200,
    ) -> Any:
        request_headers = dict(headers or {})
        if body is not None:
            request_headers.setdefault("Content-Type", "application/json")
        self.recorder.emit(
            step=step,
            direction="client_to_server",
            transport="http",
            method=method,
            path=path,
            request_payload=body,
        )
        response = self.http.request(
            method,
            _url(self.server, path),
            json=body if body is not None else None,
            headers=request_headers,
            timeout=10,
        )
        try:
            response_payload: Any = response.json()
        except ValueError:
            response_payload = {"_body": f"<binary len={len(response.content)}>"} if response.content else None
        self.recorder.emit(
            step=f"{step}.response",
            direction="server_to_client",
            transport="http",
            method=method,
            path=path,
            status=response.status_code,
            response_payload=response_payload,
        )
        if response.status_code != expected_status:
            raise RuntimeError(
                f"{step}: expected HTTP {expected_status}, got {response.status_code}: {response_payload}"
            )
        return response_payload

    def ws_send(self, step: str, event_type: str, payload: dict[str, Any]) -> str:
        client_msg_id = f"behavior-{uuid.uuid4().hex[:12]}"
        packet = {
            "type": event_type,
            "payload": payload,
            "client_msg_id": client_msg_id,
            "ts": _now_ms(),
            "reply_to": None,
        }
        self.recorder.emit(
            step=step,
            direction="client_to_server",
            transport="websocket",
            event_type=event_type,
            client_msg_id=client_msg_id,
            reply_to=None,
            payload=payload,
        )
        self.websocket.send(json.dumps(packet, ensure_ascii=False))
        return client_msg_id

    def ws_receive(self, step: str, expected_type: str | None = None) -> dict[str, Any]:
        raw = self.websocket.recv(timeout=10)
        event = json.loads(raw)
        self.recorder.emit(
            step=step,
            direction="server_to_client",
            transport="websocket",
            event_type=event.get("type"),
            client_msg_id=event.get("client_msg_id"),
            reply_to=event.get("reply_to"),
            payload=event.get("payload", {}),
        )
        if expected_type and event.get("type") != expected_type:
            raise RuntimeError(f"{step}: expected {expected_type}, got {event.get('type')}")
        return event

    def run(self) -> None:
        self.http_call("http.public_key", "GET", "/auth/public_key")
        self.http_call(
            "http.register",
            "POST",
            "/auth/register",
            {"username": self.username, "password": PASSWORD, "invite_code": "local"},
        )
        login = self.http_call(
            "http.login",
            "POST",
            "/auth/login",
            {"username": self.username, "password": PASSWORD, "request_token": False},
        )
        self.login_token = login["login_token"]
        self.message_token = login["message_token"]
        self.http_call(
            "http.auto_login", "POST", "/auth/auto_login", {"username": self.username, "token": self.login_token}
        )
        self.http_call(
            "http.reset_account",
            "POST",
            "/auth/reset_account",
            {"new_username": f"{self.username}-reset", "new_password": PASSWORD, "invite_code": "local"},
        )
        self.http_call("http.client_model_types", "GET", "/llm/client-model-types")

        auth_header = {"Authorization": f"Bearer {self.message_token}"}
        username = quote(self.username, safe="")
        self.http_call(
            "http.history",
            "GET",
            f"/history?username={username}&count=50&end_index=-1",
            headers=auth_header,
        )
        self.http_call("http.dynamics", "GET", f"/dynamics?username={username}&limit=10", headers=auth_header)
        self.http_call("http.dynamics_unread", "GET", f"/dynamics/unread?username={username}", headers=auth_header)
        self.http_call(
            "http.preference_get", "POST", "/preference/get", {"username": self.username, "token": self.message_token}
        )
        self.http_call(
            "http.preference_overwrite",
            "POST",
            "/preference/overwrite",
            {"username": self.username, "token": self.message_token, "preferences": {}},
        )
        self.http_call(
            "http.dynamics_read", "POST", "/dynamics/read", {"username": self.username, "token": self.message_token}
        )
        created = self.http_call(
            "http.dynamics_create",
            "POST",
            "/dynamics",
            {"username": self.username, "token": self.message_token, "content": "behavior test"},
        )
        dynamic_id = created["item"]["id"]
        self.http_call(
            "http.comments",
            "GET",
            f"/dynamics/{dynamic_id}/comments?username={username}&limit=20",
            headers=auth_header,
        )
        self.http_call(
            "http.comment_create",
            "POST",
            f"/dynamics/{dynamic_id}/comments",
            {"username": self.username, "token": self.message_token, "content": "comment", "parent_comment_id": None},
        )
        self.http_call(
            "http.update_image_client_path",
            "POST",
            "/update_image_client_path",
            {"username": self.username, "token": self.message_token, "uuid": "behavior-image", "image_client_path": ""},
        )
        self.http_call(
            "http.get_image",
            "POST",
            "/get_image",
            {"username": self.username, "token": self.message_token, "uuid": "behavior-image"},
            expected_status=404,
        )

        websocket_server = self.server.replace("https://", "wss://", 1).replace("http://", "ws://", 1)
        self.websocket = connect(
            _url(websocket_server, "/chat_ws"), open_timeout=10, close_timeout=2, max_size=8 * 1024 * 1024
        )
        self.ws_receive("ws.system_ready", "system_ready")
        auth_id = self.ws_send(
            "ws.user_auth.send",
            "user_auth",
            {"username": self.username, "token": self.message_token, "capabilities": ["negative_ack_v1"]},
        )
        auth_ok = self.ws_receive("ws.auth_ok.receive", "auth_ok")
        if auth_ok.get("reply_to") != auth_id:
            raise RuntimeError("auth_ok did not reference user_auth")
        ping_id = self.ws_send("ws.hb_ping.send", "hb_ping", {"ping_id": 1})
        pong = self.ws_receive("ws.hb_pong.receive", "hb_pong")
        if pong.get("reply_to") != ping_id or pong.get("payload", {}).get("ping_id") != 1:
            raise RuntimeError("heartbeat reply mismatch")
        for label, length in (("start", 2), ("end", 0)):
            msg_id = self.ws_send(f"ws.user_typing_{label}.send", "user_typing", {"text_length": length})
            ack = self.ws_receive(f"ws.user_typing_{label}.ack", "server_ack")
            if ack.get("reply_to") != msg_id:
                raise RuntimeError("typing ACK mismatch")
        text_id = self.ws_send("ws.user_text.send", "user_text", {"message": "hello", "llm_mode": {"types": []}})
        text_ack = self.ws_receive("ws.user_text.ack", "server_ack")
        if text_ack.get("reply_to") != text_id:
            raise RuntimeError("text ACK mismatch")
        text_reply = self.ws_receive("ws.user_text.reply", "agent_message")
        if text_reply.get("reply_to") != text_id or text_reply.get("payload", {}).get("is_final_package") is not True:
            raise RuntimeError("text terminal reply mismatch")
        for event_type, label in (("user_image_selecting", "select"), ("user_image_selecting_cancel", "cancel")):
            msg_id = self.ws_send(f"ws.image_{label}.send", event_type, {})
            ack = self.ws_receive(f"ws.image_{label}.ack", "server_ack")
            if ack.get("reply_to") != msg_id:
                raise RuntimeError("image selection ACK mismatch")
        touch_id = self.ws_send(
            "ws.user_touch.send",
            "user_touch",
            {"touchArea": ["头"], "touchCount": 1, "timeSinceLastSentTouch": 0.0},
        )
        touch_ack = self.ws_receive("ws.user_touch.ack", "server_ack")
        if touch_ack.get("reply_to") != touch_id:
            raise RuntimeError("touch ACK mismatch")
        image_id = self.ws_send(
            "ws.user_image.send",
            "user_image",
            {"image_base64": IMAGE, "mime_type": "image/png", "image_client_path": "", "llm_mode": {"types": []}},
        )
        image_ack = self.ws_receive("ws.user_image.ack", "server_ack")
        if image_ack.get("reply_to") != image_id:
            raise RuntimeError("image ACK mismatch")
        image_reply = self.ws_receive("ws.user_image.reply", "agent_message")
        if image_reply.get("reply_to") != image_id:
            raise RuntimeError("image terminal reply mismatch")
        self.websocket.close()
        self.recorder.emit(step="ws.closed", direction="client", transport="websocket", result="closed")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Python side of the local client behavior comparison")
    parser.add_argument("--server", default="http://127.0.0.1:60030")
    parser.add_argument("--username", default="behavior-comparison")
    parser.add_argument("--log-file", type=Path, required=True)
    args = parser.parse_args()
    recorder = Recorder(args.log_file)
    try:
        BehaviorClient(args.server, args.username, recorder).run()
    except Exception as exc:  # pragma: no cover - exercised by a failed external run
        recorder.emit(step="client.error", direction="client", transport="runner", error=str(exc))
        print(f"Python behavior test failed: {exc}", file=sys.stderr)
        return 1
    finally:
        recorder.close()
    print(f"Python behavior log: {args.log_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
