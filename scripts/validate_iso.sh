#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
OUT_ISO="$WORKSPACE/out/lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output.iso"
EFS_MNT="$WORKSPACE/work/system/patched-efs-mnt"
SYSTEM_MNT="$WORKSPACE/work/system/patched-system-mnt"
SYSTEM_EFS_LBA=164344
SYSTEM_EFS_SIZE=2290556928

umount -l "$SYSTEM_MNT" 2>/dev/null || true
umount -l "$EFS_MNT" 2>/dev/null || true
mkdir -p "$EFS_MNT" "$SYSTEM_MNT"

mount -o "loop,ro,offset=$((SYSTEM_EFS_LBA * 2048)),sizelimit=$SYSTEM_EFS_SIZE" -t erofs "$OUT_ISO" "$EFS_MNT"
mount -o loop,ro "$EFS_MNT/system.img" "$SYSTEM_MNT"

echo "== added files =="
for path in \
    system/system_ext/priv-app/AudioOutputSwitch/AudioOutputSwitch.apk \
    system/system_ext/etc/permissions/privapp-permissions-org.lineageos.tv.audiooutput.xml \
    system/system_ext/etc/sysconfig/hiddenapi-package-whitelist-org.lineageos.tv.audiooutput.xml; do
    ls -l "$SYSTEM_MNT/$path"
done
test ! -e "$SYSTEM_MNT/system/system_ext/overlay/AudioOutputSettingsOverlay"

echo "== signatures =="
apksigner verify --verbose "$SYSTEM_MNT/system/system_ext/priv-app/AudioOutputSwitch/AudioOutputSwitch.apk"

echo "== boot layout =="
xorriso -indev "$OUT_ISO" -report_el_torito plain -report_system_area plain 2>&1 | sed -n '1,70p'

umount "$SYSTEM_MNT"
umount "$EFS_MNT"
