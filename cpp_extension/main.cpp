#include <iostream>
#include <string>

#include "database.h"
#include "auth.h"

int main() {

    Database db;

    if (!db.open()) {
        std::cout << "Failed to open database.\n";
        return 1;
    }

    std::cout << "Database opened successfully!\n";
    
    db.create_tables();

    Auth auth(&db);

    int choice;

    std::cout << "==== LOGIN SIMULATOR ====\n";
    std::cout << "1. Register\n";
    std::cout << "2. Login\n";
    std::cout << "Choice: ";
    std::cin >> choice;

    std::string username;
    std::string password;

    std::cout << "\nUsername: ";
    std::cin >> username;

    std::cout << "Password: ";
    std::cin >> password;

    if (choice == 1) {

        if (auth.register_user(username, password)) {
            std::cout << "\nRegistration successful!\n";
        }
        else {
            std::cout << "\nRegistration failed!\n";
        }

    }
    else if (choice == 2) {

        if (auth.login(username, password)) {
            std::cout << "\nLogin successful!\n";
        }
        else {
            std::cout << "\nLogin failed!\n";
        }

    }
    else {
        std::cout << "\nInvalid option.\n";
    }

    db.close();

    return 0;
}