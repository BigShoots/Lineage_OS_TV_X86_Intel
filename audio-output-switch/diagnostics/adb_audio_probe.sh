#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

echo "== audio services =="
adb -s "$DEVICE" shell 'cmd -l | grep -i audio || true' || true
adb -s "$DEVICE" shell 'cmd media.audio_policy help 2>/dev/null || true' || true

echo "== audio devices and strategies =="
adb -s "$DEVICE" shell 'dumpsys audio | grep -Ei "AudioProductStrategy|Product Strategy|preferred device|preferred devices|device:|Devices|HDMI|USB|speaker|headphone|headset|bus|strategy|media" | head -220' || true

echo "== package and settings hook =="
adb -s "$DEVICE" shell 'pm path org.lineageos.tv.audiooutput 2>/dev/null || true' || true
adb -s "$DEVICE" shell 'cmd package resolve-activity --brief com.android.tv.settings.SOUND 2>/dev/null || true' || true
