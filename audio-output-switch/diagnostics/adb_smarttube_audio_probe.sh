#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" wait-for-device || exit 1

echo "== preferred media route =="
adb -s "$DEVICE" shell 'dumpsys audio | sed -n "/Preferred devices for strategy:/,/Non-default devices for strategy:/p"' || true

echo "== music stream =="
adb -s "$DEVICE" shell 'dumpsys audio | sed -n "/- STREAM_MUSIC:/,/^- STREAM_ALARM/p"' || true

echo "== playback players =="
adb -s "$DEVICE" shell 'dumpsys audio | sed -n "/players:/,/ducked players/p" | head -260' || true

echo "== audio flinger selected snippets =="
adb -s "$DEVICE" shell 'dumpsys media.audio_flinger | grep -Ei -C4 "Track|Output thread|MixerThread|DirectOutputThread|standby|device|sample|format|channel|session|active|org.smarttube" | head -520' || true

echo "== audio policy selected snippets =="
adb -s "$DEVICE" shell 'dumpsys media.audio_policy | grep -Ei -C4 "Output|Device|hdmi|speaker|strategy|active|stream|format|profile|mix|telephony|h2w" | head -640' || true

echo "== alsa/tools =="
adb -s "$DEVICE" shell '
for x in tinyplay tinymix tinypcminfo aplay speaker-test ffmpeg stagefright; do
    printf "%s=" "$x"
    which "$x" 2>/dev/null || true
done
echo "--- /proc/asound/cards"
cat /proc/asound/cards 2>/dev/null || true
echo "--- /proc/asound/pcm"
cat /proc/asound/pcm 2>/dev/null || true
echo "--- HDMI/DP ELD"
for f in /proc/asound/card*/eld*; do [ -r "$f" ] && echo "--- $f" && cat "$f"; done
' || true

echo "== recent SmartTube/audio logcat =="
adb -s "$DEVICE" logcat -d -v time | grep -Ei 'smarttube|org.smarttube|AudioTrack|AudioFlinger|AudioPolicy|audioflinger|audiopolicy|ExoPlayer|MediaCodec|codec|AudioSink|unsupported|hdmi|pcm|EACCES|denied' | tail -300 || true
