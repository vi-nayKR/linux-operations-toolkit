#!/usr/bin/env bats

@test "diagnostics collector writes the documented metadata-only bundle" {
  if [[ "$(uname -s)" != Linux ]]; then
    skip "diagnostics runtime is supported and tested on Linux"
  fi
  output_directory="$BATS_TEST_TMPDIR/diagnostics"
  run "$BATS_TEST_DIRNAME/../roles/safe_diagnostics/files/sre-diagnostics" "$output_directory"
  [ "$status" -eq 0 ]
  [ -f "$output_directory/MANIFEST.txt" ]
  [ -f "$output_directory/filesystems.txt" ]
  [ -f "$output_directory/memory.txt" ]
  grep -q '^scope=metadata-only$' "$output_directory/MANIFEST.txt"
  grep -q 'environment,process-command-lines,journals' "$output_directory/MANIFEST.txt"
  ! find "$output_directory" -type f \( -iname '*env*' -o -iname '*journal*' -o -iname '*config*' \) | grep -q .
}

@test "diagnostics collector refuses a symlink output" {
  real_directory="$BATS_TEST_TMPDIR/real"
  symlink_path="$BATS_TEST_TMPDIR/link"
  mkdir -p "$real_directory"
  ln -s "$real_directory" "$symlink_path"
  run "$BATS_TEST_DIRNAME/../roles/safe_diagnostics/files/sre-diagnostics" "$symlink_path"
  [ "$status" -eq 64 ]
  [[ "$output" == *"must not be a symlink"* ]]
}

@test "fault injection requires an explicit disposable-host acknowledgement" {
  run env -u SRE_DRILL_ACK "$BATS_TEST_DIRNAME/../drills/03-failed-service.sh"
  [ "$status" -eq 64 ]
  [[ "$output" == *"refusing fault injection"* ]]
}
