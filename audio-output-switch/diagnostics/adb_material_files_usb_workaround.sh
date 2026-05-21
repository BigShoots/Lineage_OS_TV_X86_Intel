#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"
PKG="${2:-me.zhanghai.android.files}"

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" root >/dev/null || true
sleep 1
adb -s "$DEVICE" wait-for-device || exit 1

INFO="$(adb -s "$DEVICE" shell 'dumpsys mount | grep -A8 "VolumeInfo{public:" | head -20' | tr -d '\r')"
UUID="$(printf '%s\n' "$INFO" | sed -n 's/.*fsUuid=\([^ ]*\).*/\1/p' | head -1)"
DEV="$(printf '%s\n' "$INFO" | sed -n 's/.*VolumeInfo{public:\([^}]*\)}.*/public:\1/p' | head -1)"
UID="$(adb -s "$DEVICE" shell "cmd package list packages -U $PKG" | sed -n 's/.*uid:\([0-9]*\).*/\1/p' | tr -d '\r' | head -1)"

if [ -z "$UUID" ] || [ -z "$DEV" ] || [ -z "$UID" ]; then
    echo "Could not determine UUID='$UUID' DEV='$DEV' UID='$UID'" >&2
    exit 1
fi

echo "USB volume: $DEV uuid=$UUID"
echo "Material Files uid: $UID"

adb -s "$DEVICE" shell "
set -x
mkdir -p /storage/$UUID
umount /storage/$UUID 2>/dev/null || true
mount -t vfat -o rw,dirsync,nosuid,nodev,noexec,noatime,uid=$UID,gid=$UID,fmask=0007,dmask=0007,allow_utime=0020,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,tz=UTC,errors=remount-ro /dev/block/vold/$DEV /storage/$UUID
ls -ld /storage/$UUID
ls -la /storage/$UUID | head -40
appops set $PKG MANAGE_EXTERNAL_STORAGE allow || true
appops set $PKG LEGACY_STORAGE allow || true
am force-stop $PKG || true
"

echo "== app-visible mount test as package uid =="
adb -s "$DEVICE" shell "su $UID -c 'id; ls -la /storage/$UUID | head -20' 2>&1 || true"
