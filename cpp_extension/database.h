#ifndef DATABASE_H
#define DATABASE_H

#include <sqlite3.h>

class Database {
public:
    sqlite3* db;

    bool open();
    void close();
    void create_tables();
};

#endif