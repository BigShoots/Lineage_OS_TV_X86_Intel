#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"
WAV_LOCAL="work/audio-output-switch/build/hdmi-test-tone.wav"
WAV_REMOTE="/data/local/tmp/hdmi-test-tone.wav"

mkdir -p "$(dirname "$WAV_LOCAL")"
python3 - <<'PY'
import math
import os
import struct
import wave

path = "work/audio-output-switch/build/hdmi-test-tone.wav"
rate = 48000
seconds = 1.2
freq = 880.0
frames = int(rate * seconds)
amp = 0.35

with wave.open(path, "wb") as wf:
    wf.setnchannels(2)
    wf.setsampwidth(2)
    wf.setframerate(rate)
    for i in range(frames):
        # Gentle fade avoids a click at the beginning/end.
        fade = min(1.0, i / 1200.0, (frames - i - 1) / 1200.0)
        sample = int(32767 * amp * fade * math.sin(2 * math.pi * freq * i / rate))
        wf.writeframesraw(struct.pack("<hh", sample, sample))
PY

adb connect "$DEVICE" >/dev/null || true
adb -s "$DEVICE" wait-for-device || exit 1
adb -s "$DEVICE" root >/dev/null || true
adb -s "$DEVICE" wait-for-device || true
adb -s "$DEVICE" push "$WAV_LOCAL" "$WAV_REMOTE" >/dev/null || exit 1

echo "== aplay device list =="
adb -s "$DEVICE" shell /system/bin/aplay -l || true

echo "== direct playback tests =="
for dev in hw:0,3 hw:0,7 hw:0,8 hw:0,0; do
    echo "--- $dev"
    adb -s "$DEVICE" shell "/system/bin/aplay -D $dev -v $WAV_REMOTE" 2>&1
    echo "exit=$?"
done
