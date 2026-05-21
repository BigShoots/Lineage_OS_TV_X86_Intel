#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" root >/dev/null || true
sleep 1
adb -s "$DEVICE" wait-for-device || exit 1

echo "== ids and storage dirs =="
adb -s "$DEVICE" shell '
id
for p in /mnt/runtime /mnt/runtime/* /mnt/user /mnt/user/0 /mnt/user/0/* /mnt/pass_through /mnt/pass_through/* /mnt/media_rw /mnt/media_rw/* /storage /storage/*; do
    ls -ld "$p" 2>&1
done
'

echo "== mount service =="
adb -s "$DEVICE" shell 'dumpsys mount | sed -n "1,180p"'

echo "== vold/storage logs =="
adb -s "$DEVICE" logcat -d -v time | grep -Ei 'vold|public:8,17|1512-1D39|VolumeInfo|MountService|StorageManagerService|sdcardfs|media_rw|ExternalStorage|DocumentsUI|DocumentManagerRole' | tail -260 || true
