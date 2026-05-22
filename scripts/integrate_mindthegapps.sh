#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")/../.." && pwd)"
GAPPS_ZIP="${1:-/mnt/c/Users/Student/Downloads/MindTheGapps-14.0.0-x86_64-ATV-full-20250624_164100 (2).zip}"
SYSTEM_IMG="$WORKSPACE/work/system/system.img"
STAGE="$WORKSPACE/work/gapps"
EXTRACT="$STAGE/extracted"
MNT="$STAGE/system-mnt"

if [ ! -f "$GAPPS_ZIP" ]; then
    echo "Missing GApps zip: $GAPPS_ZIP" >&2
    exit 1
fi

cleanup() {
    umount "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

rm -rf "$EXTRACT"
mkdir -p "$EXTRACT" "$MNT"
umount -l "$MNT" 2>/dev/null || true

echo "== extracting MindTheGapps =="
7z x -y -o"$EXTRACT" "$GAPPS_ZIP" >/dev/null

gapps_arch="$(grep -m1 '^arch=' "$EXTRACT/build.prop" | cut -d= -f2)"
gapps_sdk="$(grep -m1 '^version=' "$EXTRACT/build.prop" | cut -d= -f2)"
if [ "$gapps_arch" != "x86_64" ] || [ "$gapps_sdk" != "34" ]; then
    echo "Unexpected GApps package arch/sdk: arch=$gapps_arch sdk=$gapps_sdk" >&2
    exit 1
fi

echo "== mounting system.img =="
mount -o loop,rw "$SYSTEM_IMG" "$MNT"
SYSTEM_OUT="$MNT/system"
android_sdk="$(grep -m1 '^ro.build.version.sdk=' "$SYSTEM_OUT/build.prop" | cut -d= -f2)"
if [ "$android_sdk" != "$gapps_sdk" ]; then
    echo "GApps SDK $gapps_sdk does not match image SDK $android_sdk" >&2
    exit 1
fi

echo "== generating addon.d script =="
cat "$EXTRACT/system/addon.d/addond_head" > "$EXTRACT/system/addon.d/30-gapps.sh"
(
    cd "$EXTRACT/system"
    find . ! -path './addon.d/*' -type f | sed 's#^\./##' | sort
) >> "$EXTRACT/system/addon.d/30-gapps.sh"
cat "$EXTRACT/system/addon.d/addond_tail" >> "$EXTRACT/system/addon.d/30-gapps.sh"
rm -f "$EXTRACT/system/addon.d/addond_head" "$EXTRACT/system/addon.d/addond_tail"

echo "== normalizing extracted ownership and permissions =="
chown -R 0:0 "$EXTRACT/system"
find "$EXTRACT/system" -type d -exec chmod 0755 {} +
find "$EXTRACT/system" -type f -exec chmod 0644 {} +
find "$EXTRACT/system" -type f -name '*.sh' -exec chmod 0755 {} +

echo "== free space before copy =="
df -h "$MNT"

echo "== copying GApps into system image =="
mkdir -p "$SYSTEM_OUT/addon.d" "$SYSTEM_OUT/product" "$SYSTEM_OUT/system_ext"
if [ -d "$EXTRACT/system/system" ]; then
    cp -a "$EXTRACT/system/system/." "$SYSTEM_OUT/"
fi
if [ -d "$EXTRACT/system/product" ]; then
    cp -a "$EXTRACT/system/product/." "$SYSTEM_OUT/product/"
fi
if [ -d "$EXTRACT/system/system_ext" ]; then
    cp -a "$EXTRACT/system/system_ext/." "$SYSTEM_OUT/system_ext/"
fi
cp -a "$EXTRACT/system/addon.d/30-gapps.sh" "$SYSTEM_OUT/addon.d/"

if [ -f "$SYSTEM_OUT/product/priv-app/TVLauncher/TVLauncher.apk" ]; then
    rm -rf "$SYSTEM_OUT/product/priv-app/TVLauncherNoGMS"
    rm -rf "$SYSTEM_OUT/product/priv-app/TVRecommendationsNoGMS"
fi

map_target() {
    local rel="${1#./}"
    case "$rel" in
        system/*) printf '%s/%s\n' "$SYSTEM_OUT" "${rel#system/}" ;;
        product/*) printf '%s/product/%s\n' "$SYSTEM_OUT" "${rel#product/}" ;;
        system_ext/*) printf '%s/system_ext/%s\n' "$SYSTEM_OUT" "${rel#system_ext/}" ;;
        addon.d/30-gapps.sh) printf '%s/addon.d/30-gapps.sh\n' "$SYSTEM_OUT" ;;
    esac
}

echo "== applying Android-style metadata to new files =="
while IFS= read -r rel; do
    target="$(map_target "$rel")"
    [ -n "$target" ] && [ -e "$target" ] || continue
    chown 0:0 "$target"
    chmod 0755 "$target"
    chcon -h u:object_r:system_file:s0 "$target" || true
done < <(cd "$EXTRACT/system" && find . -type d)

while IFS= read -r rel; do
    target="$(map_target "$rel")"
    [ -n "$target" ] && [ -e "$target" ] || continue
    chown 0:0 "$target"
    case "$target" in
        *.sh) chmod 0755 "$target" ;;
        *) chmod 0644 "$target" ;;
    esac
    chcon -h u:object_r:system_file:s0 "$target" || true
done < <(cd "$EXTRACT/system" && find . -type f ! -name addond_head ! -name addond_tail)

echo "== fixing metadata on the audio switcher additions =="
rm -rf "$SYSTEM_OUT/system_ext/overlay/AudioOutputSettingsOverlay"
for path in \
    "$SYSTEM_OUT/system_ext/priv-app/AudioOutputSwitch"; do
    [ -e "$path" ] || continue
    chown -R 0:0 "$path"
    find "$path" -type d -exec chmod 0755 {} +
    find "$path" -type f -exec chmod 0644 {} +
    chcon -hR u:object_r:system_file:s0 "$path" || true
done
for path in \
    "$SYSTEM_OUT/system_ext/etc/permissions/privapp-permissions-org.lineageos.tv.audiooutput.xml" \
    "$SYSTEM_OUT/system_ext/etc/sysconfig/hiddenapi-package-whitelist-org.lineageos.tv.audiooutput.xml"; do
    [ -e "$path" ] || continue
    chown 0:0 "$path"
    chmod 0644 "$path"
    chcon -h u:object_r:system_file:s0 "$path" || true
done

echo "== free space after copy =="
df -h "$MNT"

sync
umount "$MNT"
trap - EXIT

echo "== checking filesystem =="
e2fsck -fy "$SYSTEM_IMG"

echo "MindTheGapps integration complete."
