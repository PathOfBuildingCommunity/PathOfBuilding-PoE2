cmake_minimum_required(VERSION 3.24)

project(PathOfBuildingMacOSHost LANGUAGES C CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_ARCHITECTURES arm64 CACHE STRING "Build Apple Silicon runtime")

find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL3 REQUIRED sdl3)
pkg_check_modules(ZSTD REQUIRED libzstd)

# LuaJIT: prefer a vendored build (built with LUAJIT_ENABLE_OSX_HRT by
# tools/macos/build_luajit.sh) so JIT mcode allocation works on Apple Silicon.
# Homebrew's LuaJIT lacks that path -> MCODEAL -> no JIT -> the app is ~9 fps.
# Fall back to pkg-config when no prefix is provided.
if(DEFINED LUAJIT_PREFIX AND EXISTS "${LUAJIT_PREFIX}")
  find_library(LUAJIT_LIB NAMES luajit-5.1 PATHS "${LUAJIT_PREFIX}/lib" NO_DEFAULT_PATH REQUIRED)
  set(LUAJIT_LIBRARIES "${LUAJIT_LIB}")
  set(LUAJIT_INCLUDE_DIRS "${LUAJIT_PREFIX}/include/luajit-2.1")
  set(LUAJIT_LIBRARY_DIRS "${LUAJIT_PREFIX}/lib")
  message(STATUS "Using vendored LuaJIT (OSX_HRT): ${LUAJIT_LIB}")
else()
  pkg_check_modules(LUAJIT REQUIRED luajit)
  message(WARNING "Using system LuaJIT (no LUAJIT_PREFIX) - JIT may fail on Apple Silicon")
endif()

find_package(CURL REQUIRED)
find_package(ZLIB REQUIRED)

set(APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/AppIcon.icns")
set_source_files_properties("${APP_ICON}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")

add_executable(PathOfBuilding-PoE2
    src/main.mm
    src/Host.mm
    src/DdsDecode.mm
    src/TgaImage.mm
    src/FontRenderer.mm
    src/SubScript.mm
    "${APP_ICON}"
)

target_include_directories(PathOfBuilding-PoE2 PRIVATE
    ${SDL3_INCLUDE_DIRS}
    ${LUAJIT_INCLUDE_DIRS}
    ${ZSTD_INCLUDE_DIRS}
    src
)

target_link_directories(PathOfBuilding-PoE2 PRIVATE
    ${SDL3_LIBRARY_DIRS}
    ${LUAJIT_LIBRARY_DIRS}
    ${ZSTD_LIBRARY_DIRS}
)

target_link_libraries(PathOfBuilding-PoE2 PRIVATE
    ${SDL3_LIBRARIES}
    ${LUAJIT_LIBRARIES}
    ${ZSTD_LIBRARIES}
    CURL::libcurl
    ZLIB::ZLIB
    "-framework Cocoa"
)

target_compile_options(PathOfBuilding-PoE2 PRIVATE
    ${SDL3_CFLAGS_OTHER}
    ${LUAJIT_CFLAGS_OTHER}
    ${ZSTD_CFLAGS_OTHER}
)

set_target_properties(PathOfBuilding-PoE2 PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "Path of Building (PoE2)"
    MACOSX_BUNDLE_GUI_IDENTIFIER "community.pathofbuilding.poebuild2"
    MACOSX_BUNDLE_ICON_FILE "AppIcon"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
)
