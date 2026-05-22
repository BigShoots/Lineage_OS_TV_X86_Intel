#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"
JAR="work/audio-output-switch/build/adb-harness/dist/AudioRouteCli.jar"
REMOTE="/data/local/tmp/AudioRouteCli.jar"
MAIN="org.lineageos.tv.audiooutput.AudioRouteCli"

adb connect "$DEVICE" || true
adb -s "$DEVICE" wait-for-device || exit 1

state="$(adb devices | awk -v d="$DEVICE" '$1 == d {print $2}')"
if [ "$state" != "device" ]; then
    echo "ADB state is '$state'. Accept the RSA debugging prompt on the TV, then rerun." >&2
    exit 2
fi

echo "== identity =="
adb -s "$DEVICE" shell '
echo "lineage=$(getprop ro.lineage.version)"
echo "model=$(getprop ro.product.model)"
echo "device=$(getprop ro.product.device)"
echo "sdk=$(getprop ro.build.version.sdk)"
'

echo "== audio hardware/policy =="
adb -s "$DEVICE" shell '
echo "--- AudioManager output devices via route harness follows later"
echo "--- /proc/asound/cards"; cat /proc/asound/cards 2>/dev/null || true
echo "--- /proc/asound/pcm"; cat /proc/asound/pcm 2>/dev/null || true
echo "--- HDMI/DP ELD"; for f in /proc/asound/card*/eld*; do [ -r "$f" ] && echo "--- $f" && cat "$f"; done
echo "--- connected audio policy devices"; dumpsys audio | sed -n "/Connected devices:/,/APM Connected device/p"
echo "--- preferred media strategy"; dumpsys audio | sed -n "/Preferred devices for strategy:/,/Non-default devices for strategy:/p"
'

echo "== route harness: clear and list =="
bash work/audio-output-switch/build_adb_harness.sh >/dev/null
adb -s "$DEVICE" push "$JAR" "$REMOTE" >/dev/null
adb -s "$DEVICE" shell "CLASSPATH=$REMOTE app_process /system/bin $MAIN clear" || true
adb -s "$DEVICE" shell "CLASSPATH=$REMOTE app_process /system/bin $MAIN list" || true

echo "== route harness: try synthetic HDMI TYPE_HDMI=9 =="
adb -s "$DEVICE" shell "CLASSPATH=$REMOTE app_process /system/bin $MAIN setattrs 9 ''" || true
adb -s "$DEVICE" shell 'dumpsys audio | sed -n "/Preferred devices for strategy:/,/Non-default devices for strategy:/p"'

echo "== packages that look like Material Files =="
PKGS="$(adb -s "$DEVICE" shell 'pm list packages | grep -Ei "zhanghai|material.*files|files" | sed "s/package://"' | tr -d '\r')"
printf '%s\n' "$PKGS"

FILES_PKG="$(printf '%s\n' "$PKGS" | grep -E '^me\.zhanghai\.android\.files$|zhanghai.*files|material.*files' | head -1)"
if [ -n "$FILES_PKG" ]; then
    echo "== Material Files package: $FILES_PKG =="
    adb -s "$DEVICE" shell "dumpsys package $FILES_PKG | sed -n '/requested permissions:/,/User 0:/p' | head -220" || true
    echo "== appops before =="
    adb -s "$DEVICE" shell "appops get $FILES_PKG" || true

    echo "== granting storage-related permissions/appops =="
    adb -s "$DEVICE" shell "pm grant $FILES_PKG android.permission.READ_EXTERNAL_STORAGE" || true
    adb -s "$DEVICE" shell "pm grant $FILES_PKG android.permission.WRITE_EXTERNAL_STORAGE" || true
    adb -s "$DEVICE" shell "pm grant $FILES_PKG android.permission.READ_MEDIA_AUDIO" || true
    adb -s "$DEVICE" shell "pm grant $FILES_PKG android.permission.READ_MEDIA_VIDEO" || true
    adb -s "$DEVICE" shell "pm grant $FILES_PKG android.permission.READ_MEDIA_IMAGES" || true
    adb -s "$DEVICE" shell "appops set $FILES_PKG MANAGE_EXTERNAL_STORAGE allow" || true
    adb -s "$DEVICE" shell "appops set $FILES_PKG LEGACY_STORAGE allow" || true
    adb -s "$DEVICE" shell "appops set $FILES_PKG READ_EXTERNAL_STORAGE allow" || true
    adb -s "$DEVICE" shell "appops set $FILES_PKG WRITE_EXTERNAL_STORAGE allow" || true
    adb -s "$DEVICE" shell "am force-stop $FILES_PKG" || true
    echo "== appops after =="
    adb -s "$DEVICE" shell "appops get $FILES_PKG" || true
else
    echo "Material Files package not found by package-name search."
fi

echo "== USB/storage volumes and permissions =="
adb -s "$DEVICE" shell '
echo "--- sm volumes"; sm list-volumes all 2>/dev/null || true
echo "--- cmd volume"; cmd volume list 2>/dev/null || true
echo "--- mount"; mount | grep -Ei "vold|media_rw|storage|sdcard|exfat|fuse|ntfs|vfat" || true
echo "--- storage dirs"; ls -ld /storage /storage/* /mnt/media_rw /mnt/media_rw/* 2>/dev/null || true
echo "--- storage samples"; for d in /storage/* /mnt/media_rw/*; do [ -d "$d" ] && echo "--- $d" && ls -la "$d" 2>&1 | head -40; done
'

echo "== recent storage/files denials =="
adb -s "$DEVICE" logcat -d -v time | grep -Ei 'avc: denied|Permission denied|EACCES|zhanghai|MaterialFiles|media_rw|ExternalStorage|DocumentsUI|vold|StorageManager|fuse|sdcard' | tail -260 || true
