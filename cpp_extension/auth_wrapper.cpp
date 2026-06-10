#include "auth_wrapper.h"

void AuthWrapper::_bind_methods() {
    ClassDB::bind_method(
        D_METHOD("login", "username", "password"),
        &AuthWrapper::login
    );

    ClassDB::bind_method(
        D_METHOD("register_user", "username", "password"),
        &AuthWrapper::register_user
    );
}

AuthWrapper::AuthWrapper() {
    db.open();
    db.create_tables();

    auth = new Auth(&db);
}

AuthWrapper::~AuthWrapper() {
    delete auth;
    db.close();
}

bool AuthWrapper::login(String username, String password) {
    return auth->login(
        username.utf8().get_data(),
        password.utf8().get_data()
    );
}

bool AuthWrapper::register_user(String username, String password) {
    return auth->register_user(
        username.utf8().get_data(),
        password.utf8().get_data()
    );
}