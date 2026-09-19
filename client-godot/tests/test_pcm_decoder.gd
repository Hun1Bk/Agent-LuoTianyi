extends SceneTree
var failures: Array[String] = []

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		print("FAIL: ", description)

func wav(pcm: PackedByteArray, bits: int = 16, channels: int = 1, rate: int = 24000, format: int = 1) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(44)
	for pair in [[0,"RIFF"], [8,"WAVE"], [12,"fmt "], [36,"data"]]:
		for i in 4:
			bytes[pair[0] + i] = pair[1].unicode_at(i)
	bytes.encode_u32(4, 36 + pcm.size())
	bytes.encode_u32(16, 16)
	bytes.encode_u16(20, format)
	bytes.encode_u16(22, channels)
	bytes.encode_u32(24, rate)
	bytes.encode_u32(28, rate * channels * bits / 8)
	bytes.encode_u16(32, channels * bits / 8)
	bytes.encode_u16(34, bits)
	bytes.encode_u32(40, pcm.size())
	bytes.append_array(pcm)
	return bytes

func decoder():
	return ClassDB.instantiate("PcmStreamDecoder")

func _initialize() -> void:
	if not ClassDB.class_exists("PcmStreamDecoder"):
		print("ENVIRONMENT: decoder extension unavailable")
		quit(2)
		return
	var data := wav(PackedByteArray([0,64,0,192,0,0]))
	data.encode_u32(4, 0xffffffff)
	data.encode_u32(40, 0xffffffff)
	var stream = decoder()
	for part in [data.slice(0,3), data.slice(3,23), data.slice(23,45), data.slice(45)]:
		check(stream.append(part).ok, "split header and partial sample accepted")
	var status: Dictionary = stream.finish()
	check(status.ok and status.finished and status.sample_rate == 24000 and status.decoded_frames == 3, "streamable mono completed")
	check(stream.read_frames(2) == PackedVector2Array([Vector2(.5,.5), Vector2(-.5,-.5)]), "PCM16 normalized stereo frames")
	check(stream.read_frames(8) == PackedVector2Array([Vector2.ZERO]), "reads consume only available frames")
	check(is_equal_approx(stream.get_amplitude(0), sqrt(0.5/3.0)), "native RMS follows absolute frame")
	check(stream.get_amplitude(3) == 0.0, "out of range amplitude zero")
	check(stream.finish().ok and stream.append(data).code == "STREAM_FINISHED", "finish idempotent and rejects late append")
	for sample in [[8, PackedByteArray([192,64]), 1], [24, PackedByteArray([0,0,64,0,0,192]), 1], [32, PackedByteArray([0,0,0,64,0,0,0,192]), 1], [32, PackedByteArray([0,0,0,63,0,0,0,191]), 3]]:
		stream = decoder()
		check(stream.append(wav(sample[1], sample[0], 2, 48000, sample[2])).ok and stream.finish().ok, "supported stereo format")
		check(stream.read_frames(1) == PackedVector2Array([Vector2(.5,-.5)]), "stereo sign and scale")
	for malformed in [PackedByteArray([1,2,3,4]), data.slice(0,43), data.slice(0,45), wav(PackedByteArray())]:
		stream = decoder()
		stream.append(malformed)
		check(not stream.finish().ok and stream.read_frames(100).is_empty(), "truncated or empty rejected without partial data")
	stream = decoder()
	check(not stream.append(wav(PackedByteArray([0,0]),16,1,24000,6)).ok, "compressed format rejected")
	check(not stream.append(data).ok, "decode failure sticky")
	stream = decoder()
	var enormous := PackedByteArray()
	enormous.resize(8*1024*1024+1)
	check(stream.append(enormous).code == "BUFFER_LIMIT", "input bound enforced")
	print("PCM decoder: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
