#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" root >/dev/null || true
sleep 2
adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" wait-for-device

echo "== identity =="
adb -s "$DEVICE" shell 'id; getprop ro.product.model; getprop ro.product.device; getprop ro.lineage.version' || true

echo "== cec device nodes =="
adb -s "$DEVICE" shell 'ls -l /dev/cec* /sys/class/cec /sys/class/cec/* 2>/dev/null || true' || true

echo "== drm connectors =="
adb -s "$DEVICE" shell 'for d in /sys/class/drm/card*-*/status; do echo "$d=$(cat "$d" 2>/dev/null)"; done' || true

echo "== cec modules =="
adb -s "$DEVICE" shell 'cat /proc/modules | grep -Ei "cec|i915|drm|hdmi|seco|pulse|rainshadow|extron" || true' || true

echo "== cec kernel log =="
adb -s "$DEVICE" shell 'dmesg | grep -Ei "cec|hdmi|i915|drm" | tail -200 || true' || true

echo "== android services =="
adb -s "$DEVICE" shell 'service list | grep -Ei "hdmi|cec|tv" || true' || true
adb -s "$DEVICE" shell 'cmd -l | grep -Ei "hdmi|cec|tv" || true' || true

echo "== package features =="
adb -s "$DEVICE" shell 'pm list features | grep -Ei "hdmi|cec|tv" || true' || true

echo "== hal registration =="
adb -s "$DEVICE" shell 'lshal 2>/dev/null | grep -Ei "cec|hdmi" || true' || true
adb -s "$DEVICE" shell 'service list | grep -Ei "hal.*cec|hdmi.*cec" || true' || true

echo "== vendor/system cec binaries =="
adb -s "$DEVICE" shell 'find /system /vendor /system_ext /product -maxdepth 5 \( -iname "*cec*" -o -iname "*hdmi*" \) 2>/dev/null | sort | head -300' || true

echo "== hdmi control dumpsys =="
adb -s "$DEVICE" shell 'dumpsys hdmi_control 2>/dev/null | head -260 || true' || true

echo "== cec settings =="
adb -s "$DEVICE" shell 'settings list global | grep -Ei "cec|hdmi" || true; settings list secure | grep -Ei "cec|hdmi" || true; settings list system | grep -Ei "cec|hdmi" || true' || true
