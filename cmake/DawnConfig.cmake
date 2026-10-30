# webgpu-dawn-cmake: find_package(Dawn CONFIG) on an unpacked release archive.
#
#   dawn::webgpu_dawn     - the shared library, with webgpu.h, Dawn's headers and WGPU_SHARED_LIBRARY
#   dawn_copy_runtime(T)  - copies the library, and on Windows dxcompiler.dll, beside target T
#   DAWN_RUNTIME_FILES    - those files, for install rules
#
# The same names as a source build (this project's CMakeLists.txt). The archive holds one Release
# build, which serves every configuration of a consumer: the C API does not depend on the C++
# runtime, so Debug consumers use it too.

include("${CMAKE_CURRENT_LIST_DIR}/DawnTargets.cmake")

get_filename_component(_DawnRoot "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set_target_properties(dawn::webgpu_dawn PROPERTIES
	MAP_IMPORTED_CONFIG_DEBUG Release
	MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release
	MAP_IMPORTED_CONFIG_MINSIZEREL Release
)

get_target_property(_DawnLibrary dawn::webgpu_dawn IMPORTED_LOCATION_RELEASE)
set(DAWN_RUNTIME_FILES "${_DawnLibrary}")
if(EXISTS "${_DawnRoot}/bin/dxcompiler.dll")
	list(APPEND DAWN_RUNTIME_FILES "${_DawnRoot}/bin/dxcompiler.dll")
endif()
unset(_DawnLibrary)
unset(_DawnRoot)

function(dawn_copy_runtime Target)
	add_custom_command(TARGET ${Target} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy_if_different ${DAWN_RUNTIME_FILES} "$<TARGET_FILE_DIR:${Target}>"
		VERBATIM
	)
endfunction()
