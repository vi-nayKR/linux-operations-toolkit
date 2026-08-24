#!/usr/bin/env bash
set -Eeuo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=drills/lib.sh
source "$script_directory/lib.sh"
require_disposable_drill_host

drill_name="memory-pressure"
unit_name=sre-drill-memory.service

cleanup() {
  systemctl stop "$unit_name" >/dev/null 2>&1 || true
  systemctl reset-failed "$unit_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

systemd-run --unit="$unit_name" --property=MemoryMax=32M --property=RuntimeMaxSec=20 \
  /usr/bin/python3 -c 'import time; allocation = bytearray(128 * 1024 * 1024); time.sleep(15)' >/dev/null

result=""
for _ in $(seq 1 40); do
  result="$(systemctl show "$unit_name" --property=Result --value 2>/dev/null || true)"
  substate="$(systemctl show "$unit_name" --property=SubState --value 2>/dev/null || true)"
  if [[ "$result" == oom-kill || "$substate" == failed ]]; then
    break
  fi
  sleep 0.25
done

main_status="$(systemctl show "$unit_name" --property=ExecMainStatus --value)"
if [[ "$result" != oom-kill && "$main_status" != 9 ]]; then
  record_drill "$drill_name" "failed expected_oom result=$result status=$main_status"
  exit 1
fi
record_drill "$drill_name" "detected result=$result exec_status=$main_status memory_max=32M"
cleanup
trap - EXIT
record_drill "$drill_name" "recovered unit_failed=false"
