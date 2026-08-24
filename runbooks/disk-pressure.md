# Runbook: Disk or Inode Pressure

## Signals

High filesystem utilization, inode exhaustion, write failures, database errors, container eviction, or a backup that cannot create its temporary archive.

## Diagnose

```bash
df -hPT
df -iP
du -x -d 1 /var 2>/dev/null | sort -n
lsof +L1
journalctl --disk-usage
```

Separate byte exhaustion, inode exhaustion, deleted-but-open files, runaway logs, expected data growth, and an unhealthy mount. Confirm the affected filesystem; a full `/var` is not repaired by deleting unrelated files from `/home`.

## Recover

- stop or rate-limit the writer if growth is ongoing;
- rotate or vacuum logs according to retention policy;
- move or expire data only when ownership and recovery requirements are known;
- extend the filesystem through the approved storage path;
- restart a process holding a large deleted file only after evaluating impact;
- rerun the failed backup and verify its checksum and freshness metric.

Do not reflexively delete the largest path. Preserve evidence and confirm whether it is authoritative data.

## Disposable drill

`01-disk-pressure.sh` fills a dedicated 16 MiB tmpfs above 90%, captures bounded diagnostics, unmounts it, and verifies removal. It never fills the container root filesystem.
