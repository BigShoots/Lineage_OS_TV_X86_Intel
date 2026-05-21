#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
ORIGINAL_ISO="$WORKSPACE/lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-signed.iso"
ORIGINAL_EFS="$WORKSPACE/work/iso-root/system.efs"
NEW_EFS="$WORKSPACE/work/system/system.efs.new"
PADDED_EFS="$WORKSPACE/work/system/system.efs.padded"
OUT_ISO="$WORKSPACE/out/lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output.iso"
SYSTEM_EFS_LBA=164344
SYSTEM_EFS_BLOCKS=1118436

orig_size="$(stat -c%s "$ORIGINAL_EFS")"
new_size="$(stat -c%s "$NEW_EFS")"
cp --sparse=always "$NEW_EFS" "$PADDED_EFS"
truncate -s "$orig_size" "$PADDED_EFS"
padded_size="$(stat -c%s "$PADDED_EFS")"
printf 'system.efs sizes: original=%s new=%s padded=%s\n' "$orig_size" "$new_size" "$padded_size"

fsck.erofs -p "$PADDED_EFS"

rm -f "$OUT_ISO"
cp --sparse=always "$ORIGINAL_ISO" "$OUT_ISO"
dd if="$PADDED_EFS" of="$OUT_ISO" bs=2048 seek="$SYSTEM_EFS_LBA" conv=notrunc status=progress

ls -lh "$OUT_ISO"
sha256sum "$OUT_ISO"
printf 'embedded system.efs sha256: '
dd if="$OUT_ISO" bs=2048 skip="$SYSTEM_EFS_LBA" count="$SYSTEM_EFS_BLOCKS" status=none | sha256sum
printf 'padded system.efs sha256:   '
sha256sum "$PADDED_EFS"
