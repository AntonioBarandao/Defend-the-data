#ifndef AUTH_H
#define AUTH_H

#include <string>
#include "database.h"

class Auth {
public:
    Database* database;

    Auth(Database* db);

    bool register_user(std::string username,
                       std::string password);

    bool login(std::string username,
               std::string password);
};

#endif