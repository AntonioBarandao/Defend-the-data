cmake_minimum_required(VERSION 3.15)

project(auth_extension)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Godot C++ bindings
add_subdirectory(godot-cpp)

# -------------------------------------------------
# SOURCE FILES (IMPORTANT: include ALL .cpp files)
# -------------------------------------------------
add_library(auth SHARED
    cpp_extension/auth_wrapper.cpp
    cpp_extension/register_types.cpp
    cpp_extension/database.cpp
    cpp_extension/auth.cpp
    sqlite/sqlite3.c
)

# -------------------------------------------------
# INCLUDE DIRECTORIES
# -------------------------------------------------
target_include_directories(auth PRIVATE
    ${CMAKE_SOURCE_DIR}/godot-cpp/include
    ${CMAKE_SOURCE_DIR}/cpp_extension
    ${CMAKE_SOURCE_DIR}/sqlite
)

# -------------------------------------------------
# LINK GODOT C++ BINDINGS
# -------------------------------------------------
target_link_libraries(auth PRIVATE godot-cpp)