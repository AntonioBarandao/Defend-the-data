#include "auth.h"
#include <iostream>

Auth::Auth(Database* db) {
    database = db;
}


bool Auth::register_user(std::string username,
                         std::string password) {

    std::string sql =
        "INSERT INTO users(username, password) VALUES('"
        + username + "','" + password + "');";

    char* errMsg = 0;

    int rc = sqlite3_exec(database->db,
                          sql.c_str(),
                          0,
                          0,
                          &errMsg);

    return rc == SQLITE_OK;
}

bool Auth::login(std::string username,
                 std::string password) {

    std::string sql =
        "SELECT * FROM users WHERE username='"
        + username +
        "' AND password='" +
        password + "';";

    sqlite3_stmt* stmt;

    sqlite3_prepare_v2(database->db,
                       sql.c_str(),
                       -1,
                       &stmt,
                       0);

    int result = sqlite3_step(stmt);

    bool success = (result == SQLITE_ROW);

    sqlite3_finalize(stmt);

    return success;
}