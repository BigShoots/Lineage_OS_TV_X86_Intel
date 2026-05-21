#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" root >/dev/null || true
sleep 2
adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" wait-for-device

echo "== display hdr summary =="
adb -s "$DEVICE" shell 'dumpsys display | grep -Ei "supportedHdrTypes|hdrCapabilities|supportedColorModes|mHdrConversionMode|hdrSdrRatio|DisplayDeviceInfo|uniqueId|name"' || true

echo "== surfaceflinger hdr summary =="
adb -s "$DEVICE" shell 'dumpsys SurfaceFlinger | grep -Ei "hdr|Hdr|dataspace|color mode|ColorMode|DisplayDeviceInfo|Display 0|active mode|BT2020|PQ|HLG|Dolby|HDR10" | head -220' || true

echo "== codec service names =="
adb -s "$DEVICE" shell 'dumpsys media.codec 2>/dev/null | grep -Ei "Codec|componentName|owner|video/hevc|video/x-vnd.on2.vp9|video/av01|Main10|P010|10bit|10-bit|HDR|Dolby|HLG|PQ" | head -260' || true

echo "== media codec xml hdr-relevant snippets =="
adb -s "$DEVICE" shell '
for f in /vendor/etc/media*.xml /system/etc/media*.xml /product/etc/media*.xml /system_ext/etc/media*.xml; do
    [ -f "$f" ] || continue
    if grep -IaqE "video/hevc|video/x-vnd.on2.vp9|video/av01|HEVCProfileMain10|VP9Profile2|AV1ProfileMain10|HDR|hdr|P010|YUVP010|dolby|hlg|pq" "$f"; then
        echo "--- $f"
        grep -InaE "video/hevc|video/x-vnd.on2.vp9|video/av01|HEVCProfileMain10|VP9Profile2|AV1ProfileMain10|HDR|hdr|P010|YUVP010|dolby|hlg|pq" "$f" | head -120
    fi
done
' || true

echo "== drm connector edid hdr hints =="
adb -s "$DEVICE" shell '
for d in /sys/class/drm/card*-*; do
    [ -d "$d" ] || continue
    status="$(cat "$d/status" 2>/dev/null)"
    [ "$status" = connected ] || continue
    echo "--- $d"
    echo "status=$status"
    cat "$d/modes" 2>/dev/null | head -20
    if [ -r "$d/edid" ]; then
        od -An -tx1 "$d/edid" 2>/dev/null | tr -d " \n" | head -c 512
        echo
    fi
done
' || true
