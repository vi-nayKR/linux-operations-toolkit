#!/usr/bin/env bash
set -Eeuo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=drills/lib.sh
source "$script_directory/lib.sh"
require_disposable_drill_host

drill_name="disk-pressure"
sandbox=/var/lib/sre-drills/disk-pressure
mount_path="$sandbox/volume"

cleanup() {
  if mountpoint -q "$mount_path" 2>/dev/null; then
    umount "$mount_path"
  fi
  rm -f -- "$mount_path/payload.bin" 2>/dev/null || true
  rmdir "$mount_path" "$sandbox" 2>/dev/null || true
}
trap cleanup EXIT

install -d -m 0700 "$mount_path"
mount -t tmpfs -o size=16m,nodev,nosuid,noexec tmpfs "$mount_path"
dd if=/dev/zero of="$mount_path/payload.bin" bs=1M count=15 status=none
usage="$(df --output=pcent "$mount_path" | awk 'NR == 2 { gsub(/%/, ""); print $1 }')"
if (( usage < 90 )); then
  record_drill "$drill_name" "failed expected_pressure usage_percent=$usage"
  exit 1
fi
record_drill "$drill_name" "detected usage_percent=$usage"
/usr/local/sbin/sre-diagnostics "/var/lib/sre-drills/evidence/${drill_name}-diagnostics" >/dev/null
cleanup
trap - EXIT
record_drill "$drill_name" "recovered mount_removed=true"
