#include <iostream>
#include "database.h"
#include "auth.h"

int main() {

    Database db;

    if (!db.open()) {
        return 1;
    }

    db.create_tables();

    Auth auth(&db);

    bool registered =
        auth.register_user("Admin_TAJ", "1234");

    if (registered) {
        std::cout << "Registration successful\n";
    } else {
        std::cout << "Registration failed\n";
    }

    bool logged_in =
        auth.login("Admin_TAJ", "1234");

    if (logged_in) {
        std::cout << "Login successful\n";
    } else {
        std::cout << "Login failed\n";
    }

    db.close();

    return 0;
}