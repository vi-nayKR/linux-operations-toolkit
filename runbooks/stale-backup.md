# Runbook: Stale or Failed Backup

## Signals

`sre_backup_last_run_success == 0`, last-success age above the agreed threshold, a missed timer, missing archive/checksum, capacity errors, or restore verification failure.

## Diagnose

```bash
systemctl status sre-backup.timer sre-backup.service --no-pager
systemctl list-timers sre-backup.timer --all
/usr/local/sbin/sre-backup-freshness
find /var/backups/sre-toolkit -maxdepth 1 -name 'sre-backup-*.tar.gz' -ls
cd /var/backups/sre-toolkit && sha256sum --check sre-backup-*.sha256
```

Check the source mount, destination capacity, role-managed marker, lock owner, timer state, last attempt, and last verified success separately. A green process exit without a restore test is not complete backup assurance.

## Recover

Repair the causal mount, capacity, permissions, schedule, or script issue; start `sre-backup.service`; verify checksum and freshness; then copy through the approved off-host/immutable path. Perform a restore exercise against disposable storage before closing a backup incident.

## Disposable drill

`06-stale-backup.sh` creates a valid archive, rewrites only the lab metric to a timestamp two days old, requires the freshness check to fail, then creates and verifies a new archive. Production metrics must never be edited this way.
