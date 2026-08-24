# Linux Operations Toolkit

[![ci](https://github.com/vi-nayKR/linux-operations-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/vi-nayKR/linux-operations-toolkit/actions/workflows/ci.yml)

An evidence-driven Linux fleet baseline for Debian and Arch systems. Ansible converges users, SSH, packages, time sync, nftables, a small Prometheus textfile exporter, a persistent verified backup timer, and metadata-only diagnostics. Disposable systemd containers then prove second-run idempotence and exercise six bounded failure/recovery drills.

This repository answers one reliability question:

> Can a small heterogeneous Linux fleet converge, reveal drift, and recover common failures?

## What it proves

- Debian 13 and current Arch package/service differences are explicit rather than hidden behind shell conditionals.
- A second Ansible convergence must report `changed=0`, `unreachable=0`, and `failed=0` for both nodes.
- Backups are locked, created in the destination filesystem, atomically renamed, listed, checksummed, re-verified, retained, and exposed through last-run and last-success metrics.
- The systemd timer uses `Persistent=true`; a missed run after downtime is not silently lost.
- Diagnostics collect bounded host metadata without environment variables, process command lines, journals, application configuration, credentials, or cloud metadata.
- Six disposable drills detect and recover disk pressure, cgroup memory pressure, a failed unit, DNS/TLS failures, a database lock, and a stale backup.

These are lab claims. They are not evidence of professional on-call, production fleet scale, disaster recovery, or off-host backup durability.

## Repository map

```text
roles/linux_baseline/       users, SSH, packages, nftables, time sync, exporter
roles/durable_backup/       verified backup service/timer and freshness check
roles/safe_diagnostics/     metadata-only diagnostic collector
drills/                     guarded fault injection and recovery checks
runbooks/                   operator diagnosis and recovery paths
tests/containers/           pinned Debian and Arch systemd test images
scripts/                    validation and two-node integration harness
docs/                       architecture, safety, limitations, and evidence rules
```

## Safe quick start

Use an existing non-root account with sudo for the first convergence. Copy `inventory/example.yml`, replace the RFC 5737 documentation addresses, and declare public keys. Do not put private keys, password hashes, vault passwords, host secrets, or live inventory into Git.

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --requirement requirements.txt
ansible-galaxy collection install --requirement collections/requirements.yml
ansible-playbook --inventory inventory/your-fleet.yml playbooks/site.yml --check --diff
ansible-playbook --inventory inventory/your-fleet.yml playbooks/site.yml
```

Review nftables access, SSH behavior, backup paths, and sudo policy before removing `--check`. The default exporter binds only to `127.0.0.1:9101`; use an authenticated collector path or SSH tunnel instead of exposing it broadly.

## Validation

Static validation requires the pinned Python requirements plus Bats 1.14.0, ShellCheck 0.11.0, and Gitleaks 8.30.1:

```bash
./scripts/validate.sh
```

The full integration harness requires Linux, Docker with privileged container support, and cgroup v2. It creates two uniquely named, labelled disposable containers and refuses to replace pre-existing names:

```bash
./scripts/integration-systemd-containers.sh
```

Fault injection has a second guard. It runs only in a detected container unless a disposable VM is explicitly acknowledged:

```bash
SRE_DRILL_ACK=disposable ./scripts/run-drills.sh
```

Never run the drill suite on a production host. Start with [docs/SAFETY.md](docs/SAFETY.md) and the individual runbook.

## Operational choices

| Concern | Debian family | Arch family |
| --- | --- | --- |
| Package manager | APT | pacman |
| SSH package/service | `openssh-server` / `ssh` | `openssh` / `sshd` |
| Python package | `python3` | `python` |
| Process tools | `procps` | `procps-ng` |
| Time sync package | `systemd-timesyncd` | provided by `systemd` |
| Firewall | nftables | nftables |

The role deliberately supports only these two OS families. Unsupported systems fail before mutation.

## Evidence boundary

CI uploads short-lived raw convergence and drill artifacts. The repository retains the evidence method and a curated record without committing changing runtime output. See [docs/EVIDENCE.md](docs/EVIDENCE.md) and [docs/LIMITATIONS.md](docs/LIMITATIONS.md).
