#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SRE_DRILL_ACK="${SRE_DRILL_ACK:-}"

for drill in \
  01-disk-pressure.sh \
  02-memory-pressure.sh \
  03-failed-service.sh \
  04-dns-tls.sh \
  05-database-lock.sh \
  06-stale-backup.sh; do
  printf 'running %s\n' "$drill"
  "$repo_root/drills/$drill"
done

printf 'all six bounded drills recovered successfully\n'
