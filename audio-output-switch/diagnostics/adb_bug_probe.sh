#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

adb connect "$DEVICE" || true
adb -s "$DEVICE" wait-for-device || exit 1

echo "== identity/packages =="
adb -s "$DEVICE" shell '
echo "lineage=$(getprop ro.lineage.version)"
echo "sdk=$(getprop ro.build.version.sdk)"
echo "device=$(getprop ro.product.device)"
echo "model=$(getprop ro.product.model)"
pm path org.lineageos.tv.audiooutput 2>/dev/null || true
pm path com.android.tv.settings 2>/dev/null || true
pm list packages | grep -Ei "smart|tube|liskov|google|gms|audiooutput" || true
' || true

echo "== audio devices/preferred =="
adb -s "$DEVICE" shell '
dumpsys audio | grep -Ei -C4 "Preferred devices|strategy:|telephony|hdmi|speaker|AUDIO_DEVICE|encoded|surround|force use|direct|offload|format" | head -420
' || true

echo "== settings current tasks =="
adb -s "$DEVICE" shell 'dumpsys activity activities | grep -Ei "ResumedActivity|Hist|com.android.tv.settings|org.lineageos.tv.audiooutput|launcher|home" | head -160' || true

echo "== recent relevant logcat =="
adb -s "$DEVICE" logcat -d -v time | grep -Ei 'AndroidRuntime|FATAL EXCEPTION|com.android.tv.settings|TvSettings|audiooutput|AudioOutput|SmartTube|liskovsoft|setPreferredDevice|preferred device|not supported|ActivityTaskManager|SecurityException|Resources\$NotFound|IndexOutOfBounds|NullPointer|ClassCastException|IllegalStateException' | tail -360 || true
