#pragma message(">>> register_types.cpp IS BEING COMPILED <<<")

#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>

#include "auth_wrapper.h"

using namespace godot;

void initialize_auth(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<AuthWrapper>();
}

void uninitialize_auth(ModuleInitializationLevel level) {
}

extern "C" {

GDExtensionBool GDE_EXPORT auth_library_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization
) {
    GDExtensionBinding::InitObject init_obj(
        p_get_proc_address,
        p_library,
        r_initialization
    );

    init_obj.register_initializer(initialize_auth);
    init_obj.register_terminator(uninitialize_auth);
    init_obj.set_minimum_library_initialization_level(
        MODULE_INITIALIZATION_LEVEL_SCENE
    );

    return init_obj.init();
}

}