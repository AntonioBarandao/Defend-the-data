#include "database.h"
#include <iostream>
#include <filesystem>

bool Database::open() {

    int rc = sqlite3_open("/root/AntonioBarandao.github.io/My-Website/Defend-The-Data-Virus-Tower-Defense-/Acc_Src/game.db", &db);
    std::cout << "Current directory: "
          << std::filesystem::current_path()
          << std::endl;

    if (rc) {
        std::cout << "Cannot open database\n";
        return false;
    }

    return true;
}

void Database::close() {
    sqlite3_close(db);
}

void Database::create_tables() {

    const char* sql =
        "CREATE TABLE IF NOT EXISTS users ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "username TEXT UNIQUE,"
        "password TEXT);";

    char* errMsg = 0;

    sqlite3_exec(db, sql, 0, 0, &errMsg);
}