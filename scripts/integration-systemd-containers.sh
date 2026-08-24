#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_suffix="${GITHUB_RUN_ID:-$$}"
debian_container="linux-ops-debian-${run_suffix}"
arch_container="linux-ops-arch-${run_suffix}"
debian_image="linux-ops-debian:${run_suffix}"
arch_image="linux-ops-arch:${run_suffix}"
runtime_directory="$(mktemp -d "${RUNNER_TEMP:-/tmp}/linux-ops-integration.XXXXXX")"
evidence_directory="$repo_root/evidence/runtime"
known_hosts="$runtime_directory/known_hosts"
inventory="$runtime_directory/inventory.yml"
private_key="$runtime_directory/id_ed25519"

cleanup() {
  for container in "$debian_container" "$arch_container"; do
    if docker container inspect "$container" >/dev/null 2>&1; then
      expected_label="$(docker container inspect --format '{{ index .Config.Labels "io.github.vi-naykr.linux-operations-toolkit" }}' "$container")"
      if [[ "$expected_label" == integration-test ]]; then
        docker container rm --force "$container" >/dev/null
      fi
    fi
  done
}
trap cleanup EXIT

for tool in docker ansible-playbook ssh ssh-keygen ssh-keyscan; do
  if ! command -v "$tool" >/dev/null; then
    printf 'missing required integration tool: %s\n' "$tool" >&2
    exit 1
  fi
done
for container in "$debian_container" "$arch_container"; do
  if docker container inspect "$container" >/dev/null 2>&1; then
    printf 'refusing to replace existing container: %s\n' "$container" >&2
    exit 1
  fi
done

mkdir -p "$evidence_directory"
: > "$known_hosts"
ssh-keygen -q -t ed25519 -N '' -f "$private_key"
export SRE_OPERATOR_PUBLIC_KEY
SRE_OPERATOR_PUBLIC_KEY="$(<"$private_key.pub")"

docker build --tag "$debian_image" --file "$repo_root/tests/containers/debian/Dockerfile" "$repo_root"
docker build --tag "$arch_image" --file "$repo_root/tests/containers/arch/Dockerfile" "$repo_root"

start_node() {
  local container="$1"
  local image="$2"
  local hostname="$3"
  docker run --detach \
    --name "$container" \
    --hostname "$hostname" \
    --label io.github.vi-naykr.linux-operations-toolkit=integration-test \
    --privileged \
    --cgroupns=host \
    --tmpfs /run \
    --tmpfs /run/lock \
    --tmpfs /tmp \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --publish 127.0.0.1::22 \
    "$image" >/dev/null
}

start_node "$debian_container" "$debian_image" debian-node
start_node "$arch_container" "$arch_image" arch-node

wait_for_systemd() {
  local container="$1"
  for _ in $(seq 1 60); do
    state="$(docker exec "$container" systemctl is-system-running 2>/dev/null || true)"
    if [[ "$state" == running || "$state" == degraded ]]; then
      return
    fi
    sleep 1
  done
  docker container inspect --format 'state={{ .State.Status }} exit={{ .State.ExitCode }} error={{ .State.Error }}' "$container" >&2
  docker logs "$container" >&2 || true
  docker exec "$container" ps -ef >&2 || true
  docker exec "$container" systemctl --failed --no-pager >&2 || true
  docker exec "$container" journalctl --boot --no-pager --lines=100 >&2 || true
  printf 'systemd did not become usable in %s\n' "$container" >&2
  exit 1
}

bootstrap_ssh() {
  local container="$1"
  local service="$2"
  docker exec "$container" ssh-keygen -A
  docker exec "$container" install -d -m 0700 /root/.ssh
  docker cp "$private_key.pub" "$container:/root/.ssh/authorized_keys" >/dev/null
  docker exec "$container" chmod 0600 /root/.ssh/authorized_keys
  docker exec "$container" systemctl start "$service"
}

wait_for_systemd "$debian_container"
wait_for_systemd "$arch_container"
bootstrap_ssh "$debian_container" ssh
bootstrap_ssh "$arch_container" sshd

debian_port="$(docker port "$debian_container" 22/tcp | awk -F: 'NR == 1 { print $NF }')"
arch_port="$(docker port "$arch_container" 22/tcp | awk -F: 'NR == 1 { print $NF }')"
ssh-keyscan -H -p "$debian_port" 127.0.0.1 2>/dev/null | tee -a "$known_hosts" >/dev/null
ssh-keyscan -H -p "$arch_port" 127.0.0.1 2>/dev/null | tee -a "$known_hosts" >/dev/null

