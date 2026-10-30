# webgpu-dawn-cmake: Dawn (Google's WebGPU implementation) as one shared library with its C API.
#
# Two ways in, with the same targets:
#   - a release archive: find_package(Dawn CONFIG) on the unpacked archive (see README.md);
#   - from source: add this project with FetchContent or add_subdirectory, which builds Dawn here.
# Either way, link dawn::webgpu_dawn and call dawn_copy_runtime(<executable>).
#
# scripts/build.ps1 builds this project standalone and packages the install tree as an archive.

# 3.22: Dawn's own minimum.
cmake_minimum_required(VERSION 3.22)

# The Dawn release this project builds: a tag of https://github.com/google/dawn/releases.
# Archive tags are <DAWN_TAG>-<packaging revision>, such as v20261027.184652-1.
set(DAWN_TAG "v20261027.184652" CACHE STRING "Dawn release tag to build")

project(webgpu-dawn-cmake LANGUAGES C CXX)

get_property(_WebGpuDawnMultiConfig GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT _WebGpuDawnMultiConfig AND NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

include(cmake/DawnOptions.cmake)

include(FetchContent)
FetchContent_Declare(dawn
	GIT_REPOSITORY https://github.com/google/dawn.git
	GIT_TAG ${DAWN_TAG}
	GIT_SHALLOW TRUE
	GIT_PROGRESS TRUE
	# Dawn fetches its own dependencies at configure time (DAWN_FETCH_DEPENDENCIES); no submodules.
	GIT_SUBMODULES ""
)
FetchContent_MakeAvailable(dawn)

#--------------------------------------------------------------------------------------------------
# Exported interface. The same in source mode (here) and archive mode (cmake/DawnConfig.cmake),
# so a consumer writes one path:
#
#   dawn::webgpu_dawn     - the library, with webgpu.h, Dawn's headers and WGPU_SHARED_LIBRARY
#   dawn_copy_runtime(T)  - copies the library, and on Windows dxcompiler.dll, beside target T
#--------------------------------------------------------------------------------------------------

# Dawn defines dawn::webgpu_dawn itself, as an alias of webgpu_dawn.
set(DAWN_RUNTIME_FILES "$<TARGET_FILE:webgpu_dawn>")
if(DAWN_USE_BUILT_DXC)
	list(APPEND DAWN_RUNTIME_FILES "$<TARGET_FILE:dxcompiler>")
endif()
set(DAWN_RUNTIME_FILES "${DAWN_RUNTIME_FILES}" CACHE INTERNAL "Files to ship beside an executable using Dawn")

function(dawn_copy_runtime Target)
	add_custom_command(TARGET ${Target} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy_if_different ${DAWN_RUNTIME_FILES} "$<TARGET_FILE_DIR:${Target}>"
		COMMAND_EXPAND_LISTS
		VERBATIM
	)
	if(DAWN_USE_BUILT_DXC)
		add_dependencies(${Target} dxcompiler)
	endif()
endfunction()

# Packaging, for standalone builds only: `cmake --install` assembles the archive's layout.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
	include(cmake/Package.cmake)
endif()
