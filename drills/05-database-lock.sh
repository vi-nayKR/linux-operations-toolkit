#!/usr/bin/env bash
set -Eeuo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=drills/lib.sh
source "$script_directory/lib.sh"
require_disposable_drill_host

drill_name="database-lock"
sandbox=/var/lib/sre-drills/database-lock
database="$sandbox/drill.sqlite3"
ready_file="$sandbox/locked"
locker_pid=""

cleanup() {
  if [[ -n "$locker_pid" ]]; then
    kill "$locker_pid" >/dev/null 2>&1 || true
    wait "$locker_pid" 2>/dev/null || true
  fi
  rm -f -- "$database" "${database}-journal" "${database}-wal" "${database}-shm" "$ready_file" "$sandbox/lock-error.txt"
  rmdir "$sandbox" 2>/dev/null || true
}
trap cleanup EXIT
install -d -m 0700 "$sandbox"

/usr/bin/python3 - "$database" "$ready_file" <<'PY' &
import sqlite3
import sys
import time

connection = sqlite3.connect(sys.argv[1])
connection.execute("CREATE TABLE IF NOT EXISTS drill_events (value TEXT)")
connection.execute("BEGIN EXCLUSIVE")
connection.execute("INSERT INTO drill_events VALUES ('held')")
open(sys.argv[2], "w", encoding="utf-8").close()
time.sleep(20)
PY
locker_pid=$!

for _ in $(seq 1 40); do
  [[ -f "$ready_file" ]] && break
  sleep 0.1
done
if [[ ! -f "$ready_file" ]]; then
  record_drill "$drill_name" "failed lock_not_acquired=true"
  exit 1
fi

if /usr/bin/python3 - "$database" 2>"$sandbox/lock-error.txt" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1], timeout=0.1)
connection.execute("INSERT INTO drill_events VALUES ('unexpected')")
connection.commit()
PY
then
  record_drill "$drill_name" "failed concurrent_write_succeeded=true"
  exit 1
fi
if ! grep -q 'database is locked' "$sandbox/lock-error.txt"; then
  record_drill "$drill_name" "failed expected_lock_diagnosis=true"
  exit 1
fi
record_drill "$drill_name" "detected sqlite_error=database_is_locked"

kill "$locker_pid"
wait "$locker_pid" 2>/dev/null || true
locker_pid=""
/usr/bin/python3 - "$database" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1], timeout=1)
connection.execute("INSERT INTO drill_events VALUES ('recovered')")
connection.commit()
PY
record_drill "$drill_name" "recovered write_succeeded=true"
