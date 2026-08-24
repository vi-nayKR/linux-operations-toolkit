#!/usr/bin/env bash
set -Eeuo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=drills/lib.sh
source "$script_directory/lib.sh"
require_disposable_drill_host

drill_name="failed-service"
unit_name=sre-drill-failed.service
unit_path="/run/systemd/system/$unit_name"

cleanup() {
  systemctl stop "$unit_name" >/dev/null 2>&1 || true
  systemctl reset-failed "$unit_name" >/dev/null 2>&1 || true
  rm -f -- "$unit_path"
  systemctl daemon-reload >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

install -m 0644 /dev/null "$unit_path"
{
  printf '[Unit]\nDescription=Disposable expected-failure drill\n'
  printf '[Service]\nType=oneshot\nExecStart=/bin/false\n'
} > "$unit_path"
systemctl daemon-reload
if systemctl start "$unit_name" >/dev/null 2>&1; then
  record_drill "$drill_name" "failed service_unexpectedly_started=true"
  exit 1
fi
if ! systemctl is-failed --quiet "$unit_name"; then
  record_drill "$drill_name" "failed expected_failed_state=true"
  exit 1
fi
record_drill "$drill_name" "detected active_state=failed"
/usr/local/sbin/sre-diagnostics "/var/lib/sre-drills/evidence/${drill_name}-diagnostics" >/dev/null
cleanup
trap - EXIT
if systemctl list-unit-files "$unit_name" --no-legend 2>/dev/null | grep -q "$unit_name"; then
  record_drill "$drill_name" "failed unit_still_loaded=true"
  exit 1
fi
record_drill "$drill_name" "recovered unit_removed=true"
