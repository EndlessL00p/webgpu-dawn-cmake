# Built standalone against an unpacked release archive, the way a consumer uses it:
#   cmake -B build -S tests/smoke -DCMAKE_PREFIX_PATH=<unpacked archive>
cmake_minimum_required(VERSION 3.21)
project(webgpu_dawn_smoke C)

find_package(Dawn CONFIG REQUIRED)

add_executable(smoke Smoke.c)
target_link_libraries(smoke PRIVATE dawn::webgpu_dawn)
# The library, and on Windows DXC, beside the executable.
dawn_copy_runtime(smoke)
