import json

import pytest
from cryptography.hazmat.primitives import serialization
from fastapi.testclient import TestClient

from local_mock_server import EventLogger, MockState, create_app


@pytest.fixture
def client(tmp_path):
    logger = EventLogger(log_file=tmp_path / "events.jsonl")
    app = create_app(MockState(), logger)
    with TestClient(app) as test_client:
        yield test_client, logger
    logger.close()


def _login(client):
    response = client.post(
        "/auth/login",
        json={"username": "test-user", "password": "encrypted", "request_token": True},
    )
    assert response.status_code == 200
    return response.json()


def test_account_and_empty_http_contract(client):
    test_client, _ = client
    public_key = test_client.get("/auth/public_key")
    assert public_key.status_code == 200
    serialization.load_pem_public_key(public_key.json()["public_key"].encode())

    session = _login(test_client)
    assert all(session[field] for field in ("user_id", "login_token", "message_token"))
    auto = test_client.post(
        "/auth/auto_login",
        json={"username": session["user_id"], "token": session["login_token"]},
    )
    assert auto.status_code == 200
    registered = test_client.post(
        "/auth/register",
        json={"username": "registered-user", "password": "encrypted", "invite_code": "local"},
    )
    assert registered.status_code == 200
    reset = test_client.post(
        "/auth/reset_account",
        json={"new_username": "reset-user", "new_password": "encrypted", "invite_code": "local"},
    )
    assert reset.status_code == 200

    headers = {"Authorization": f"Bearer {session['message_token']}"}
    assert test_client.get("/llm/client-model-types").json() == {"types": []}
    assert test_client.get("/history?username=test-user", headers=headers).json() == {
        "history": [],
        "start_index": 0,
    }
    assert test_client.get("/dynamics?username=test-user", headers=headers).json() == {
        "items": [],
        "has_more": False,
        "next_cursor": None,
    }
    assert test_client.get("/dynamics/unread?username=test-user", headers=headers).json()["unread_count"] == 0
    assert test_client.post(
        "/preference/get",
        json={"username": "test-user", "token": session["message_token"]},
    ).json() == {"preferences": {}}
    assert test_client.post(
        "/preference/overwrite",
        json={"username": "test-user", "token": session["message_token"], "preferences": {}},
    ).json() == {"status": "success"}
    assert test_client.post(
        "/dynamics/read",
        json={"username": "test-user", "token": session["message_token"]},
    ).json() == {"ok": True}
    created = test_client.post(
        "/dynamics",
        json={"username": "test-user", "token": session["message_token"], "content": "hello"},
    )
    assert created.status_code == 200
    assert created.json()["item"]["allow_comment"] is True
    comment = test_client.post(
        "/dynamics/mock-post/comments",
        json={
            "username": "test-user",
            "token": session["message_token"],
            "content": "reply",
            "parent_comment_id": None,
        },
    )
    assert comment.status_code == 200
    assert comment.json()["item"]["dynamic_id"] == "mock-post"
    assert (
        test_client.get("/history?username=test-user", headers={"Authorization": "Bearer invalid"}).status_code == 401
    )


def test_websocket_handshake_heartbeat_ack_and_empty_reply(client):
    test_client, _ = client
    session = _login(test_client)
    with test_client.websocket_connect("/chat_ws") as websocket:
        assert websocket.receive_json()["type"] == "system_ready"
        websocket.send_json(
            {
                "type": "user_auth",
                "client_msg_id": "auth-1",
                "payload": {
                    "username": "test-user",
                    "token": session["message_token"],
                    "capabilities": ["negative_ack_v1"],
                },
            }
        )
        auth_ok = websocket.receive_json()
        assert auth_ok["type"] == "auth_ok"
        assert auth_ok["reply_to"] == "auth-1"

        websocket.send_json({"type": "hb_ping", "client_msg_id": "ping-1", "payload": {"ping_id": 7}})
        pong = websocket.receive_json()
        assert pong["type"] == "hb_pong"
        assert pong["payload"]["ping_id"] == 7

        websocket.send_json({"type": "user_text", "client_msg_id": "message-1", "payload": {"message": "hello"}})
        ack = websocket.receive_json()
        reply = websocket.receive_json()
        assert ack["type"] == "server_ack"
        assert ack["reply_to"] == "message-1"
        assert reply["type"] == "agent_message"
        assert reply["reply_to"] == "message-1"
        assert reply["payload"]["uuid"]
        assert reply["payload"]["text"] == ""
        assert reply["payload"]["is_final_package"] is True


def test_websocket_rejects_invalid_token(client):
    test_client, _ = client
    with test_client.websocket_connect("/chat_ws") as websocket:
        assert websocket.receive_json()["type"] == "system_ready"
        websocket.send_json(
            {
                "type": "user_auth",
                "client_msg_id": "auth-invalid",
                "payload": {"username": "unknown", "token": "invalid", "capabilities": []},
            }
        )
        response = websocket.receive_json()
        assert response["type"] == "auth_error"
        assert response["payload"]["code"] == "INVALID_TOKEN"


def test_logs_are_jsonl_and_redacted(client, tmp_path):
    test_client, logger = client
    session = _login(test_client)
    logger.emit("test", password="plain-password", token=session["message_token"], image_base64="aGVsbG8=")
    logger.close()
    records = [json.loads(line) for line in (tmp_path / "events.jsonl").read_text(encoding="utf-8").splitlines()]
    serialized = json.dumps(records, ensure_ascii=False)
    assert "plain-password" not in serialized
    assert session["message_token"] not in serialized
    assert "aGVsbG8=" not in serialized
    assert any(record.get("kind") == "http" for record in records)
    assert all("ts" in record for record in records)
