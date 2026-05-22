#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")/../.." && pwd)"
SYSTEM_IMG="$WORKSPACE/work/system/system.img"
MNT="$WORKSPACE/work/system/primary-hdmi-policy-mnt"
POLICY="$MNT/system/vendor/etc/audio_policy_configuration.xml"

cleanup() {
    umount "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$MNT"
umount -l "$MNT" 2>/dev/null || true
mount -o loop,rw "$SYSTEM_IMG" "$MNT"

python3 - "$POLICY" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
xml = path.read_text()
if 'tagName="HDMI Out"' not in xml:
    replacements = [
        (
            "                <item>Speaker</item>\n",
            "                <item>Speaker</item>\n"
            "                <item>HDMI Out</item>\n",
        ),
        (
            """                <devicePort tagName="Wired Headphones" type="AUDIO_DEVICE_OUT_WIRED_HEADPHONE" role="sink">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                             samplingRates="48000" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>
                </devicePort>

""",
            """                <devicePort tagName="Wired Headphones" type="AUDIO_DEVICE_OUT_WIRED_HEADPHONE" role="sink">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                             samplingRates="48000" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>
                </devicePort>
                <devicePort tagName="HDMI Out" type="AUDIO_DEVICE_OUT_AUX_DIGITAL" role="sink">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                             samplingRates="48000" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>
                </devicePort>

""",
        ),
        (
            """                <route type="mix" sink="Speaker"
                       sources="primary output"/>
""",
            """                <route type="mix" sink="Speaker"
                       sources="primary output"/>
                <route type="mix" sink="HDMI Out"
                       sources="primary output"/>
""",
        ),
    ]
    for old, new in replacements:
        if old not in xml:
            raise SystemExit(f"audio policy patch anchor missing: {old[:80]!r}")
        xml = xml.replace(old, new, 1)
    path.write_text(xml)
else:
    print("Primary HDMI policy already present")
PY

chown 0:0 "$POLICY"
chmod 0644 "$POLICY"
chcon -h u:object_r:system_file:s0 "$POLICY" || true

grep -n 'HDMI Out' "$POLICY"

sync
umount "$MNT"
trap - EXIT

e2fsck -fy "$SYSTEM_IMG"
