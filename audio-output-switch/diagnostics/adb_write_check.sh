#!/usr/bin/env bash
set -u

DEVICE="${1:-172.16.0.153:5555}"

echo "== mounts =="
adb -s "$DEVICE" shell 'mount | sed -n "1,120p"' || true

echo "== df =="
adb -s "$DEVICE" shell 'df -h / /system /system/system_ext 2>/dev/null || true' || true

echo "== write probe =="
adb -s "$DEVICE" shell 'touch /system/system_ext/etc/permissions/.codex-write-test 2>&1; rc=$?; rm -f /system/system_ext/etc/permissions/.codex-write-test 2>/dev/null; exit $rc' || true
