#!/bin/bash

# Default values
CMAKE_ARGS=""

CLEAN=false

INSTALL=false

# Find a valid macOS SDK and set it for CMake to fix a potential mismatch
if [[ "$(uname)" == "Darwin" ]]; then
    SDK_PATH=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)
    if [ -n "$SDK_PATH" ]; then
        CMAKE_ARGS="-DCMAKE_OSX_SYSROOT=$SDK_PATH"
    fi
fi

# Parse command-line arguments
for arg in "$@"
do
    case $arg in
        --format)
        clang-format -i **/*.cpp **/*.h **/*.mm
        exit $?
        ;;
        --format-check)
        clang-format -i **/*.cpp **/*.h **/*.mm --dry-run -Werror
        exit $?
        ;;
        --tidy)
        CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_CXX_CLANG_TIDY=clang-tidy"
        shift # Remove --tidy from processing
        ;;
        --tidy-fix)
        CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_CXX_CLANG_TIDY='clang-tidy;-fix-errors'"
        shift # Remove --tidy-fix from processing
        ;;
        --clean)
        CLEAN=true
        shift
        ;;
        --install)
        INSTALL=true
        shift
        ;;
        *)
        CMAKE_ARGS="$CMAKE_ARGS $arg"
        ;;
    esac
done

# Clean build directory for a fresh configuration
if $CLEAN && [ -d "build" ]; then
    echo "Removing existing build directory."
    rm -rf build
fi

echo "Configuring with: cmake -B build -G Ninja $CMAKE_ARGS"

# Run CMake configuration.
cmake -B build $CMAKE_ARGS

# Run the build
echo "Building project..."
cmake --build build --parallel

# Bundle Qt into the .app and copy it to /Applications (macOS only)
if $INSTALL; then
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "--install is macOS only; use 'cmake --install build' elsewhere." >&2
        exit 1
    fi

    MACDEPLOYQT=$(command -v macdeployqt || echo "$(brew --prefix qt 2>/dev/null)/bin/macdeployqt")
    if [ ! -x "$MACDEPLOYQT" ]; then
        echo "macdeployqt not found. Install Qt (e.g. 'brew install qt')." >&2
        exit 1
    fi

    echo "Bundling Qt frameworks into build/qView.app..."
    "$MACDEPLOYQT" build/qView.app

    echo "Installing to /Applications/qView.app..."
    rm -rf /Applications/qView.app
    cp -R build/qView.app /Applications/
    # Ad-hoc signature, otherwise Gatekeeper refuses the freshly modified bundle
    codesign --force --deep --sign - /Applications/qView.app
    echo "Done. Launch with: open -a qView"
fi
