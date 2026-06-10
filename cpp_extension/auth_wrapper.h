#ifndef AUTH_WRAPPER_H
#define AUTH_WRAPPER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>

#include "database.h"
#include "auth.h"

using namespace godot;

class AuthWrapper : public RefCounted {
    GDCLASS(AuthWrapper, RefCounted);

private:
    Database db;
    Auth* auth;

protected:
    static void _bind_methods();

public:
    AuthWrapper();
    ~AuthWrapper();

    bool login(String username, String password);
    bool register_user(String username, String password);
};

#endif