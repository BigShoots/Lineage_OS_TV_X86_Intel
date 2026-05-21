#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
SYSTEM_IMG="$WORKSPACE/work/system/system.img"
MNT="$WORKSPACE/work/system/usb-storage-visibility-mnt"

cleanup() {
    umount "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

patch_fstab() {
    local file="$1"
    [ -f "$file" ] || return 0

    local tmp="${file}.tmp"
    awk '
        BEGIN { OFS = "\t" }
        /voldmanaged=(usb|usbdisk)/ && $0 !~ /encryptable=/ {
            $5 = $5 ",encryptable=userdata"
        }
        { print }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
    chown 0:0 "$file"
    chmod 0644 "$file"
    chcon -h u:object_r:system_file:s0 "$file" || true
}

patch_build_prop() {
    local file="$1"
    [ -f "$file" ] || return 0

    if grep -q '^persist.sys.adoptable=' "$file"; then
        sed -i 's/^persist\.sys\.adoptable=.*/persist.sys.adoptable=force_on/' "$file"
    else
        printf '\n# Make public USB storage app-visible on Android TV x86.\npersist.sys.adoptable=force_on\n' >> "$file"
    fi
    chown 0:0 "$file"
    chmod 0644 "$file"
    chcon -h u:object_r:system_file:s0 "$file" || true
}

mkdir -p "$MNT"
umount -l "$MNT" 2>/dev/null || true
mount -o loop,rw "$SYSTEM_IMG" "$MNT"

patch_fstab "$MNT/fstab.lineage_x86_64_tv"
patch_fstab "$MNT/system/vendor/etc/fstab.internal.x86"
patch_build_prop "$MNT/system/build.prop"

echo "== patched fstab entries =="
grep -n 'voldmanaged=.*usb' "$MNT/fstab.lineage_x86_64_tv" "$MNT/system/vendor/etc/fstab.internal.x86" || true
echo "== adoptable property =="
grep -n '^persist.sys.adoptable=' "$MNT/system/build.prop"

sync
umount "$MNT"
trap - EXIT

e2fsck -fy "$SYSTEM_IMG"
