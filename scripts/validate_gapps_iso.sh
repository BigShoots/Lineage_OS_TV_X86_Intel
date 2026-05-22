#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")/../.." && pwd)"
ISO="${1:-$WORKSPACE/out/lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output-gapps.iso}"
STAGE="$WORKSPACE/work/validate-gapps"
EFS="$STAGE/system.efs"
EFS_MNT="$STAGE/efs-mnt"
SYSTEM_MNT="$STAGE/system-mnt"

cleanup() {
    umount "$SYSTEM_MNT" 2>/dev/null || true
    umount "$EFS_MNT" 2>/dev/null || true
}
trap cleanup EXIT

rm -rf "$STAGE"
mkdir -p "$EFS_MNT" "$SYSTEM_MNT"

echo "== extracting system.efs from ISO =="
xorriso -indev "$ISO" -osirrox on -extract /system.efs "$EFS" >/dev/null 2>&1
fsck.erofs -p "$EFS"

mount -o loop,ro -t erofs "$EFS" "$EFS_MNT"
mount -o loop,ro "$EFS_MNT/system.img" "$SYSTEM_MNT"

echo "== audio switcher files =="
for path in \
    system/system_ext/priv-app/AudioOutputSwitch/AudioOutputSwitch.apk \
    system/system_ext/overlay/AudioOutputSettingsOverlay/AudioOutputSettingsOverlay.apk \
    system/system_ext/etc/permissions/privapp-permissions-org.lineageos.tv.audiooutput.xml \
    system/system_ext/etc/sysconfig/hiddenapi-package-whitelist-org.lineageos.tv.audiooutput.xml; do
    ls -Zl "$SYSTEM_MNT/$path"
done

echo "== Fire TV remote keylayout =="
ls -Zl "$SYSTEM_MNT/system/usr/keylayout/Vendor_0171_Product_0413.kl"
grep -nE 'key[[:space:]]+139[[:space:]]+SETTINGS' \
    "$SYSTEM_MNT/system/usr/keylayout/Vendor_0171_Product_0413.kl"

echo "== primary HDMI audio policy =="
grep -n 'HDMI Out' "$SYSTEM_MNT/system/vendor/etc/audio_policy_configuration.xml"

echo "== USB storage visibility policy =="
grep -n 'voldmanaged=.*usb.*encryptable=userdata' \
    "$SYSTEM_MNT/fstab.lineage_x86_64_tv" \
    "$SYSTEM_MNT/system/vendor/etc/fstab.internal.x86"
grep -n '^persist.sys.adoptable=force_on' "$SYSTEM_MNT/system/build.prop"

echo "== MindTheGapps files =="
for path in \
    system/product/etc/init/gapps.rc \
    system/product/etc/permissions/privapp-permissions-google-product.xml \
    system/product/priv-app/PrebuiltGmsCorePano/PrebuiltGmsCorePano.apk \
    system/product/priv-app/TVLauncher/TVLauncher.apk \
    system/product/priv-app/Tubesky/Tubesky.apk \
    system/system_ext/priv-app/GoogleServicesFramework/GoogleServicesFramework.apk \
    system/app/GoogleExtShared/GoogleExtShared.apk \
    system/addon.d/30-gapps.sh; do
    ls -Zl "$SYSTEM_MNT/$path"
done

echo "== removed no-gms launcher packages =="
test ! -e "$SYSTEM_MNT/system/product/priv-app/TVLauncherNoGMS"
test ! -e "$SYSTEM_MNT/system/product/priv-app/TVRecommendationsNoGMS"

echo "== APK signature sanity =="
apksigner verify --verbose "$SYSTEM_MNT/system/system_ext/priv-app/AudioOutputSwitch/AudioOutputSwitch.apk"
apksigner verify --verbose "$SYSTEM_MNT/system/system_ext/overlay/AudioOutputSettingsOverlay/AudioOutputSettingsOverlay.apk"
apksigner verify --verbose "$SYSTEM_MNT/system/product/priv-app/PrebuiltGmsCorePano/PrebuiltGmsCorePano.apk" >/dev/null
apksigner verify --verbose "$SYSTEM_MNT/system/product/priv-app/TVLauncher/TVLauncher.apk" >/dev/null

echo "Validation complete."
