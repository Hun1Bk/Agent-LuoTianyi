"""Small local HTTP/WebSocket server for client protocol comparison.

This module deliberately does not import ``server_main`` or the production
runtime. It only implements the transport contract used by the Python and
Godot clients and keeps all account state in memory.
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import secrets
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import uvicorn
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse, Response

HTTP_EVENT = "http"
WS_EVENT = "websocket"
SENSITIVE_KEYS = {
    "password",
    "new_password",
    "login_token",
    "message_token",
    "token",
    "authorization",
    "public_key",
    "image_base64",
    "audio",
}
SUPPORTED_EVENTS = {
    "user_text",
    "user_image",
    "user_typing",
    "user_touch",
    "user_image_selecting",
    "user_image_selecting_cancel",
}


def _now_ms() -> int:
    return int(time.time() * 1000)


def _secret_summary(value: str) -> str:
    digest = hashlib.sha256(value.encode("utf-8")).hexdigest()[:12]
    return f"<redacted len={len(value)} sha256={digest}>"


def _sanitize(value: Any, verbose: bool = False, key: str = "") -> Any:
    """Redact credentials and large media recursively before logging."""
    if isinstance(value, dict):
        return {
            str(item_key): _sanitize(item_value, verbose, str(item_key).lower())
            for item_key, item_value in value.items()
        }
    if isinstance(value, list):
        return [_sanitize(item, verbose, key) for item in value]
    if isinstance(value, str):
        normalized_key = key.lower()
        if normalized_key in SENSITIVE_KEYS or any(marker in normalized_key for marker in ("password", "token")):
            return _secret_summary(value)
        if normalized_key.endswith("_base64") or normalized_key in {"audio", "public_key"}:
            return _secret_summary(value)
        if not verbose and len(value) > 512:
            return f"<truncated len={len(value)} sha256={hashlib.sha256(value.encode('utf-8')).hexdigest()[:12]}>"
    return value


@dataclass
class MockAccount:
    username: str
    user_id: str
    login_token: str
    message_token: str


@dataclass
class MockState:
    accounts: dict[str, MockAccount] = field(default_factory=dict)
    public_key: str = ""
    http_count: int = 0
    ws_count: int = 0
    event_count: int = 0
    error_count: int = 0
    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    def __post_init__(self) -> None:
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        self.public_key = (
            private_key.public_key()
            .public_bytes(
                serialization.Encoding.PEM,
                serialization.PublicFormat.SubjectPublicKeyInfo,
            )
            .decode("utf-8")
        )

    def account_for(self, username: str) -> MockAccount:
        with self._lock:
            account = self.accounts.get(username)
            if account is None:
                account = MockAccount(
                    username=username,
                    user_id=username,
                    login_token=secrets.token_urlsafe(24),
                    message_token=secrets.token_urlsafe(24),
                )
                self.accounts[username] = account
            return account

    def validate_message_token(self, username: str, token: str) -> bool:
        with self._lock:
            account = self.accounts.get(username)
            return bool(account and secrets.compare_digest(account.message_token, token))

    def validate_login_token(self, username: str, token: str) -> bool:
        with self._lock:
            account = self.accounts.get(username)
            return bool(account and secrets.compare_digest(account.login_token, token))


class EventLogger:
    """Emit one JSON object per line to stdout and optionally to a JSONL file."""

    def __init__(self, verbose: bool = False, log_file: str | Path | None = None) -> None:
        self.verbose = verbose
        self._stream = open(log_file, "a", encoding="utf-8") if log_file else None
        self._lock = threading.Lock()

    def emit(self, kind: str, **fields: Any) -> None:
        record = {"ts": _now_ms(), "kind": kind, **fields}
        safe_record = _sanitize(record, self.verbose)
        line = json.dumps(safe_record, ensure_ascii=False, separators=(",", ":"))
        with self._lock:
            print(line, flush=True)
            if self._stream:
                self._stream.write(line + "\n")
                self._stream.flush()

    def close(self) -> None:
        with self._lock:
            if self._stream:
                self._stream.close()
                self._stream = None


def _event(event_type: str, payload: dict[str, Any], reply_to: str | None = None) -> dict[str, Any]:
    message = {"type": event_type, "ts": _now_ms(), "payload": payload}
    if reply_to is not None:
        message["reply_to"] = reply_to
    return message


async def _json_body(request: Request) -> dict[str, Any]:
    try:
        body = await request.json()
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise HTTPException(status_code=400, detail="request body must be a JSON object") from exc
    if not isinstance(body, dict):
        raise HTTPException(status_code=400, detail="request body must be a JSON object")
    return body


def _required_string(payload: dict[str, Any], field_name: str) -> str:
    value = payload.get(field_name)
    if not isinstance(value, str) or not value.strip():
        raise HTTPException(status_code=400, detail=f"{field_name} is required")
    return value


def _bearer_token(request: Request) -> str:
    header = request.headers.get("authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Bearer token required")
    return token


def _token_from_body(payload: dict[str, Any]) -> str:
    token = payload.get("token")
    if not isinstance(token, str) or not token:
        raise HTTPException(status_code=401, detail="token required")
    return token


def _mock_item(dynamic_id: str, *, comment: bool, parent_comment_id: str | None = None) -> dict[str, Any]:
    item = {
        "id": dynamic_id,
        "author_type": "user",
        "author_name": "local-mock",
        "content": "",
        "created_at": "1970-01-01 00:00:00",
    }
    if comment:
        item.update({"dynamic_id": dynamic_id.split(":", 1)[0], "parent_comment_id": parent_comment_id})
    else:
        item.update({"allow_comment": True, "comment_count": 0})
    return item


def create_app(state: MockState | None = None, event_logger: EventLogger | None = None) -> FastAPI:
    state = state or MockState()
    event_logger = event_logger or EventLogger()
    app = FastAPI(title="AgentLuo Local Mock Server")
    app.state.mock_state = state
    app.state.event_logger = event_logger

    @app.middleware("http")
    async def log_http(request: Request, call_next):
        started = time.perf_counter()
        request_body = await request.body()
        try:
            request_payload: Any = json.loads(request_body) if request_body else None
        except json.JSONDecodeError:
            request_payload = "<invalid json>"
        try:
            response = await call_next(request)
            body_parts = [part async for part in response.body_iterator]
            body = b"".join(body_parts)
            response_summary: Any
            try:
                response_summary = json.loads(body) if body else None
            except json.JSONDecodeError:
                response_summary = f"<binary len={len(body)}>"
            response = Response(
                content=body,
                status_code=response.status_code,
                headers=dict(response.headers),
                media_type=response.media_type,
            )
            state.http_count += 1
            event_logger.emit(
                HTTP_EVENT,
                request_id=f"http-{uuid.uuid4().hex[:12]}",
                direction="request",
                method=request.method,
                path=request.url.path,
                query=str(request.url.query),
                status=response.status_code,
                elapsed_ms=round((time.perf_counter() - started) * 1000, 2),
                client=request.client.host if request.client else None,
                request_payload=request_payload,
                response_payload=response_summary,
            )
            return response
        except Exception:
            state.error_count += 1
            raise

    @app.get("/auth/public_key")
    async def public_key() -> dict[str, str]:
        return {"public_key": state.public_key}

    @app.post("/auth/login")
    async def login(request: Request) -> dict[str, str]:
        payload = await _json_body(request)
        username = _required_string(payload, "username")
        _required_string(payload, "password")
        account = state.account_for(username)
        return {
            "user_id": account.user_id,
            "login_token": account.login_token,
            "message_token": account.message_token,
        }

    @app.post("/auth/auto_login")
    async def auto_login(request: Request) -> dict[str, str]:
        payload = await _json_body(request)
        username = _required_string(payload, "username")
        token = _required_string(payload, "token")
        if not state.validate_login_token(username, token):
            raise HTTPException(status_code=401, detail="invalid login token")
        account = state.account_for(username)
        return {
            "user_id": account.user_id,
            "login_token": account.login_token,
            "message_token": account.message_token,
        }

    @app.post("/auth/register")
    async def register(request: Request) -> dict[str, str]:
        payload = await _json_body(request)
        username = _required_string(payload, "username")
        _required_string(payload, "password")
        _required_string(payload, "invite_code")
        account = state.account_for(username)
        return {"message": "registered", "user_id": account.user_id}

    @app.post("/auth/reset_account")
    async def reset_account(request: Request) -> dict[str, str]:
        payload = await _json_body(request)
        new_username = _required_string(payload, "new_username")
        _required_string(payload, "new_password")
        _required_string(payload, "invite_code")
        account = state.account_for(new_username)
        return {"message": "reset", "username": account.username}

    @app.get("/history")
    async def history(request: Request) -> dict[str, Any]:
        username = request.query_params.get("username", "")
        if not username or not state.validate_message_token(username, _bearer_token(request)):
            raise HTTPException(status_code=401, detail="invalid message token")
        return {"history": [], "start_index": 0}

    @app.get("/llm/client-model-types")
    async def client_model_types() -> dict[str, list[Any]]:
        return {"types": []}

    @app.post("/preference/get")
    async def preference_get(request: Request) -> dict[str, Any]:
        payload = await _json_body(request)
        username = _required_string(payload, "username")
        if not state.validate_message_token(username, _token_from_body(payload)):
            raise HTTPException(status_code=401, detail="invalid message token")
        return {"preferences": {}}

    @app.post("/preference/overwrite")
    async def preference_overwrite(request: Request) -> dict[str, str]:
        payload = await _json_body(request)
        username = _required_string(payload, "username")
        if not state.validate_message_token(username, _token_from_body(payload)):
            raise HTTPException(status_code=401, detail="invalid message token")
        if not isinstance(payload.get("preferences"), dict):
            raise HTTPException(status_code=400, detail="preferences must be an object")
        return {"status": "success"}

    @app.get("/dynamics")
    async def dynamics(request: Request) -> dict[str, Any]:
        username = request.query_params.get("username", "")
        if not username or not state.validate_message_token(username, _bearer_token(request)):
            raise HTTPException(status_code=401, detail="invalid message token")
        return {"items": [], "has_more": False, "next_cursor": None}

    @app.get("/dynamics/unread")
    async def dynamics_unread(request: Request) -> dict[str, Any]:
        username = request.query_params.get("username", "")
        if not username or not state.validate_message_token(username, _bearer_token(request)):
            raise HTTPException(status_code=401, detail="invalid message token")
        return {"has_unread": False, "unread_count": 0, "unread_dynamic_count": 0, "unread_comment_count": 0}

    @app.get("/dynamics/{dynamic_id}/comments")
    async def dynamic_comments(dynamic_id: str, request: Request) -> dict[str, Any]:
        del dynamic_id
        username = request.query_params.get("username", "")
        if not username or not state.validate_message_token(username, _bearer_token(request)):
            raise HTTPException(status_code=401, detail="invalid message token")
        return {"items": [], "has_more": False, "next_cursor": None}

    @app.post("/dynamics/read")
    async def dynamics_read(request: Request) -> dict[str, bool]:
        payload = await _json_body(request)
        username = _required_string(payload, "username")
        if not state.validate_message_token(username, _token_from_body(payload)):
            raise HTTPException(status_code=401, detail="invalid message token")
        return {"ok": True}

    @app.post("/dynamics")
    async def dynamics_create(request: Request) -> dict[str, Any]:
        payload = await _json_body(request)
        username = _required_string(payload, "username")
        if not state.validate_message_token(username, _token_from_body(payload)):
            raise HTTPException(status_code=401, detail="invalid message token")
        return {"item": _mock_item(f"mock-post-{uuid.uuid4().hex[:12]}", comment=False)}

    @app.post("/dynamics/{dynamic_id}/comments")
    async def dynamic_comment_create(dynamic_id: str, request: Request) -> dict[str, Any]:
        payload = await _json_body(request)
        username = _required_string(payload, "username")
        if not state.validate_message_token(username, _token_from_body(payload)):
            raise HTTPException(status_code=401, detail="invalid message token")
        item_id = f"{dynamic_id}:comment-{uuid.uuid4().hex[:12]}"
        return {
            "item": _mock_item(
                item_id,
                comment=True,
                parent_comment_id=payload.get("parent_comment_id"),
            )
        }

    @app.post("/get_image")
    async def get_image() -> JSONResponse:
        return JSONResponse({"detail": "mock server has no stored images"}, status_code=404)

    @app.post("/update_image_client_path")
    async def update_image_client_path(request: Request) -> dict[str, Any]:
        payload = await _json_body(request)
        username = _required_string(payload, "username")
        if not state.validate_message_token(username, _token_from_body(payload)):
            raise HTTPException(status_code=401, detail="invalid message token")
        return {}

    @app.websocket("/chat_ws")
    async def chat_ws(websocket: WebSocket) -> None:
        connection_id = f"ws-{uuid.uuid4().hex[:12]}"
        await websocket.accept()
        state.ws_count += 1
        username: str | None = None

        async def send(message: dict[str, Any]) -> None:
            state.event_count += 1
            event_logger.emit(
                WS_EVENT,
                connection_id=connection_id,
                direction="server_to_client",
                username=username,
                event_type=message.get("type"),
                client_msg_id=message.get("client_msg_id"),
                reply_to=message.get("reply_to"),
                payload=message.get("payload", {}),
            )
            await websocket.send_json(message)

        async def protocol_error(code: str, message: str, reply_to: str | None = None) -> None:
            state.error_count += 1
            await send(_event("error", {"code": code, "message": message}, reply_to))

        await send(_event("system_ready", {"message": "mock server ready", "require_auth_before_chat": True}))
        try:
            attempts = 0
            while username is None and attempts < 5:
                attempts += 1
                try:
                    raw = await asyncio.wait_for(websocket.receive_text(), timeout=15)
                    event = json.loads(raw)
                except WebSocketDisconnect:
                    return
                except asyncio.TimeoutError:
                    await send(_event("auth_error", {"code": "AUTH_TIMEOUT", "message": "authentication timed out"}))
                    await websocket.close(code=1008)
                    return
                except (json.JSONDecodeError, UnicodeDecodeError):
                    await protocol_error("BAD_JSON", "message must be valid JSON")
                    continue
                if not isinstance(event, dict) or not isinstance(event.get("payload"), dict):
                    await protocol_error("BAD_MESSAGE", "message must be an object with an object payload")
                    continue
                event_type = event.get("type")
                payload = event["payload"]
                state.event_count += 1
                event_logger.emit(
                    WS_EVENT,
                    connection_id=connection_id,
                    direction="client_to_server",
                    username=None,
                    event_type=event_type,
                    client_msg_id=event.get("client_msg_id"),
                    reply_to=event.get("reply_to"),
                    payload=payload,
                )
                if event_type != "user_auth":
                    await protocol_error(
                        "AUTH_REQUIRED", "send user_auth before other events", event.get("client_msg_id")
                    )
                    continue
                candidate = payload.get("username")
                token = payload.get("token")
                if not isinstance(candidate, str) or not candidate or not isinstance(token, str) or not token:
                    await send(
                        _event(
                            "auth_error",
                            {"code": "MISSING_AUTH_FIELDS", "message": "username and token are required"},
                            event.get("client_msg_id"),
                        )
                    )
                    continue
                if not state.validate_message_token(candidate, token):
                    await send(
                        _event(
                            "auth_error",
                            {"code": "INVALID_TOKEN", "message": "invalid message token"},
                            event.get("client_msg_id"),
                        )
                    )
                    continue
                username = candidate
                await send(
                    _event(
                        "auth_ok",
                        {"message": "authentication successful", "capabilities": ["negative_ack_v1"]},
                        event.get("client_msg_id"),
                    )
                )

            if username is None:
                await send(
                    _event(
                        "auth_error",
                        {"code": "AUTH_ATTEMPTS_EXCEEDED", "message": "too many authentication attempts"},
                    )
                )
                await websocket.close(code=1008)
                return

            while True:
                try:
                    raw = await websocket.receive_text()
                    event = json.loads(raw)
                except WebSocketDisconnect:
                    return
                except (json.JSONDecodeError, UnicodeDecodeError):
                    await protocol_error("BAD_JSON", "message must be valid JSON")
                    continue
                if not isinstance(event, dict) or not isinstance(event.get("payload"), dict):
                    await protocol_error("BAD_MESSAGE", "message must be an object with an object payload")
                    continue
                event_type = event.get("type")
                payload = event["payload"]
                client_msg_id = event.get("client_msg_id")
                state.event_count += 1
                event_logger.emit(
                    WS_EVENT,
                    connection_id=connection_id,
                    direction="client_to_server",
                    username=username,
                    event_type=event_type,
                    client_msg_id=client_msg_id,
                    reply_to=event.get("reply_to"),
                    payload=payload,
                )
                if event_type == "hb_ping":
                    ping_id = payload.get("ping_id")
                    if ping_id is None:
                        await protocol_error("MISSING_PING_ID", "ping event must have ping_id", client_msg_id)
                    else:
                        await send(_event("hb_pong", {"ping_id": ping_id, "server_ts": _now_ms()}, client_msg_id))
                    continue
                if event_type not in SUPPORTED_EVENTS:
                    await protocol_error("UNSUPPORTED_EVENT", f"unsupported event type: {event_type}", client_msg_id)
                    continue
                await send(_event("server_ack", {"ok": True, "received_event_type": event_type}, client_msg_id))
                if event_type in {"user_text", "user_image"}:
                    await send(
                        _event(
                            "agent_message",
                            {
                                "uuid": f"mock-{uuid.uuid4().hex}",
                                "text": "",
                                "audio": "",
                                "expression": None,
                                "is_final_package": True,
                                "display_in_chat": True,
                            },
                            client_msg_id,
                        )
                    )
        finally:
            event_logger.emit("websocket_connection", connection_id=connection_id, action="closed", username=username)

    return app


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the AgentLuo local empty mock server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=60030)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--log-file", type=Path)
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    logger = EventLogger(verbose=args.verbose, log_file=args.log_file)
    state = MockState()
    app = create_app(state=state, event_logger=logger)
    logger.emit("server", action="started", host=args.host, port=args.port)
    try:
        uvicorn.run(app, host=args.host, port=args.port, log_level="warning")
    finally:
        logger.emit(
            "server",
            action="stopped",
            http_count=state.http_count,
            ws_count=state.ws_count,
            event_count=state.event_count,
            error_count=state.error_count,
        )
        logger.close()


app = create_app()


if __name__ == "__main__":
    main()
