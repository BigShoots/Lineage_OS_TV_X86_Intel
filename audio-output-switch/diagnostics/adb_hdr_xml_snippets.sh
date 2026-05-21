#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" wait-for-device

echo "== /vendor/etc/media_codecs_ffmpeg_c2.xml =="
adb -s "$DEVICE" shell 'sed -n "88,155p" /vendor/etc/media_codecs_ffmpeg_c2.xml' || true

echo "== /vendor/etc/media_codecs_google_c2_video.xml =="
adb -s "$DEVICE" shell 'sed -n "40,96p" /vendor/etc/media_codecs_google_c2_video.xml' || true

echo "== hdr display settings packages/xml =="
adb -s "$DEVICE" shell 'grep -RInaE "match_content_dynamic_range|HDR|hdr" /system_ext/priv-app/TvSettingsTwoPanel /system_ext/etc /product/etc /system/etc /vendor/etc 2>/dev/null | grep -Iv "\.apk" | head -120' || true
