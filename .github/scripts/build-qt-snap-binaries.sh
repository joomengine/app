#!/usr/bin/env bash
# Compile against the SDK paired with the strict Snap's Qt content provider.
set -euo pipefail
cd -- "$(dirname -- "$0")/../.."

sudo snap install kde-qt6-core24-sdk --channel=latest/stable
sudo snap install mesa-2404 --channel=latest/stable
sdk=/snap/kde-qt6-core24-sdk/current/usr
multiarch=$(gcc -print-multiarch)
lib="$sdk/lib/$multiarch"
export LD_LIBRARY_PATH="$lib:$sdk/lib:/snap/mesa-2404/current/usr/lib/$multiarch:$lib/blas:$lib/lapack:$lib/libproxy${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="$lib/pkgconfig:$sdk/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export XDG_DATA_DIRS="$sdk/share:/usr/local/share:/usr/share"

# Never embed the build SDK path in the installed executable. The KDE
# content extension supplies its matching Qt libraries when the Snap starts.
options=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$sdk" -DCMAKE_SKIP_RPATH=ON)
cmake -S . -B build "${options[@]}"
cmake --build build --target joomengine --parallel
cmake -S . -B build-qa "${options[@]}" -DJOOMENGINE_NATIVE_QA=ON
cmake --build build-qa --target joomengine --parallel
