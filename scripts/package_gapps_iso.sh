#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
ORIGINAL_ISO="$WORKSPACE/lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-signed.iso"
EROFS_ROOT="$WORKSPACE/work/system/erofs-build-root"
SYSTEM_IMG="$WORKSPACE/work/system/system.img"
NEW_EFS="$WORKSPACE/work/system/system.efs.gapps"
OUT_ISO="$WORKSPACE/out/lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-audio-output-gapps.iso"
UUID="f94efea1-cebe-4f16-b2ee-340f2ca1f8e4"

rm -rf "$EROFS_ROOT"
mkdir -p "$EROFS_ROOT"
cp --sparse=always "$SYSTEM_IMG" "$EROFS_ROOT/system.img"

rm -f "$NEW_EFS" "$OUT_ISO"

echo "== building EROFS system.efs =="
mkfs.erofs -zlz4hc,12 -C65536 -Ebig_pcluster -U "$UUID" "$NEW_EFS" "$EROFS_ROOT"
fsck.erofs -p "$NEW_EFS"
ls -lh "$NEW_EFS"

echo "== rebuilding bootable ISO with larger system.efs =="
xorriso \
    -indev "$ORIGINAL_ISO" \
    -outdev "$OUT_ISO" \
    -map "$NEW_EFS" /system.efs \
    -boot_image any replay \
    -compliance no_emul_toc

ls -lh "$OUT_ISO"
sha256sum "$OUT_ISO"

echo "== boot layout summary =="
xorriso -indev "$OUT_ISO" -report_el_torito plain -report_system_area plain 2>&1 | sed -n '1,80p'
