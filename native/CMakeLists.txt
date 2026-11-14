cmake_minimum_required(VERSION 3.21)
project(NiriCapture LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Quick DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GST REQUIRED IMPORTED_TARGET gstreamer-app-1.0 gstreamer-video-1.0 gstreamer-allocators-1.0)
add_library(niricaptureplugin MODULE plugin.cpp windowstream.h windowstream.cpp)
set_target_properties(niricaptureplugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/NiriCapture")
target_link_libraries(niricaptureplugin PRIVATE Qt6::Quick Qt6::DBus PkgConfig::GST)
file(WRITE "${CMAKE_BINARY_DIR}/NiriCapture/qmldir" "plugin niricaptureplugin\n")
# Quickshell virtualizes config-relative URLs. Native libraries must be loaded
# through a real file URL, not its qs: virtual filesystem. Regenerate on checkout.
file(WRITE "${CMAKE_BINARY_DIR}/LiveWindow.qml"
    "import QtQuick\nimport \"file://${CMAKE_BINARY_DIR}/NiriCapture\" as Native\nNative.WindowStream {}\n")