{
  printf '%s\n' '---' 'all:' '  children:' '    linux_fleet:' '      hosts:'
  printf '        debian-node:\n          ansible_host: 127.0.0.1\n          ansible_port: %s\n' "$debian_port"
  printf '        arch-node:\n          ansible_host: 127.0.0.1\n          ansible_port: %s\n' "$arch_port"
  printf '%s\n' '      vars:' '        ansible_user: root' '        ansible_become: false'
  printf '        ansible_ssh_private_key_file: %s\n' "$private_key"
  printf "        ansible_ssh_common_args: '-o UserKnownHostsFile=%s -o StrictHostKeyChecking=yes'\n" "$known_hosts"
} > "$inventory"

export ANSIBLE_NOCOLOR=1
ansible-playbook --inventory "$inventory" "$repo_root/tests/integration.yml" |
  tee "$evidence_directory/converge-first.log"
ansible-playbook --inventory "$inventory" "$repo_root/tests/integration.yml" |
  tee "$evidence_directory/converge-second.log"

if [[ "$(grep -Ec 'changed=0 +unreachable=0 +failed=0' "$evidence_directory/converge-second.log")" -ne 2 ]]; then
  printf 'second convergence was not idempotent on both nodes\n' >&2
  exit 1
fi

ssh_node() {
  local port="$1"
  shift
  ssh -i "$private_key" -p "$port" \
    -o BatchMode=yes -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts" -o StrictHostKeyChecking=yes \
    root@127.0.0.1 "$@"
}

ssh_operator() {
  local port="$1"
  shift
  ssh -i "$private_key" -p "$port" \
    -o BatchMode=yes -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts" -o StrictHostKeyChecking=yes \
    sre-operator@127.0.0.1 "$@"
}

verify_node() {
  local node_name="$1"
  local port="$2"
  local ssh_service="$3"
  {
    printf 'node=%s\n' "$node_name"
    ssh_node "$port" systemctl is-active "$ssh_service" nftables sre-textfile-exporter.service sre-backup.timer
    ssh_node "$port" systemctl is-enabled "$ssh_service" nftables systemd-timesyncd sre-textfile-exporter.service sre-backup.timer
    ssh_operator "$port" sudo -n true
    ssh_node "$port" /usr/sbin/sshd -T | grep -E '^(passwordauthentication no|kbdinteractiveauthentication no|permitrootlogin without-password)$'
    ssh_node "$port" systemctl start sre-backup.service
    ssh_node "$port" /usr/local/sbin/sre-backup-freshness
    ssh_node "$port" "cd /var/backups/sre-toolkit && sha256sum --check --status sre-backup-*.tar.gz.sha256"
    ssh_node "$port" curl --fail --silent --show-error http://127.0.0.1:9101/metrics | grep '^sre_backup_last_success_unixtime '
    ssh_node "$port" systemctl cat sre-backup.timer | grep '^Persistent=true$'
  } | tee "$evidence_directory/verify-${node_name}.log"
}

verify_node debian "$debian_port" ssh
verify_node arch "$arch_port" sshd

docker exec "$debian_container" install -d -m 0755 /opt/linux-operations-toolkit/scripts
docker cp "$repo_root/drills" "$debian_container:/opt/linux-operations-toolkit/" >/dev/null
docker cp "$repo_root/scripts/run-drills.sh" "$debian_container:/opt/linux-operations-toolkit/scripts/run-drills.sh" >/dev/null
docker exec "$debian_container" chmod 0755 /opt/linux-operations-toolkit/scripts/run-drills.sh
docker exec "$debian_container" find /opt/linux-operations-toolkit/drills -type f -name '*.sh' -exec chmod 0755 '{}' +
docker exec --env SRE_DRILL_ACK=disposable "$debian_container" \
  /opt/linux-operations-toolkit/scripts/run-drills.sh | tee "$evidence_directory/drills.log"
docker cp "$debian_container:/var/lib/sre-drills/evidence" "$evidence_directory/drills-debian" >/dev/null

if [[ "$(find "$evidence_directory/drills-debian" -maxdepth 1 -type f -name '*.log' | wc -l | tr -d ' ')" -ne 6 ]]; then
  printf 'expected evidence logs for six drills\n' >&2
  exit 1
fi
for log in "$evidence_directory"/drills-debian/*.log; do
  if ! grep -q 'recovered ' "$log"; then
    printf 'drill did not retain recovery evidence: %s\n' "$log" >&2
    exit 1
  fi
done

printf 'two-node convergence, idempotence, backup verification, and six drills passed\n'
