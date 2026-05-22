#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_DIR="$WORKSPACE/work/audio-output-switch"
SYSTEM_IMG="$WORKSPACE/work/system/system.img"
KEYLAYOUT="$PROJECT_DIR/keylayout/Vendor_0171_Product_0413.kl"
MNT="$WORKSPACE/work/system/fire-remote-keylayout-mnt"

if [ ! -f "$KEYLAYOUT" ]; then
    echo "Missing keylayout: $KEYLAYOUT" >&2
    exit 1
fi

cleanup() {
    umount "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$MNT"
umount -l "$MNT" 2>/dev/null || true
mount -o loop,rw "$SYSTEM_IMG" "$MNT"

KL_DIR="$MNT/system/usr/keylayout"
mkdir -p "$KL_DIR"
install -m 0644 -o 0 -g 0 "$KEYLAYOUT" "$KL_DIR/Vendor_0171_Product_0413.kl"
chcon -h u:object_r:system_file:s0 "$KL_DIR/Vendor_0171_Product_0413.kl" || true

sync
umount "$MNT"
trap - EXIT

e2fsck -fy "$SYSTEM_IMG"
