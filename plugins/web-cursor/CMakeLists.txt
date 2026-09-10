cmake_minimum_required(VERSION 3.19)

project(caelestia-webcursor LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
add_compile_options(-fexceptions)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -rdynamic")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(EPOXY REQUIRED IMPORTED_TARGET epoxy)

set(ULTRALIGHT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty"
    CACHE PATH "Path to an extracted Ultralight SDK")

if(NOT EXISTS "${ULTRALIGHT_ROOT}/include/AppCore/App.h" OR
   NOT EXISTS "${ULTRALIGHT_ROOT}/bin/libUltralightCore.so")
    message(FATAL_ERROR
        "Ultralight SDK was not found at ${ULTRALIGHT_ROOT}.\n"
        "Install and extract a compatible Ultralight SDK yourself into the ThirdParty directory:\n"
        "  ./install-sdk.sh /path/to/ultralight-sdk\n"
        "The SDK directory must contain include/AppCore/App.h and bin/libUltralightCore.so.")
endif()

set(ULTRALIGHT_BIN "${ULTRALIGHT_ROOT}/bin")

function(ultralight_import_library target_name lib_basename)
    add_library(${target_name} SHARED IMPORTED)
    set_target_properties(${target_name} PROPERTIES
        IMPORTED_LOCATION "${ULTRALIGHT_BIN}/lib${lib_basename}.so"
        INTERFACE_INCLUDE_DIRECTORIES "${ULTRALIGHT_ROOT}/include"
    )
endfunction()

ultralight_import_library(Ultralight::Ultralight Ultralight)
ultralight_import_library(Ultralight::UltralightCore UltralightCore)
ultralight_import_library(Ultralight::AppCore AppCore)
ultralight_import_library(Ultralight::WebCore WebCore)

add_library(Ultralight::SDK INTERFACE IMPORTED)
target_link_libraries(Ultralight::SDK INTERFACE
    Ultralight::Ultralight
    Ultralight::UltralightCore
    Ultralight::AppCore
    Ultralight::WebCore
)

set(CMAKE_BUILD_RPATH "${ULTRALIGHT_BIN}")
set(CMAKE_INSTALL_RPATH "/usr/lib/webkde_core")

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui DBus Widgets)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(KF6 REQUIRED COMPONENTS CoreAddons Config)
find_package(KWin REQUIRED)

set(WEBCURSOR_CONTENTS "${CMAKE_CURRENT_SOURCE_DIR}/contents")

add_library(webkde_core OBJECT
    ${WEBCURSOR_CONTENTS}/config/CursorJSON.cpp
    ${WEBCURSOR_CONTENTS}/config/CursorJSON.hpp
    ${WEBCURSOR_CONTENTS}/config/UserConfig.cpp
    ${WEBCURSOR_CONTENTS}/config/UserConfig.hpp
    ${WEBCURSOR_CONTENTS}/lib/Quick/PluginPath/PluginPath.cpp
    ${WEBCURSOR_CONTENTS}/lib/Quick/PluginPath/PluginPath.hpp
)
set_target_properties(webkde_core PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(webkde_core PUBLIC
    ${WEBCURSOR_CONTENTS}
    ${WEBCURSOR_CONTENTS}/config
    ${WEBCURSOR_CONTENTS}/header
    ${WEBCURSOR_CONTENTS}/lib
    ${WEBCURSOR_CONTENTS}/lib/Quick/PluginPath

)
target_link_libraries(webkde_core PUBLIC Qt6::Core Qt6::DBus )

add_subdirectory(contents/kwin-plasma)

install(DIRECTORY ${WEBCURSOR_CONTENTS}/WebCursor/
    DESTINATION "${CMAKE_INSTALL_DATADIR}/caelestia/webcursor")
install(DIRECTORY "${ULTRALIGHT_BIN}/"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/webkde_core"
    FILES_MATCHING PATTERN "*.so*")
install(DIRECTORY "${ULTRALIGHT_ROOT}/resources"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/caelestia/webcursor")
