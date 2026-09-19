#include "pcm_stream_decoder.h"
#include <godot_cpp/core/class_db.hpp>
using namespace godot;
void PcmStreamDecoder::_bind_methods() {
    ClassDB::bind_method(D_METHOD("append", "bytes"), &PcmStreamDecoder::append);
    ClassDB::bind_method(D_METHOD("finish"), &PcmStreamDecoder::finish);
    ClassDB::bind_method(D_METHOD("get_status"), &PcmStreamDecoder::get_status);
    ClassDB::bind_method(D_METHOD("read_frames", "max_count"), &PcmStreamDecoder::read_frames);
    ClassDB::bind_method(D_METHOD("get_amplitude", "frame_index"), &PcmStreamDecoder::get_amplitude);
}
Dictionary PcmStreamDecoder::get_status() const {
    Dictionary status;
    status["ok"] = false;
    status["code"] = "NOT_IMPLEMENTED";
    for (const char *key : {"sample_rate", "channels", "bits", "queued_frames", "decoded_frames", "input_bytes"}) status[key] = 0;
    status["finished"] = false;
    return status;
}
Dictionary PcmStreamDecoder::append(const PackedByteArray &) { return get_status(); }
Dictionary PcmStreamDecoder::finish() { return get_status(); }
PackedVector2Array PcmStreamDecoder::read_frames(int) { return {}; }
double PcmStreamDecoder::get_amplitude(int64_t) const { return 0; }
