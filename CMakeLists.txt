cmake_minimum_required(VERSION 3.24)

if(CMAKE_HOST_APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum supported macOS version")
endif()
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" JOOMENGINE_VERSION LIMIT_COUNT 1)
project(JoomEngine VERSION "${JOOMENGINE_VERSION}" LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
option(JOOMENGINE_NATIVE_QA "Build the separately instrumented native test executable" OFF)

if(WIN32)
    include(FetchContent)
    # Match the revision used by GetBible's C++ desktop app.
    FetchContent_Declare(choc
        URL https://codeload.github.com/Tracktion/choc/tar.gz/a08bfd84494921700703a8433b9d1a304edfafd2
        URL_HASH SHA256=9e5fec006eacee8ec6d7b066d6d262d3fb6933d4914679713c82faad4698a717)
    FetchContent_MakeAvailable(choc)
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
    target_link_libraries(joomengine PRIVATE choc::choc "${webview2_SOURCE_DIR}/build/native/x64/WebView2LoaderStatic.lib"
        ole32 oleaut32 shell32 user32 shlwapi version advapi32 userenv)
elseif(APPLE OR CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_package(Qt6 6.8 REQUIRED COMPONENTS Widgets Network WebEngineWidgets)
    add_executable(joomengine src/qt.cpp)
    target_link_libraries(joomengine PRIVATE Qt6::Widgets Qt6::Network Qt6::WebEngineWidgets)
    if(APPLE)
        set(JOOMENGINE_MAC_BUNDLE_ID org.joomengine.app)
        if(JOOMENGINE_NATIVE_QA)
            set(JOOMENGINE_MAC_BUNDLE_ID org.joomengine.app.qa)
        endif()
        set(mac_resources assets/joomengine.icns LICENSE NOTICE)
        set_source_files_properties(${mac_resources} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
        target_sources(joomengine PRIVATE ${mac_resources})
        set_target_properties(joomengine PROPERTIES MACOSX_BUNDLE TRUE OUTPUT_NAME JoomEngine
            MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/packaging/macos/Info.plist.in")
    endif()
else()
    message(FATAL_ERROR "JoomEngine supports Linux, Windows and macOS desktops")
endif()

target_include_directories(joomengine PRIVATE src)
if(JOOMENGINE_NATIVE_QA)
    target_compile_definitions(joomengine PRIVATE JOOMENGINE_NATIVE_QA=1)
    target_include_directories(joomengine PRIVATE test)
endif()
