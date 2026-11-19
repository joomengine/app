cmake_minimum_required(VERSION 3.24)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" JOOMENGINE_VERSION LIMIT_COUNT 1)
project(JoomEngine VERSION "${JOOMENGINE_VERSION}" LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
option(JOOMENGINE_NATIVE_QA "Build the separately instrumented native test executable" OFF)

include(FetchContent)
# Match the revision used by GetBible's C++ desktop app.
FetchContent_Declare(choc
    URL https://codeload.github.com/Tracktion/choc/tar.gz/a08bfd84494921700703a8433b9d1a304edfafd2
    URL_HASH SHA256=9e5fec006eacee8ec6d7b066d6d262d3fb6933d4914679713c82faad4698a717)
FetchContent_MakeAvailable(choc)

if(WIN32)
    enable_language(RC)
    FetchContent_Declare(webview2
        URL https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.4314.35/microsoft.web.webview2.1.0.4314.35.nupkg
        DOWNLOAD_NAME webview2.zip
        URL_HASH SHA256=90778deb1b77e36292828b4b5833c9255c27533f40e0ddd55891ae718944edc4)
    FetchContent_MakeAvailable(webview2)
    configure_file(cmake/windows.rc.in app.rc @ONLY)
    add_executable(joomengine WIN32 src/windows.cpp "${CMAKE_CURRENT_BINARY_DIR}/app.rc")
    set_target_properties(joomengine PROPERTIES OUTPUT_NAME JoomEngine
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    target_compile_definitions(joomengine PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)
    target_compile_options(joomengine PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:/utf-8>")
    target_include_directories(joomengine SYSTEM PRIVATE "${webview2_SOURCE_DIR}/build/native/include")
    target_link_libraries(joomengine PRIVATE "${webview2_SOURCE_DIR}/build/native/x64/WebView2LoaderStatic.lib"
        ole32 oleaut32 shell32 user32 shlwapi version advapi32 userenv)
elseif(APPLE)
    enable_language(OBJCXX)
    set(CMAKE_OBJCXX_STANDARD 17)
    set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0")
    set(mac_resources assets/joomengine.icns LICENSE NOTICE LICENSES/CHOC-ISC.txt)
    set_source_files_properties(${mac_resources} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    add_executable(joomengine MACOSX_BUNDLE src/macos.mm ${mac_resources})
    set_target_properties(joomengine PROPERTIES OUTPUT_NAME JoomEngine
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/packaging/macos/Info.plist.in")
    target_compile_options(joomengine PRIVATE -fobjc-arc)
    target_link_libraries(joomengine PRIVATE "-framework Cocoa" "-framework WebKit")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
    pkg_check_modules(WEBKIT REQUIRED IMPORTED_TARGET webkit2gtk-4.1)
    add_executable(joomengine src/linux.cpp)
    target_link_libraries(joomengine PRIVATE PkgConfig::GTK PkgConfig::WEBKIT)
else()
    message(FATAL_ERROR "JoomEngine supports Linux, Windows and macOS desktops")
endif()

target_link_libraries(joomengine PRIVATE choc::choc)
target_include_directories(joomengine PRIVATE src)
if(JOOMENGINE_NATIVE_QA)
    target_compile_definitions(joomengine PRIVATE JOOMENGINE_NATIVE_QA=1)
    target_include_directories(joomengine PRIVATE test)
endif()
