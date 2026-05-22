#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$PROJECT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/adb-harness"
ANDROID_JAR="/usr/lib/android-sdk/platforms/android-23/android.jar"
LOCAL_BUILD_TOOLS="$WORKSPACE/tools/android-build-tools/android-14/android-14"
D8="${D8:-$LOCAL_BUILD_TOOLS/d8}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes" "$BUILD_DIR/dex" "$BUILD_DIR/dist"

mapfile -d '' JAVA_SOURCES < <(find "$PROJECT_DIR/adb-harness/src" -name '*.java' -print0 | sort -z)
javac -source 1.8 -target 1.8 \
    -bootclasspath "$ANDROID_JAR" \
    -d "$BUILD_DIR/classes" \
    "${JAVA_SOURCES[@]}"

jar cf "$BUILD_DIR/classes.jar" -C "$BUILD_DIR/classes" .
"$D8" --lib "$ANDROID_JAR" --output "$BUILD_DIR/dex" "$BUILD_DIR/classes.jar"
(cd "$BUILD_DIR/dex" && zip -q "$BUILD_DIR/dist/AudioRouteCli.jar" classes.dex)
ls -lh "$BUILD_DIR/dist/AudioRouteCli.jar"
