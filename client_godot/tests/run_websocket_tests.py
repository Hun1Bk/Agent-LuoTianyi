"""Real sockets on loopback; fixture rejects incompatible authentication and retry IDs."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import threading
from websockets.sync.server import serve
from websockets.exceptions import ConnectionClosed

PROJECT = Path(__file__).resolve().parents[1]


def run(godot):
    errors = []
    dropped_ids = []
    rejected_connections = []
    lock = threading.Lock()

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
                                     "res://tests/test_websocket_transport.gd"],
                                    env={**os.environ, "GODOT_TEST_SERVER": f"http://127.0.0.1:{port}"},
                                    capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=45)
            print(result.stdout)
            if result.returncode or "ERROR:" in result.stdout + result.stderr or errors:
                raise RuntimeError("WebSocket contract failed: " + result.stderr + repr(errors))
            assert len(dropped_ids) == 2, "expected original and retry"
            assert len(rejected_connections) == 1, "rejected credentials reconnected"
        finally:
            server.shutdown()
            thread.join(timeout=3)
    print("Loopback WebSocket contract: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    run(parser.parse_args().godot)
