# Contribute to JoomEngine

Clone the repository and create a branch for your changes.

```sh
git clone https://github.com/joomengine/joomengine.git
cd joomengine
git switch -c my-change
```

The desktop project uses C++17 and CMake 3.24 or newer. The fixed home is [JoomEngine Playground](https://playground.joomengine.org/). Changes to the Joomla, PHP, MariaDB and JCB deployment belong in the [Playground repository](https://github.com/joomengine/playground).

## Build and run

### Linux

Install a C++17 compiler and the Qt 6.8 or newer development packages for Widgets, Network and WebEngineWidgets. On Ubuntu 26.04 you can install the same dependencies used to build and exercise the native archive in CI.

```sh
sudo apt update
sudo apt install cmake g++ pkg-config qt6-base-dev qt6-webengine-dev libqt6webenginecore6-bin qt6-qpa-plugins dbus-x11 xvfb xauth xdotool
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
./build/joomengine
```

### macOS

Install Apple's command line tools, CMake and a Qt 6 desktop SDK with Qt WebEngine. Use that SDK's `qt-cmake` on your PATH to select the right Qt installation. The [macOS workflow](../.github/workflows/macos.yml) installs the pinned SDK used for distributable DMGs.

```sh
qt-cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
open build/JoomEngine.app
```

### Windows

Install Visual Studio's **Desktop development with C++** workload, the Windows SDK, CMake and the [WebView2 Evergreen Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/#download-section). Use an x64 Developer PowerShell for Visual Studio. CMake fetches the pinned CHOC and WebView2 development files and verifies their checksums.

```powershell
cmake -S . -B build -A x64
cmake --build build --config Release --parallel
.\build\Release\JoomEngine.exe
```

## Test your change

The native navigation test on Linux or macOS needs only the C++ compiler.

```sh
mkdir -p build
c++ -std=c++17 -Wall -Wextra -Werror -Isrc test/policy.cpp -o build/joomengine-policy-test
./build/joomengine-policy-test
```

The hosted test starts an instrumented build with a temporary browser profile. It loads JCB, fetches an external file, opens a detached tool, saves a unique database row, checks that row in the exported ZIP, then reads it again after restarting and performing native Reload. It needs Python 3 and an internet connection to Playground and its external dependencies.

Run the Linux test in a virtual display.

```sh
cmake -S . -B build-qa -DCMAKE_BUILD_TYPE=Release -DJOOMENGINE_NATIVE_QA=ON
cmake --build build-qa --parallel
dbus-run-session -- xvfb-run -a python3 test/native_smoke.py build-qa/joomengine
```

On macOS, run the executable inside the QA app bundle.

```sh
qt-cmake -S . -B build-qa -DCMAKE_BUILD_TYPE=Release -DJOOMENGINE_NATIVE_QA=ON
cmake --build build-qa --parallel
python3 test/native_smoke.py build-qa/JoomEngine.app/Contents/MacOS/JoomEngine
```

On Windows, use the same developer shell.

```powershell
cmake -S . -B build-qa -A x64 -DJOOMENGINE_NATIVE_QA=ON
cmake --build build-qa --config Release --parallel
python test/native_smoke.py build-qa/Release/JoomEngine.exe
```

Open a pull request targeting `main` and describe how you tested your change. The [desktop workflow](../.github/workflows/desktop.yml) links to the packaging and install tests. Verified assets are available from the run's **Artifacts** section. For publication from the main branch and release tags, see [releases](releases.md) and [store publishing](publishing.md).

[All JoomEngine guides](README.md)
