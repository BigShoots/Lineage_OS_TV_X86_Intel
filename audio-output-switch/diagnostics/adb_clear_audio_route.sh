#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:-172.16.0.153:5555}"
JAR="audio-output-switch/build/adb-harness/dist/AudioRouteCli.jar"
REMOTE="/data/local/tmp/AudioRouteCli.jar"
MAIN="org.lineageos.tv.audiooutput.AudioRouteCli"

bash audio-output-switch/build_adb_harness.sh >/dev/null
adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" wait-for-device
adb -s "$DEVICE" push "$JAR" "$REMOTE" >/dev/null
adb -s "$DEVICE" shell "CLASSPATH=$REMOTE app_process /system/bin $MAIN clear"
adb -s "$DEVICE" shell 'dumpsys audio | sed -n "/Preferred devices for strategy:/,/Non-default devices for strategy:/p"'
