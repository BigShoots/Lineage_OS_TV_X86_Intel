#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"
PATCHED="audio-output-switch/build/live-audio_policy_configuration.xml"
REMOTE="/data/local/tmp/audio_policy_configuration.primary_hdmi.xml"
JAR="audio-output-switch/build/adb-harness/dist/AudioRouteCli.jar"
REMOTE_JAR="/data/local/tmp/AudioRouteCli.jar"
MAIN="org.lineageos.tv.audiooutput.AudioRouteCli"

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" wait-for-device || exit 1
adb -s "$DEVICE" root >/dev/null || true
adb -s "$DEVICE" wait-for-device || true

echo "== push and bind mount patched audio policy =="
adb -s "$DEVICE" push "$PATCHED" "$REMOTE" >/dev/null || exit 1
adb -s "$DEVICE" shell "mount --bind $REMOTE /vendor/etc/audio_policy_configuration.xml" || exit 1
adb -s "$DEVICE" shell "mount | grep audio_policy_configuration || true"

echo "== restart audio services =="
adb -s "$DEVICE" shell '
stop audioserver
stop vendor.audio-hal
sleep 1
start vendor.audio-hal
start audioserver
sleep 3
' || true

echo "== policy after restart =="
adb -s "$DEVICE" shell '
echo "--- available outputs"
dumpsys media.audio_policy | sed -n "/Available output devices/,/Available input devices/p"
echo "--- primary supported devices"
dumpsys media.audio_policy | sed -n "/Handle: .*\"primary\"/,/Handle: .*\"usb\"/p" | grep -Ei "primary output|Supported devices|Speaker|HDMI|AUX|Output MixPorts|Audio Routes|route|Port ID" | head -180
echo "--- stream music"
dumpsys audio | sed -n "/- STREAM_MUSIC:/,/^- STREAM_ALARM/p"
'

echo "== route harness list =="
bash audio-output-switch/build_adb_harness.sh >/dev/null
adb -s "$DEVICE" push "$JAR" "$REMOTE_JAR" >/dev/null
adb -s "$DEVICE" shell "CLASSPATH=$REMOTE_JAR app_process /system/bin $MAIN list" || true

echo "== set synthetic TYPE_HDMI=9 once policy exists =="
adb -s "$DEVICE" shell "CLASSPATH=$REMOTE_JAR app_process /system/bin $MAIN setattrs 9 ''" || true
adb -s "$DEVICE" shell 'dumpsys audio | sed -n "/Preferred devices for strategy:/,/Non-default devices for strategy:/p"'
