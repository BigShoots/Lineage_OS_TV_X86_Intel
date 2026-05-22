#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_DIR="$WORKSPACE/work/audio-output-switch"
SYSTEM_IMG="$WORKSPACE/work/system/system.img"
APK="$PROJECT_DIR/build/dist/AudioOutputSwitch.apk"
OVERLAY_APK="$PROJECT_DIR/build/dist/AudioOutputSettingsOverlay.apk"
MNT="$WORKSPACE/work/system/audio-switcher-install-mnt"

if [ ! -f "$APK" ]; then
    echo "Missing built APK: $APK" >&2
    exit 1
fi
if [ ! -f "$OVERLAY_APK" ]; then
    echo "Missing built overlay APK: $OVERLAY_APK" >&2
    exit 1
fi

cleanup() {
    umount "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$MNT"
umount -l "$MNT" 2>/dev/null || true
mount -o loop,rw "$SYSTEM_IMG" "$MNT"

SYSTEM_OUT="$MNT/system"
APP_DIR="$SYSTEM_OUT/system_ext/priv-app/AudioOutputSwitch"
OVERLAY_DIR="$SYSTEM_OUT/system_ext/overlay/AudioOutputSettingsOverlay"
mkdir -p "$APP_DIR"
cp "$APK" "$APP_DIR/AudioOutputSwitch.apk"
mkdir -p "$OVERLAY_DIR"
cp "$OVERLAY_APK" "$OVERLAY_DIR/AudioOutputSettingsOverlay.apk"

install -m 0644 -o 0 -g 0 \
    "$PROJECT_DIR/privapp-permissions-org.lineageos.tv.audiooutput.xml" \
    "$SYSTEM_OUT/system_ext/etc/permissions/privapp-permissions-org.lineageos.tv.audiooutput.xml"
install -m 0644 -o 0 -g 0 \
    "$PROJECT_DIR/hiddenapi-package-whitelist-org.lineageos.tv.audiooutput.xml" \
    "$SYSTEM_OUT/system_ext/etc/sysconfig/hiddenapi-package-whitelist-org.lineageos.tv.audiooutput.xml"

chown -R 0:0 "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 0755 {} +
find "$APP_DIR" -type f -exec chmod 0644 {} +
chown -R 0:0 "$OVERLAY_DIR"
find "$OVERLAY_DIR" -type d -exec chmod 0755 {} +
find "$OVERLAY_DIR" -type f -exec chmod 0644 {} +
chcon -hR u:object_r:system_file:s0 "$APP_DIR" || true
chcon -hR u:object_r:system_file:s0 "$OVERLAY_DIR" || true
chcon -h u:object_r:system_file:s0 \
    "$SYSTEM_OUT/system_ext/etc/permissions/privapp-permissions-org.lineageos.tv.audiooutput.xml" \
    "$SYSTEM_OUT/system_ext/etc/sysconfig/hiddenapi-package-whitelist-org.lineageos.tv.audiooutput.xml" || true

sync
umount "$MNT"
trap - EXIT

e2fsck -fy "$SYSTEM_IMG"
