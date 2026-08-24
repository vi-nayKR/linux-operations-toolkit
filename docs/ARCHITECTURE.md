# Architecture

## Control and data paths

Ansible is the control path. It reaches each node over SSH, selects an explicit Debian or Arch variable map, and converges three roles. The host remains usable without the control node after convergence.

```text
Ansible control node
        |
        | SSH + sudo
        v
  Linux node
   |-- baseline: identity, SSH, packages, time sync, nftables
   |-- metrics: 127.0.0.1:9101 reads bounded *.prom files
   |-- backup.timer -> backup.service -> archive + checksum
   `-- diagnostics: operator-invoked metadata bundle
```

The integration test uses SSH rather than a Docker connection plug-in. That tests host keys, the SSH service, Python discovery, privilege escalation, firewall continuity, and the same transport used by a small real fleet.

## Backup transaction

1. Validate real, non-root source/destination paths and a role-managed destination marker.
2. Acquire a non-blocking `flock` in the destination.
3. Create the archive as a temporary file in the destination filesystem.
4. List the archive to reject an unreadable stream.
5. Atomically rename it to the final name.
6. Write a SHA-256 sidecar and immediately verify it.
7. Atomically update last-success metrics; update last-run status on every exit.
8. Prune only toolkit-named archives beyond the bounded retention count.

The temporary and final files share a filesystem, so rename is atomic. This protects readers from partial local archives. It does not make a local backup durable against host, disk, theft, ransomware, or site loss.

## Metrics

The exporter reads only regular, non-symlink `*.prom` files smaller than 1 MiB from one configured directory. It serves `/metrics` and `/healthz`; other paths return 404. It has no discovery, remote write, shell execution, or configuration endpoint.

The default loopback binding avoids adding an unauthenticated network listener. A real collector can use a local agent, authenticated reverse proxy, overlay network policy, or SSH tunnel.

## Fault containment

Drills require `SRE_DRILL_ACK=disposable` and container detection. Their paths and unit names are fixed under `/var/lib/sre-drills`, `/run/systemd/system/sre-drill-*`, or one local high port. The memory drill has a cgroup cap and runtime cap; the disk drill mounts a 16 MiB tmpfs rather than filling the root filesystem.
