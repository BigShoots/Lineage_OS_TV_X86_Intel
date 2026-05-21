# LineageOS TV x86 Intel Patches

This repository contains the source files, image patch scripts, validation scripts, and test notes used to build a patched LineageOS 21 Android TV x86_64 ISO for Intel mini PCs.

The working target was `lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-signed.iso` on a 7th generation Intel mini PC connected over DisplayPort-to-HDMI.

## Improvements Over Stock

- Adds a privileged Android TV audio output switcher at the existing TV Settings sound entry point.
- Persists the selected media output device and reapplies it after boot.
- Filters unsafe/bogus policy routes such as telephony and bus outputs.
- Exposes the primary HDMI/DisplayPort PCM path to Android audio policy so media apps can route to HDMI audio.
- Makes public USB storage app-visible on Android TV x86 by enabling adoptable-style vold visibility.
- Includes scripts to integrate a user-supplied MindTheGapps Android TV x86_64 package into the ISO.
- Includes ADB probes for audio routing, HDMI PCM, USB storage, CEC, HDR, and app-level playback debugging.

## Important Caveats

- The GApps ZIP is not included in this repository. Place your own compatible MindTheGapps ATV x86_64 Android 14 ZIP in the workspace before running the integration script.
- The tested Intel setup did not expose Android HDMI-CEC support.
- The tested Intel setup did not advertise HDR output support.
- Material Files should use normal file access, not root-only mode, because this build has ADB root but not a normal `su` provider.

## Final Tested ISO

The local build produced:

`lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output-gapps.iso`

SHA-256:

`cbd4129200c3685ef0108e761d8531695becf858ba79e5dc2a9ae8079a78e8d1`

Size:

`2812321792` bytes

GitHub release assets must be under 2 GiB each, so the ISO should be uploaded as multipart archives.

## Repository Layout

- `audio-output-switch/app`: privileged audio switcher app source.
- `audio-output-switch/diagnostics`: ADB test and probe scripts used during bring-up.
- `audio-output-switch/*.xml`: privapp and hidden API allowlist files for the switcher.
- `scripts`: image patch, packaging, GApps integration, and validation scripts.
- `release`: checksums and release asset metadata.

## Build Flow

The scripts assume the workspace layout used during development:

- `work/iso-root`
- `work/system/system.img`
- `audio-output-switch`
- `out`

High-level flow:

```bash
bash scripts/install_audio_switcher_to_system_img.sh
bash scripts/install_primary_hdmi_policy_to_system_img.sh
bash scripts/install_usb_storage_visibility_to_system_img.sh
bash scripts/integrate_mindthegapps.sh /path/to/MindTheGapps-14.0.0-x86_64-ATV-full.zip
bash scripts/package_gapps_iso.sh
bash scripts/validate_gapps_iso.sh
```
