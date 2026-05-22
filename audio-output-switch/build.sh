#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$PROJECT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$BUILD_DIR/dist"
FRAMEWORK_APK="$WORKSPACE/work/apk/original/framework-res.apk"
TV_SETTINGS_APK="$WORKSPACE/work/apk/original/TvSettingsTwoPanel.apk"
ANDROID_JAR="/usr/lib/android-sdk/platforms/android-23/android.jar"
KEYSTORE="$WORKSPACE/tools/signing/audiooutput.jks"
LOCAL_BUILD_TOOLS="$WORKSPACE/tools/android-build-tools/android-14/android-14"
AAPT2="${AAPT2:-$LOCAL_BUILD_TOOLS/aapt2}"
D8="${D8:-$LOCAL_BUILD_TOOLS/d8}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/app/gen" "$BUILD_DIR/app/classes" "$BUILD_DIR/overlay" \
    "$DIST_DIR" "$(dirname "$KEYSTORE")"

if [ ! -f "$FRAMEWORK_APK" ]; then
    echo "Missing $FRAMEWORK_APK" >&2
    exit 1
fi

if [ ! -f "$ANDROID_JAR" ]; then
    echo "Missing $ANDROID_JAR" >&2
    exit 1
fi

if [ ! -f "$KEYSTORE" ]; then
    keytool -genkeypair \
        -keystore "$KEYSTORE" \
        -storepass changeit \
        -keypass changeit \
        -alias audiooutput \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -dname "CN=LineageOS TV Audio Output,O=Local,C=US" \
        >/dev/null
fi

"$AAPT2" compile --dir "$PROJECT_DIR/app/src/main/res" -o "$BUILD_DIR/app/resources.zip"
"$AAPT2" link \
    -o "$BUILD_DIR/app/audio-output-unsigned.apk" \
    -I "$FRAMEWORK_APK" \
    --manifest "$PROJECT_DIR/app/src/main/AndroidManifest.xml" \
    --java "$BUILD_DIR/app/gen" \
    --min-sdk-version 23 \
    --target-sdk-version 34 \
    "$BUILD_DIR/app/resources.zip"

mapfile -d '' JAVA_SOURCES < <(find "$PROJECT_DIR/app/src/main/java" "$BUILD_DIR/app/gen" -name '*.java' -print0 | sort -z)
javac -source 1.8 -target 1.8 \
    -bootclasspath "$ANDROID_JAR" \
    -classpath "$BUILD_DIR/app/gen" \
    -d "$BUILD_DIR/app/classes" \
    "${JAVA_SOURCES[@]}"

if [ -x "$D8" ]; then
    (cd "$BUILD_DIR/app/classes" && zip -qr "$BUILD_DIR/app/classes.jar" .)
    mkdir -p "$BUILD_DIR/app/dex"
    "$D8" --lib "$ANDROID_JAR" --output "$BUILD_DIR/app/dex" "$BUILD_DIR/app/classes.jar"
    cp "$BUILD_DIR/app/dex/classes.dex" "$BUILD_DIR/app/classes.dex"
else
    dx --dex --output="$BUILD_DIR/app/classes.dex" "$BUILD_DIR/app/classes"
fi
cp "$BUILD_DIR/app/audio-output-unsigned.apk" "$BUILD_DIR/app/audio-output-with-dex.apk"
(cd "$BUILD_DIR/app" && zip -q audio-output-with-dex.apk classes.dex)
zipalign -f 4 "$BUILD_DIR/app/audio-output-with-dex.apk" "$BUILD_DIR/app/audio-output-aligned.apk"
apksigner sign \
    --ks "$KEYSTORE" \
    --ks-pass pass:changeit \
    --key-pass pass:changeit \
    --out "$DIST_DIR/AudioOutputSwitch.apk" \
    "$BUILD_DIR/app/audio-output-aligned.apk"
apksigner verify --verbose "$DIST_DIR/AudioOutputSwitch.apk"

"$AAPT2" compile --dir "$PROJECT_DIR/overlay/res" -o "$BUILD_DIR/overlay/resources.zip"
"$AAPT2" link \
    -o "$BUILD_DIR/overlay/audio-output-settings-overlay-unsigned.apk" \
    -I "$FRAMEWORK_APK" \
    -I "$TV_SETTINGS_APK" \
    --manifest "$PROJECT_DIR/overlay/AndroidManifest.xml" \
    --auto-add-overlay \
    --min-sdk-version 23 \
    --target-sdk-version 34 \
    "$BUILD_DIR/overlay/resources.zip"
zipalign -f 4 \
    "$BUILD_DIR/overlay/audio-output-settings-overlay-unsigned.apk" \
    "$BUILD_DIR/overlay/audio-output-settings-overlay-aligned.apk"
apksigner sign \
    --ks "$KEYSTORE" \
    --ks-pass pass:changeit \
    --key-pass pass:changeit \
    --out "$DIST_DIR/AudioOutputSettingsOverlay.apk" \
    "$BUILD_DIR/overlay/audio-output-settings-overlay-aligned.apk"
apksigner verify --verbose "$DIST_DIR/AudioOutputSettingsOverlay.apk"

ls -lh "$DIST_DIR"
