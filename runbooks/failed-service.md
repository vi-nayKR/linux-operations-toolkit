# Runbook: Failed systemd Service

## Signals

`systemctl --failed`, missing listener, failed dependency, restart loop, watchdog alert, or a downstream availability symptom.

## Diagnose

```bash
systemctl status SERVICE --no-pager
systemctl show SERVICE -p Result -p ExecMainCode -p ExecMainStatus -p NRestarts
systemctl list-dependencies SERVICE
systemd-analyze verify /etc/systemd/system/SERVICE
journalctl -u SERVICE --since '-15 min' --no-pager
```

Review journals privately; applications can log tokens, request data, connection strings, or customer identifiers. The default diagnostics bundle deliberately does not collect them.

## Recover

Correct the causal configuration, dependency, permissions, capacity, binary, or credential path. Run the service's validation command before restart. After recovery, verify the user-facing signal and reset the failed state only when it no longer hides an unresolved failure.

## Disposable drill

`03-failed-service.sh` installs a oneshot unit under `/run`, verifies its expected failed state, captures metadata-only diagnostics, removes the unit, reloads systemd, and confirms it is gone.
