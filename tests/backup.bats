#!/usr/bin/env bats

setup() {
  if [[ "$(uname -s)" != Linux ]]; then
    skip "durable backup runtime is supported and tested on Linux"
  fi
  export TEST_ROOT="$BATS_TEST_TMPDIR/backup"
  export TEST_SOURCE="$TEST_ROOT/source"
  export TEST_DESTINATION="$TEST_ROOT/destination"
  export TEST_METRICS="$TEST_ROOT/metrics"
  export SRE_BACKUP_CONFIG="$TEST_ROOT/sre-backup.conf"
  mkdir -p "$TEST_SOURCE" "$TEST_DESTINATION" "$TEST_METRICS"
  printf 'managed test destination\n' > "$TEST_DESTINATION/.sre-backup-managed"
  printf 'payload\n' > "$TEST_SOURCE/payload.txt"
  {
    printf 'SRE_BACKUP_SOURCE=%q\n' "$TEST_SOURCE"
    printf 'SRE_BACKUP_DESTINATION=%q\n' "$TEST_DESTINATION"
    printf 'SRE_BACKUP_METRIC_DIRECTORY=%q\n' "$TEST_METRICS"
    printf 'SRE_BACKUP_RETENTION=2\n'
    printf 'SRE_BACKUP_FRESHNESS_SECONDS=3600\n'
  } > "$SRE_BACKUP_CONFIG"
}

@test "backup creates and verifies an archive, checksum, and metrics" {
  run "$BATS_TEST_DIRNAME/../roles/durable_backup/files/sre-backup"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verified backup created"* ]]

  archive="$(find "$TEST_DESTINATION" -maxdepth 1 -name 'sre-backup-*.tar.gz' -print -quit)"
  [ -n "$archive" ]
  [ -f "$archive.sha256" ]
  run sh -c "cd '$TEST_DESTINATION' && sha256sum --check --status '$(basename "$archive").sha256'"
  [ "$status" -eq 0 ]
  grep -q '^sre_backup_last_success_unixtime ' "$TEST_METRICS/sre_backup_success.prom"
  grep -q '^sre_backup_last_run_success 1$' "$TEST_METRICS/sre_backup_run.prom"

  run env SRE_BACKUP_CONFIG="$SRE_BACKUP_CONFIG" \
    "$BATS_TEST_DIRNAME/../roles/durable_backup/files/sre-backup-freshness"
  [ "$status" -eq 0 ]
}

@test "failed backup records the attempt without inventing a success" {
  rm -f "$TEST_SOURCE/payload.txt"
  rmdir "$TEST_SOURCE"

  run "$BATS_TEST_DIRNAME/../roles/durable_backup/files/sre-backup"
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_METRICS/sre_backup_success.prom" ]
  grep -q '^sre_backup_last_run_success 0$' "$TEST_METRICS/sre_backup_run.prom"
}

@test "freshness checker detects a stale success timestamp" {
  cat > "$TEST_METRICS/sre_backup_success.prom" <<'METRIC'
sre_backup_last_success_unixtime 1000
METRIC
  run env SRE_BACKUP_CONFIG="$SRE_BACKUP_CONFIG" SRE_NOW_EPOCH=5001 \
    "$BATS_TEST_DIRNAME/../roles/durable_backup/files/sre-backup-freshness"
  [ "$status" -eq 2 ]
  [[ "$output" == *"stale backup"* ]]
}

@test "backup refuses an unmarked destination" {
  rm -f "$TEST_DESTINATION/.sre-backup-managed"
  run "$BATS_TEST_DIRNAME/../roles/durable_backup/files/sre-backup"
  [ "$status" -eq 73 ]
  [[ "$output" == *"lacks the role-managed marker"* ]]
}
