#!/usr/bin/env bash
set -euo pipefail

MNT="work/system/mnt"

umount -l "$MNT" 2>/dev/null || true
mount -o loop,ro work/system/system.img "$MNT"
trap 'umount "$MNT" 2>/dev/null || true' EXIT

echo "== feature XML =="
find "$MNT/system" -path '*/etc/permissions/*' -type f \
    | sed "s#$MNT/system/##" \
    | sort \
    | grep -Ei 'hdmi|cec|tv|ir' || true

echo "== VINTF files containing CEC/HDMI =="
find "$MNT/system" -path '*/etc/vintf/*' -type f | while read -r file; do
    if grep -aqEi 'cec|hdmi' "$file"; then
        echo "--- ${file#$MNT/system/}"
        grep -aiE 'cec|hdmi' "$file"
    fi
done

echo "== CEC/HDMI executables and libraries =="
find "$MNT/system" -type f \( -iname '*cec*' -o -iname '*hdmi*cec*' -o -iname 'android.hardware.tv*' \) \
    | sed "s#$MNT/system/##" \
    | sort \
    | head -250

echo "== vendor manifest TV/CEC/HDMI snippets =="
if [ -f "$MNT/system/vendor/etc/vintf/manifest.xml" ]; then
    grep -aiE -C2 'cec|hdmi|tv' "$MNT/system/vendor/etc/vintf/manifest.xml" || true
fi

echo "== kernel CEC modules in image =="
find "$MNT/system/lib/modules" -type f -iname '*cec*.ko' \
    | sed "s#$MNT/system/##" \
    | sort
