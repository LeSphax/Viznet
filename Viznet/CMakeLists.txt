cmake_minimum_required(VERSION 3.0)
project(Viznet)

set(CMAKE_CXX_STANDARD 17)

include_directories(${YOUR_INCLUDE_DIRECTORIES})
link_directories(${YOUR_LIBRARY_DIRECTORIES})

file(GLOB SOURCE_FILES
    ./*.cpp
    ./*.hpp
    ./*.h
    ./*.mm
)

add_executable(YourTarget ${SOURCE_FILES})

target_link_libraries(YourTarget ${YOUR_LIBRARIES})
