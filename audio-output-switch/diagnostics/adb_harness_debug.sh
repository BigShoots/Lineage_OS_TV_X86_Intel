#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"
REMOTE="/data/local/tmp/AudioRouteCli.jar"
MAIN="org.lineageos.tv.audiooutput.AudioRouteCli"

echo "== runtime binaries =="
adb -s "$DEVICE" shell 'ls -l /system/bin/app_process* /system/bin/dalvikvm* 2>/dev/null; uname -m; getenforce; id' || true

echo "== app_process64 =="
adb -s "$DEVICE" shell "timeout 15 sh -c 'CLASSPATH=$REMOTE app_process64 /system/bin $MAIN list'" || true

echo "== app_process32 =="
adb -s "$DEVICE" shell "timeout 15 sh -c 'CLASSPATH=$REMOTE app_process32 /system/bin $MAIN list'" || true

echo "== dalvikvm =="
adb -s "$DEVICE" shell "timeout 15 dalvikvm -cp $REMOTE $MAIN list" || true

echo "== relevant logcat =="
adb -s "$DEVICE" shell 'logcat -d -t 300 | grep -Ei "AudioRouteCli|app_process|dalvikvm|avc|denied|hidden|AndroidRuntime|FATAL|audit" || true' || true
