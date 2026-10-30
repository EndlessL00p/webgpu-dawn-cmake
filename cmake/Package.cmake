# The archive's layout, assembled by `cmake --install <build> --prefix <stage>` (scripts/build.ps1
# drives it). Dawn's own install rules, which run first, give:
#
#   include/            webgpu/webgpu.h, dawn/... (webgpu_cpp.h and the other C++ headers too)
#   bin/                webgpu_dawn.dll                (Windows)
#   lib/                webgpu_dawn.lib, libwebgpu_dawn.so or libwebgpu_dawn.dylib
#   lib/cmake/Dawn/     DawnTargets*.cmake, DawnConfigVersion.cmake
#
# and this file adds:
#
#   bin/dxcompiler.dll              DXC (Windows)
#   lib/cmake/Dawn/DawnConfig.cmake ours, replacing Dawn's: adds dawn_copy_runtime()
#   LICENSES/                       the licence of everything in the library and of DXC

include(GNUInstallDirs)

if(DAWN_USE_BUILT_DXC)
	install(FILES "$<TARGET_FILE:dxcompiler>" DESTINATION bin)
endif()

# After Dawn's rules, so this DawnConfig.cmake replaces the one Dawn installs.
install(FILES "${CMAKE_CURRENT_LIST_DIR}/DawnConfig.cmake" DESTINATION lib/cmake/Dawn)

# Licences. Each folder below is built into the library (or, for DXC, shipped beside it); the
# others Dawn fetches are build tools (jinja2, markupsafe), tests or unused here. Every folder must
# have a licence file, so a Dawn update that moves one fails the build instead of shipping without it.
set(_WebGpuDawnLicences
	"dawn|${dawn_SOURCE_DIR}"
	"abseil-cpp|${dawn_SOURCE_DIR}/third_party/abseil-cpp"
	"spirv-headers|${dawn_SOURCE_DIR}/third_party/spirv-headers/src"
	"spirv-tools|${dawn_SOURCE_DIR}/third_party/spirv-tools/src"
	"vulkan-headers|${dawn_SOURCE_DIR}/third_party/vulkan-headers/src"
	"vulkan-utility-libraries|${dawn_SOURCE_DIR}/third_party/vulkan-utility-libraries/src"
	"webgpu-headers|${dawn_SOURCE_DIR}/third_party/webgpu-headers/src"
)
if(WIN32)
	list(APPEND _WebGpuDawnLicences
		"directx-headers|${dawn_SOURCE_DIR}/third_party/directx-headers/src"
		"directx-shader-compiler|${dawn_SOURCE_DIR}/third_party/directx-shader-compiler/src"
	)
endif()

foreach(_Entry IN LISTS _WebGpuDawnLicences)
	string(REPLACE "|" ";" _Entry "${_Entry}")
	list(GET _Entry 0 _Name)
	list(GET _Entry 1 _Folder)
	file(GLOB _Files LIST_DIRECTORIES false
		"${_Folder}/LICENSE" "${_Folder}/LICENSE.*" "${_Folder}/LICENCE*" "${_Folder}/COPYING*"
		"${_Folder}/ThirdPartyNotices.txt" "${_Folder}/NOTICE*")
	if(NOT _Files)
		message(FATAL_ERROR "No licence file found for ${_Name} in ${_Folder}")
	endif()
	foreach(_File IN LISTS _Files)
		get_filename_component(_FileName "${_File}" NAME)
		install(FILES "${_File}" DESTINATION LICENSES/${_Name} RENAME "${_FileName}")
	endforeach()
endforeach()
