# Limitations and Not-Yet-Proven Claims

## Proven only after a green public CI run

- clean convergence over SSH into one pinned Debian 13 and one pinned Arch systemd container;
- second-run Ansible idempotence on those two images;
- SSH, sudo, nftables, time-sync enablement, exporter, persistent timer, backup checksum, and freshness verification;
- bounded injection, diagnosis, recovery, and evidence for six drills on the Debian container;
- static lint, unit tests, secret scanning, and Ansible syntax validation.

## Not proven

- production fleet scale, availability, on-call judgment, or incident response time;
- kernel, init system, firewall, or package-manager behavior outside tested images;
- safe in-place use on a remote host without console access;
- offsite backup, restore objectives, encryption with external key custody, immutable storage, or disaster recovery;
- database-lock handling for PostgreSQL/MySQL; the drill uses SQLite to reproduce the symptom safely;
- DNS resolver outage or public PKI incident; the drill uses a reserved name and a local self-signed certificate;
- memory-pressure behavior outside the tested cgroup v2 environment;
- package bytes beyond the base image are fetched from live Debian security/update and Arch rolling repositories, so a later run can exercise newer packages even though base manifests and tool versions are pinned;
- Arch package-index refresh is deliberately excluded from the idempotence change count because pacman can report metadata refresh as changed; installed package state remains enforced and counted;
- container CI verifies `systemd-timesyncd` enablement but not synchronization: the upstream unit intentionally skips startup when `ConditionVirtualization=!container` is unmet;
- nftables proof uses service enablement plus the live `inet sre_filter` ruleset because Debian keeps its loader unit active while Arch's successful one-shot unit returns to inactive;
- unattended upgrades, vulnerability remediation, EDR, auditd, SELinux/AppArmor policy, or centralized identity;
- multi-host orchestration under partial failure or `serial` rollout behavior.

## Deliberate exclusions

The role does not silently enable unattended upgrades, replace an organization's identity system, expose metrics on all interfaces, collect journals, or ship backups offsite. Those choices require site-specific retention, privacy, rollback, access, and cost decisions.
