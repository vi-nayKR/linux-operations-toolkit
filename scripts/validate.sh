#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for tool in ansible-lint ansible-playbook bats gitleaks pytest shellcheck yamllint; do
  if ! command -v "$tool" >/dev/null; then
    printf 'missing validation tool: %s\n' "$tool" >&2
    exit 1
  fi
done

shell_files=()
while IFS= read -r shell_file; do
  shell_files+=("$shell_file")
done < <(find drills scripts -type f -name '*.sh' -print | sort)
shell_files+=(
  roles/durable_backup/files/sre-backup
  roles/durable_backup/files/sre-backup-freshness
  roles/safe_diagnostics/files/sre-diagnostics
)
shellcheck --external-sources "${shell_files[@]}"
bats tests/backup.bats tests/diagnostics.bats
pytest -q tests/test_exporter.py
yamllint .
ansible-lint
ansible-playbook --syntax-check playbooks/site.yml
python3 -m py_compile roles/linux_baseline/files/sre-textfile-exporter tests/test_exporter.py
gitleaks dir . --no-banner --redact --verbose

printf 'static Linux operations validation passed\n'
