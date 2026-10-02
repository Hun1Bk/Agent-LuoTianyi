extends SceneTree
const Session = preload("res://src/session/chat_session.gd")
const Transport = preload("res://src/network/websocket_transport.gd")
const Outbox = preload("res://src/network/reliable_outbox.gd")
var failures: Array[String] = []

class QuietMedia extends Node:
	signal playback_finished(id: String, code: String)
	signal message_audio_changed(id: String, state: Dictionary)
	signal mouth_changed(value: float)
	signal state_changed(state: Dictionary)
	func reset() -> void: pass
	func set_scope(_server: String, _username: String) -> Error: return OK

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func run() -> void:
	var transport := Transport.new(func(): return 1000)
	var session := Session.new(transport, null, QuietMedia.new())
	root.add_child(session)
	transport.set_process(false)
	transport._set_state("ready", "")
	var arrivals: Array[String] = []
	session.live_message_added.connect(func(id, _role): arrivals.append(id))
	var id: String = session.send_text("保留原消息")
	var original: Dictionary = session.get_messages()[0]
	var packets: Array[Dictionary] = transport._outbox.take_ready(1000, true)
	transport._outbox.acknowledge(id, {"ok":false,"retryable":false,"code":"REJECTED"}, 1001)
	check(session.can_retry_message(id), "explicit rejection is retryable")
	check(session.retry_message(id) == OK and session.retry_message(id) == ERR_UNAVAILABLE, "retry rejects duplicate clicks")
	packets = transport._outbox.take_ready(1000, true)
	check(packets.size() == 1 and packets[0].client_msg_id == id and packets[0].payload.message == original.text, "manual retry preserves wire ID and payload")
	check(session.get_messages().size() == 1 and session.get_messages()[0].timestamp == original.timestamp and arrivals == [id], "retry preserves bubble, timestamp and arrival count")
	transport._outbox.acknowledge(id, {"ok":true}, 1001)
	check(session.get_messages()[0].status == "sent" and not session.can_retry_message(id), "ACK updates the original bubble")
	_test_unknown(session, transport)
	_test_history_rejection(session, transport)
	_test_image(session, transport)
	session.stop()
	check(transport._outbox._rejected.is_empty() and session._unsent_requests.is_empty(), "account stop releases rejected requests")
	session.queue_free()
	await process_frame
	print("Message retry: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _test_unknown(session: Node, transport: Node) -> void:
	var id: String = session.send_text("送达结果未知")
	transport._outbox.take_ready(1000, true)
	transport._outbox.take_ready(241000, false)
	check(not session.can_retry_message(id) and session.retry_message(id) == ERR_UNAVAILABLE, "uncertain delivery never permits manual retry")
	id = session.send_text("停止发送")
	transport._outbox.take_ready(1000, true)
	transport._outbox.stop()
	check(not session.can_retry_message(id), "transport stop does not prove non-delivery")

func _test_history_rejection(session: Node, transport: Node) -> void:
	session._waiting_history = true
	var id: String = session.send_text("历史屏障中的原请求")
	for index in 128: transport._outbox.enqueue("user_text", {}, true, 1000)
	session._release_history_sends()
	check(session.can_retry_message(id), "unsent history request retains its payload")
	check(session.retry_message(id) == ERR_BUSY and session.can_retry_message(id), "full outbox preserves rejected request")
	transport._outbox.stop()
	check(session.retry_message(id) == OK, "unsent request can retry when capacity returns")
	var wire: String = session._message_wires[id]
	transport._outbox.take_ready(1000, true)
	transport._outbox.acknowledge(wire, {"ok":true}, 1001)
	check(session._by_id[id].status == "sent" and session._by_id[id].id == id, "new wire ID maps back to stable local bubble")

func _test_image(session: Node, transport: Node) -> void:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.SKY_BLUE)
	var id: String = session.send_image(image.save_png_to_buffer(), "image/png")
	var original: Array[Dictionary] = transport._outbox.take_ready(1000, true)
	check(not id.is_empty(), "normalized image can be queued")
	transport._outbox.acknowledge(id, {"ok":false,"retryable":false,"code":"REJECTED"}, 1001)
	check(session.retry_message(id) == OK, "explicit image rejection permits retry")
	var retried: Array[Dictionary] = transport._outbox.take_ready(1000, true)
	check(retried.size() == 1 and retried[0] == original[0], "image retry preserves normalized bytes and complete envelope")
	transport._outbox.acknowledge(id, {"ok":true}, 1001)
