#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:-172.16.0.153:5555}"
JAR="audio-output-switch/build/adb-harness/dist/AudioRouteCli.jar"
REMOTE="/data/local/tmp/AudioRouteCli.jar"
MAIN="org.lineageos.tv.audiooutput.AudioRouteCli"

bash audio-output-switch/build_adb_harness.sh

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" root >/dev/null || true
sleep 2
adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" wait-for-device
adb -s "$DEVICE" push "$JAR" "$REMOTE" >/dev/null

run_cli() {
    adb -s "$DEVICE" shell "CLASSPATH=$REMOTE app_process /system/bin $MAIN $*"
}

echo "== initial list =="
run_cli list

target_index="$(run_cli list | awk -F: '/^[0-9]+:/ && $0 !~ /type=2 / {print $1; exit}')"
if [ -z "$target_index" ]; then
    echo "No non-speaker output found; testing clear only."
    run_cli clear
    exit 0
fi

echo "== set preferred output index $target_index =="
run_cli set "$target_index"
adb -s "$DEVICE" shell 'dumpsys audio | sed -n "/Preferred devices for strategy:/,/Non-default devices for strategy:/p"'

echo "== clear preferred output =="
run_cli clear
adb -s "$DEVICE" shell 'dumpsys audio | sed -n "/Preferred devices for strategy:/,/Non-default devices for strategy:/p"'
