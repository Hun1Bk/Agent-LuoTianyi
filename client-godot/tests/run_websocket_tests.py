"""Real sockets on loopback; fixture rejects incompatible authentication and retry IDs."""
import argparse
import json
import importlib.util
import os
from pathlib import Path
import subprocess
import threading
import sys
from websockets.sync.server import serve
from websockets.exceptions import ConnectionClosed

PROJECT = Path(__file__).resolve().parents[1]


def run(godot, script="res://tests/test_websocket_transport.gd"):
    errors = []
    dropped_ids = []
    rejected_connections = []
    lock = threading.Lock()
    replies = json.loads((PROJECT.parent / "contracts/chat/reply_events.json").read_text(encoding="utf-8"))
    # Consume the same wire fixtures with the existing Python client's real parser.
    spec = importlib.util.spec_from_file_location("contract_event_types", PROJECT.parent / "client/src/network/event_types.py")
    wire = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = wire
    spec.loader.exec_module(wire)
    for event in replies:
        parsed = wire.parse_server_message(json.dumps(event))
        assert parsed.event_type is not None
        if event["type"] == "agent_message":
            normalized = wire.normalize_agent_message(parsed)
            assert normalized.uuid == event["payload"]["uuid"]
            assert normalized.display_in_chat == event["payload"]["display_in_chat"]
            assert normalized.is_ephemeral == event["payload"]["is_ephemeral"]
            assert wire.is_audio_terminal(normalized) == event["payload"]["is_final_package"]

    def handler(socket):
        def send(kind, payload, reply_to=None):
            socket.send(json.dumps({"type": kind, "payload": payload, "reply_to": reply_to, "ts": 0}))

        try:
            assert socket.request.path == "/prefix/chat_ws", "prefix missing"
            send("system_ready", {"require_auth_before_chat": True})
            auth = json.loads(socket.recv(timeout=3))
            assert auth["type"] == "user_auth", "wrong auth event"
            assert set(auth) == {"type", "payload", "client_msg_id", "ts", "reply_to"}, "envelope mismatch"
            fields = auth["payload"]
            assert fields["token"] in {"message-test", "rotated-message"}, "message token required"
            assert fields["capabilities"] == ["negative_ack_v1"], "negative ACK capability missing"
            username = fields["username"]
            if username == "reject" and fields["token"] == "message-test":
                rejected_connections.append(1)
                send("auth_error", {"code": "INVALID_TOKEN", "message": "never show raw error"}, auth["client_msg_id"])
                socket.recv(timeout=3)  # Like the server, keep failed auth open until the client leaves.
                return
            if username == "policy":
                send("auth_error", {"code": "AUTH_ATTEMPTS_EXCEEDED"}, auth["client_msg_id"])
                socket.close(1008)
                return
            if username == "slow":
                try:
                    socket.recv(timeout=3)
                except TimeoutError:
                    pass
                return
            send("auth_ok", {"capabilities": ["negative_ack_v1"]}, auth["client_msg_id"])
            if username == "bad":
                socket.send("[]")
                socket.recv(timeout=3)
                return
            for raw in socket:
                packet = json.loads(raw)
                if packet["type"] == "hb_ping":
                    send("hb_pong", packet["payload"], packet["client_msg_id"])
                    send("heartbeat_seen", packet["payload"])
                elif packet["type"] == "user_text":
                    if username == "drop":
                        with lock:
                            dropped_ids.append(packet["client_msg_id"])
                            if len(dropped_ids) == 1:
                                socket.close(1012, "fixture restart")
                                return
                            assert len(set(dropped_ids)) == 1, "retry changed client_msg_id"
                    send("server_ack", {"ok": True}, packet["client_msg_id"])
                    if username == "conversation":
                        assert packet["payload"]["llm_mode"] == {"types": []}
                        for event in replies:
                            socket.send(json.dumps(event))
                        continue
                    send("agent_message", {"uuid": "reply-test", "text": "收到", "audio": None,
                                           "expression": "normal", "is_final_package": True})
        except ConnectionClosed:
            pass
        except Exception as error:
            errors.append(str(error))

    with serve(handler, "127.0.0.1", 0, max_size=8 * 1024 * 1024) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            port = server.socket.getsockname()[1]
            result = subprocess.run([godot, "--headless", "--path", str(PROJECT), "--script",
                                     script],
                                    env={**os.environ, "GODOT_TEST_SERVER": f"http://127.0.0.1:{port}"},
                                    capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=45)
            print(result.stdout)
            if result.returncode or "ERROR:" in result.stdout + result.stderr or errors:
                raise RuntimeError("WebSocket contract failed: " + result.stderr + repr(errors))
            if script == "res://tests/test_websocket_transport.gd":
                assert len(dropped_ids) == 2, "expected original and retry"
                assert len(rejected_connections) == 1, "rejected credentials reconnected"
        finally:
            server.shutdown()
            thread.join(timeout=3)
    print("Loopback WebSocket contract: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--script", default="res://tests/test_websocket_transport.gd")
    args = parser.parse_args()
    run(args.godot, args.script)
