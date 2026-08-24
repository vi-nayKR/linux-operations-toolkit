#!/usr/bin/env bash
set -Eeuo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=drills/lib.sh
source "$script_directory/lib.sh"
require_disposable_drill_host

drill_name="stale-backup"
metric_file=/var/lib/sre-metrics/sre_backup_success.prom

printf 'bounded backup drill payload\n' > /srv/sre-backup-source/drill.txt
systemctl start sre-backup.service
if ! /usr/local/sbin/sre-backup-freshness >/dev/null; then
  record_drill "$drill_name" "failed initial_backup_not_fresh=true"
  exit 1
fi

now="$(date +%s)"
stale_epoch="$((now - 172800))"
metric_tmp="$(mktemp /var/lib/sre-metrics/.stale-backup.XXXXXX)"
awk -v stale="$stale_epoch" '
  $1 == "sre_backup_last_success_unixtime" { print $1, stale; next }
  { print }
' "$metric_file" > "$metric_tmp"
chmod 0644 "$metric_tmp"
mv -f "$metric_tmp" "$metric_file"

if /usr/local/sbin/sre-backup-freshness >/dev/null 2>&1; then
  record_drill "$drill_name" "failed stale_metric_not_detected=true"
  exit 1
fi
record_drill "$drill_name" "detected age_seconds=172800"
sleep 1
systemctl start sre-backup.service
/usr/local/sbin/sre-backup-freshness >/dev/null
record_drill "$drill_name" "recovered verified_backup_fresh=true"
