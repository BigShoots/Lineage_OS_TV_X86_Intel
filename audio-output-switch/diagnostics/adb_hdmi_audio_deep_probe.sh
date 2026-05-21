#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" wait-for-device || exit 1

echo "== adb/root =="
adb -s "$DEVICE" root || true
adb -s "$DEVICE" wait-for-device || true

echo "== current route/track state =="
adb -s "$DEVICE" shell '
echo "--- preferred media route"
dumpsys audio | sed -n "/Preferred devices for strategy:/,/Non-default devices for strategy:/p"
echo "--- stream music"
dumpsys audio | sed -n "/- STREAM_MUSIC:/,/^- STREAM_ALARM/p"
echo "--- active SmartTube playback config"
dumpsys audio | sed -n "/players:/,/ducked players/p" | grep -Ei "smarttube|AudioTrack|state:started|deviceId|FormatInfo" || true
'

echo "== Android audio policy summary =="
adb -s "$DEVICE" shell '
echo "--- config source and available output devices"
dumpsys media.audio_policy | sed -n "/AudioPolicyManager Dump:/,/Available input devices/p"
echo "--- hardware modules"
dumpsys media.audio_policy | sed -n "/Hardware modules/,/Output Routes/p"
echo "--- output routes"
dumpsys media.audio_policy | sed -n "/Output Routes/,/Input Routes/p"
'

echo "== HAL/properties/files =="
adb -s "$DEVICE" shell '
echo "--- audio props"
getprop | grep -Ei "audio|alsa|hdmi|drm|ffmpeg" | sort || true
echo "--- audio HAL files"
ls -l /vendor/lib*/hw/audio* /system/lib*/hw/audio* /odm/lib*/hw/audio* 2>/dev/null || true
echo "--- audio policy XML files"
ls -l /vendor/etc/*audio* /system/etc/*audio* /odm/etc/*audio* 2>/dev/null || true
echo "--- available tinyalsa/aplay tools"
for x in tinyplay tinymix tinypcminfo tinycap aplay speaker-test ffmpeg stagefright; do
    printf "%s=" "$x"
    command -v "$x" 2>/dev/null || true
done
'

echo "== ALSA state =="
adb -s "$DEVICE" shell '
echo "--- cards"
cat /proc/asound/cards 2>/dev/null || true
echo "--- pcm"
cat /proc/asound/pcm 2>/dev/null || true
echo "--- devices"
cat /proc/asound/devices 2>/dev/null || true
echo "--- ELD"
for f in /proc/asound/card*/eld*; do
    [ -r "$f" ] && echo "--- $f" && cat "$f"
done
echo "--- snd nodes"
ls -l /dev/snd 2>/dev/null || true
'

echo "== policy XML snippets =="
adb -s "$DEVICE" shell '
for f in /vendor/etc/audio_policy_configuration.xml /vendor/etc/hdmi_audio_policy_configuration.xml /vendor/etc/usb_audio_policy_configuration.xml; do
    [ -r "$f" ] || continue
    echo "--- $f"
    grep -nEi "module|mixPort|devicePort|route|HDMI|Speaker|Telephony|AUDIO_DEVICE_OUT_LINE|AUDIO_DEVICE_OUT_HDMI|attachedDevices|defaultOutputDevice" "$f" | head -220
done
'

echo "== recent primary HAL/audio log =="
adb -s "$DEVICE" logcat -d -v time | grep -Ei 'audio_hw_primary|primary_audio|pcmC|alsa|AudioFlinger|AudioPolicy|setOutputDevice|open_output|create_audio_patch|hdmi|speaker' | tail -260 || true
