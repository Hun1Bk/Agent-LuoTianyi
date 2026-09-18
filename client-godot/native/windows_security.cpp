#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
using namespace godot;

class WindowsSecurity : public RefCounted {
    GDCLASS(WindowsSecurity, RefCounted);
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("encrypt_password", "public_key_pem", "password"), &WindowsSecurity::encrypt_password);
        ClassDB::bind_method(D_METHOD("protect_secret", "plain", "scope"), &WindowsSecurity::protect_secret);
        ClassDB::bind_method(D_METHOD("unprotect_secret", "cipher", "scope"), &WindowsSecurity::unprotect_secret);
    }
public:
    Dictionary unavailable() const {
        Dictionary result;
        result["ok"] = false;
        result["data"] = PackedByteArray();
        result["error"] = "UNAVAILABLE";
        return result;
    }
    Dictionary encrypt_password(const String &, const String &) const { return unavailable(); }
    Dictionary protect_secret(const PackedByteArray &, const PackedByteArray &) const { return unavailable(); }
    Dictionary unprotect_secret(const PackedByteArray &, const PackedByteArray &) const { return unavailable(); }
};

void initialize_security(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<WindowsSecurity>();
}
void terminate_security(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT windows_security_init(
        GDExtensionInterfaceGetProcAddress address, GDExtensionClassLibraryPtr library,
        GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(address, library, initialization);
    init.register_initializer(initialize_security);
    init.register_terminator(terminate_security);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
