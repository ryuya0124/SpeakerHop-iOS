#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
platform="${1:-iphoneos}"
case "$platform" in
  iphoneos) arch=arm64 ;;
  iphonesimulator) arch=arm64 ;;
  *) echo 'Expected iphoneos or iphonesimulator' >&2; exit 2 ;;
esac
cmake_bin=/opt/homebrew/bin/cmake
"$cmake_bin" -S ../third_party/airplay2-sender-cpp -B "build/native/$platform" \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$(xcrun --sdk "$platform" --show-sdk-path)" \
  -DCMAKE_OSX_ARCHITECTURES="$arch" -DCMAKE_OSX_DEPLOYMENT_TARGET=27.0 \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="$PWD/build/native/$platform/lib" \
  -DAIRPLAY_BUILD_EXAMPLE=OFF -DAIRPLAY_BUILD_TESTS=OFF
"$cmake_bin" --build "build/native/$platform" --parallel 6
