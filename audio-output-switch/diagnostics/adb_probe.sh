#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

adb connect "$DEVICE" || true
adb devices -l

echo "== build =="
adb -s "$DEVICE" shell getprop ro.build.version.release || true
adb -s "$DEVICE" shell getprop ro.build.version.sdk || true
adb -s "$DEVICE" shell getprop ro.lineage.version || true
adb -s "$DEVICE" shell getprop ro.product.model || true
adb -s "$DEVICE" shell getprop ro.product.device || true

echo "== identity before root =="
adb -s "$DEVICE" shell id || true

echo "== adb root =="
adb -s "$DEVICE" root || true
sleep 3
adb connect "$DEVICE" || true
adb -s "$DEVICE" wait-for-device

echo "== identity after root =="
adb -s "$DEVICE" shell id || true

echo "== remount =="
adb -s "$DEVICE" remount || true

echo "== mounts =="
adb -s "$DEVICE" shell 'mount | grep -E " /system | /system_ext | /product " || true' || true

echo "== target paths =="
adb -s "$DEVICE" shell 'ls -ld /system/system_ext/priv-app /system/system_ext/etc/permissions /system/system_ext/etc/sysconfig /system/system_ext/overlay 2>/dev/null || true' || true

echo "== current package =="
adb -s "$DEVICE" shell 'pm path org.lineageos.tv.audiooutput 2>/dev/null || true' || true
adb -s "$DEVICE" shell 'cmd package resolve-activity --brief com.android.tv.settings.SOUND 2>/dev/null || true' || true
