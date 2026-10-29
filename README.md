# webgpu-dawn-cmake

Prebuilt [Dawn](https://dawn.googlesource.com/dawn), Google's implementation of WebGPU, as one
**shared library** with its C API (`webgpu.h`), published as hash-verified release archives for
CMake projects.

| Platform | Backends | Runs on |
| --- | --- | --- |
| `windows-x64` | Direct3D 12 (with DXC), Direct3D 11, Vulkan | Windows 10 and later |
| `linux-x64` | Vulkan, with X11 and Wayland surfaces | glibc 2.28 and later |
| `macos-arm64` | Metal | macOS 14 and later |

## Why does this exist?

Dawn's own [releases](https://github.com/google/dawn/releases) are static libraries. On Windows
they must be linked by a Visual Studio at least as new as the one that built them, Debug builds
need a separate 1.5 GB Debug library, and DXC is left out. Building Dawn yourself needs Python and
a long compile.

A shared library with a C API avoids all of that. One Release build serves every configuration of
a consumer (Debug, Release, sanitizer builds), whichever compiler and C++ runtime the consumer
uses, and the Windows build carries DXC and links the static C runtime, so it runs with any Visual
C++ runtime.

You can use this project in two ways, with the same targets:
- a prebuilt archive;
- the full source build, through FetchContent.

## Archive contents

```
include/                       webgpu/webgpu.h, dawn/... (and Dawn's C++ headers, webgpu_cpp.h)
bin/                           webgpu_dawn.dll, dxcompiler.dll                (Windows)
lib/                           webgpu_dawn.lib | libwebgpu_dawn.so | libwebgpu_dawn.dylib
lib/cmake/Dawn/                the CMake package: find_package(Dawn)
LICENSES/                      Dawn's licence, and those of everything built into it and of DXC
VERSIONS                       the exact Dawn release and commit, compiler and platform
```

## Using an archive

```cmake
include(FetchContent)
FetchContent_Declare(dawn-prebuilt
	URL https://github.com/EndlessL00p/webgpu-dawn-cmake/releases/download/v20261027.184652-1/webgpu-dawn-v20261027.184652-1-linux-x64.zip
	URL_HASH SHA256=<from the release's SHA256SUMS>)
FetchContent_MakeAvailable(dawn-prebuilt)
find_package(Dawn CONFIG REQUIRED PATHS "${dawn-prebuilt_SOURCE_DIR}" NO_DEFAULT_PATH)

target_link_libraries(your_app PRIVATE dawn::webgpu_dawn)
dawn_copy_runtime(your_app)   # the library, and on Windows dxcompiler.dll, beside your_app
```

- `dawn::webgpu_dawn` carries the include folder and `WGPU_SHARED_LIBRARY`, so `webgpu.h` imports
  its functions from the library.
- `dawn_copy_runtime(<target>)` copies the files a program needs at run time beside it after each
  build. `DAWN_RUNTIME_FILES` lists them, for your own install rules.
- Verify every download against the `SHA256SUMS` file attached to each release.

## Building from source instead

The same targets, built locally from Dawn's sources:

```cmake
include(FetchContent)
FetchContent_Declare(webgpu-dawn-cmake
	GIT_REPOSITORY https://github.com/EndlessL00p/webgpu-dawn-cmake.git
	GIT_TAG v20261027.184652-1)
FetchContent_MakeAvailable(webgpu-dawn-cmake)
# dawn::webgpu_dawn and dawn_copy_runtime() now exist, as with an archive.
```

You need CMake 3.22 or newer, a C++20 compiler, Python 3, Git and network access: Dawn fetches its
own dependencies when it is configured. The Dawn options this project sets are in
[`cmake/DawnOptions.cmake`](cmake/DawnOptions.cmake).

## Reproducing an archive

```sh
./scripts/build.ps1                                          # build, check and zip into dist/
./scripts/smoke.ps1 -Archive dist/webgpu-dawn-dev-<platform>.zip
```

The scripts need PowerShell 7. On Windows, `build.ps1` enters a Visual Studio developer
environment itself; pass `-BuildDir C:/b` to keep Dawn's deeply nested paths under Windows' limit.

`build.ps1` checks what it built:
- on Windows, that the library and DXC link the static C runtime;
- on Linux, with `-MaxGlibc 2.28`, the newest glibc the library needs.

`smoke.ps1` unpacks an archive, builds [`tests/smoke`](tests/smoke) against it with no Dawn sources
present, and runs it. The test creates a device on the platform's adapter (WARP or Mesa's software
Vulkan driver on machines without a GPU), compiles a compute pipeline, and on Windows checks that
Dawn compiled it with DXC.

CI runs exactly these scripts. Release archives are only built by CI from a tag: Windows on
Windows Server 2025, Linux in the manylinux 2.28 container that Dawn's own releases use, and macOS
on macOS 15. Each is smoke-tested on a clean machine before the release is published.

## Versioning

Tags are `<Dawn release>-<packaging revision>`: `v20261027.184652-1` builds Dawn's release
[`v20261027.184652`](https://github.com/google/dawn/releases/tag/v20261027.184652). A `-2` would
change only the packaging. The browser side of WebGPU, Dawn's emdawnwebgpu port, is published by
Google with each Dawn release (`emdawnwebgpu_pkg-<release>.zip`), so a project can pin both to the
same Dawn release.

## Licence

The build scripts and CMake files in this repository: [MIT](LICENSE). The archives contain Dawn
(BSD 3-Clause) and the libraries built into it, and on Windows DXC; every archive includes their
licences under `LICENSES/`.
