# Curated Evidence

## Accepted two-node workflow

- Public run: [GitHub Actions `32766027669`](https://github.com/vi-nayKR/linux-operations-toolkit/actions/runs/32766027669)
- Commit: `3071d23ea574804d056f86e7d9d51062849a8c75`
- Started: 2026-08-24 19:04:21 UTC
- Completed: 2026-08-24 19:06:42 UTC
- Environment: GitHub-hosted AMD64 Linux runner; privileged, labelled Debian 13 and Arch systemd containers; cgroup v2; Ansible transport over ephemeral SSH keys

The uploaded artifact contains the fields required by [../docs/EVIDENCE.md](../docs/EVIDENCE.md):

- the second Ansible run reports `changed=0`, `unreachable=0`, and `failed=0` for both Debian and Arch;
- SSH, nftables, time synchronization, the textfile exporter and the persistent backup timer pass their declared service-state checks on both nodes;
- effective SSH policy disables password and keyboard-interactive authentication while allowing only key-based root semantics;
- both nodes create a checksum-verifiable archive, report a fresh last-success metric and show `Persistent=true` on the timer;
- all six Debian fault injections record a detected symptom and a recovered state;
- the memory-pressure drill records `result=oom-kill`, exit status 9 and successful unit cleanup under a 32 MiB cgroup limit;
- the disk-pressure and failed-service artifacts contain the bounded metadata-only diagnostic set.

Runtime output is retained by the workflow for seven days and is not committed because it contains changing ports, runner state and timestamps. CI-generated SSH private keys and backup payloads are never uploaded. The repository evidence proves a bounded disposable-container exercise, not production fleet scale, off-host disaster recovery or professional on-call experience.

The failed acceptance iterations and completed corrective actions are documented in [the convergence postmortem](../postmortems/2026-08-24-cross-distribution-convergence.md).
