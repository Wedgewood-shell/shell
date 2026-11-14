#!/bin/sh
# Build the live window-preview plugin used by the capture menu (menus/CaptureMenu.qml).
# Needs: cmake, Qt 6 (Quick, DBus) and GStreamer (app, video, allocators) dev files,
# plus the PipeWire GStreamer plugin at runtime. Rerun after Qt upgrades.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
cmake -S "$here/native" -B "$here/native/build" -DCMAKE_BUILD_TYPE=Release -Wno-dev
cmake --build "$here/native/build" -j"$(nproc)"
