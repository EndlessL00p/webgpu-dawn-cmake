# How Dawn is built: one shared library with its C API and nothing else.
# Every option is forced, so a cache from an earlier configure cannot drift from this file.

# One monolithic shared library, webgpu_dawn, holding Dawn, Tint and their dependencies.
set(DAWN_BUILD_MONOLITHIC_LIBRARY SHARED CACHE STRING "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(DAWN_ENABLE_INSTALL ON CACHE BOOL "" FORCE)
set(TINT_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)

# Dawn fetches its dependencies itself, at the commits its DEPS file pins: no depot_tools.
set(DAWN_FETCH_DEPENDENCIES ON CACHE BOOL "" FORCE)

# Nothing but the library: no samples, tests, tools, benchmarks, fuzzers or Node bindings.
set(DAWN_BUILD_SAMPLES OFF CACHE BOOL "" FORCE)
set(DAWN_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(DAWN_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(DAWN_BUILD_FUZZERS OFF CACHE BOOL "" FORCE)
set(DAWN_BUILD_NODE_BINDINGS OFF CACHE BOOL "" FORCE)
set(DAWN_BUILD_PROTOBUF OFF CACHE BOOL "" FORCE)
set(DAWN_USE_GLFW OFF CACHE BOOL "" FORCE)
set(TINT_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(TINT_BUILD_CMD_TOOLS OFF CACHE BOOL "" FORCE)
set(TINT_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(TINT_BUILD_FUZZERS OFF CACHE BOOL "" FORCE)
set(TINT_BUILD_IR_BINARY OFF CACHE BOOL "" FORCE)
set(TINT_BUILD_GLSL_VALIDATOR OFF CACHE BOOL "" FORCE)

# Backends: Direct3D 12 (and 11) on Windows, Metal on Apple platforms, Vulkan on Windows and Linux;
# Dawn's defaults. OpenGL and OpenGL ES are left out of the desktop builds.
set(DAWN_ENABLE_DESKTOP_GL OFF CACHE BOOL "" FORCE)
set(DAWN_ENABLE_OPENGLES OFF CACHE BOOL "" FORCE)

if(WIN32)
	# DXC, built with Dawn and shipped as dxcompiler.dll beside the library: without it Dawn compiles
	# Direct3D 12 shaders with the older, slower FXC.
	set(DAWN_USE_BUILT_DXC ON CACHE BOOL "" FORCE)
	# The static C runtime, in the library and in DXC, so they run with whatever Visual C++ runtime
	# the machine has, whichever Visual Studio built them. Nothing crosses the C API that one runtime
	# allocates and another frees.
	# A plain variable, so it applies to Dawn below this directory and not to a project that adds this
	# one from source.
	set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
	# Abseil, built into the library, picks its runtime itself.
	set(ABSL_MSVC_STATIC_RUNTIME ON CACHE BOOL "" FORCE)
	set(LLVM_USE_CRT_RELEASE MT CACHE STRING "" FORCE)
	set(LLVM_USE_CRT_DEBUG MTd CACHE STRING "" FORCE)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
	# Surfaces for both Linux window systems.
	set(DAWN_USE_X11 ON CACHE BOOL "" FORCE)
	set(DAWN_USE_WAYLAND ON CACHE BOOL "" FORCE)
endif()

# One layout on every platform: lib, not lib64. A plain variable, like the runtime above.
set(CMAKE_INSTALL_LIBDIR lib)
