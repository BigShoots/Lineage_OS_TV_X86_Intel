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

echo "== display props =="
adb -s "$DEVICE" shell 'getprop | grep -Ei "hdr|wide.?color|display|surfaceflinger|hwc|gralloc|vulkan|mesa|drm|codec" | sort' || true

echo "== drm connector status =="
adb -s "$DEVICE" shell 'for d in /sys/class/drm/card*-*/status; do echo "$d=$(cat "$d" 2>/dev/null)"; done' || true

echo "== display dumpsys hdr/color snippets =="
adb -s "$DEVICE" shell 'dumpsys display | grep -Ei -C3 "hdr|Hdr|wide|Wide|color mode|ColorMode|DisplayDeviceInfo|supportedModes|modes|DisplayInfo|BT2020|PQ|HLG|Dolby|HDR10" | head -260' || true

echo "== surfaceflinger hdr/color snippets =="
adb -s "$DEVICE" shell 'dumpsys SurfaceFlinger | grep -Ei -C3 "hdr|Hdr|wide|Wide|color mode|ColorMode|dataspace|BT2020|PQ|HLG|Dolby|HDR10|Display" | head -320' || true

echo "== codecs containing hdr/10-bit/hevc/vp9/av1 =="
adb -s "$DEVICE" shell 'dumpsys media.codec 2>/dev/null | grep -Ei -C2 "hevc|h265|vp9|av1|10-bit|10bit|profile|HDR|hdr|Main10|P010|YUVP010|Dolby|hlg|pq" | head -360' || true

echo "== media codec XML snippets =="
adb -s "$DEVICE" shell 'grep -RInaE "hevc|h265|vp9|av1|Main10|HDR|hdr|10-bit|10bit|profile|dolby|hlg|pq" /vendor/etc /system/etc /product/etc /system_ext/etc 2>/dev/null | head -260' || true

echo "== settings =="
adb -s "$DEVICE" shell 'settings list global | grep -Ei "hdr|dynamic|color|display" || true; settings list secure | grep -Ei "hdr|dynamic|color|display" || true; settings list system | grep -Ei "hdr|dynamic|color|display" || true' || true
