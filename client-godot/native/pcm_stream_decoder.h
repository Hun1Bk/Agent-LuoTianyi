#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

namespace godot {
class PcmStreamDecoder : public RefCounted {
    GDCLASS(PcmStreamDecoder, RefCounted);
protected:
    static void _bind_methods();
public:
    Dictionary append(const PackedByteArray &bytes);
    Dictionary finish();
    Dictionary get_status() const;
    PackedVector2Array read_frames(int max_count);
    double get_amplitude(int64_t frame_index) const;
};
}
