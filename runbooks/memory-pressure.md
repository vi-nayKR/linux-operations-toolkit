# Runbook: Memory Pressure and OOM

## Signals

Increasing memory PSI, swap activity, latency, reclaim, container or service restarts, exit status 137/SIGKILL, or kernel/systemd OOM records.

## Diagnose

```bash
free -h
cat /proc/pressure/memory
systemd-cgtop --depth=3
systemctl show SERVICE -p MemoryCurrent -p MemoryPeak -p MemoryMax -p OOMPolicy
journalctl -k --since '-15 min' | grep -i -E 'oom|out of memory|killed process'
```

Distinguish application growth, page cache, kernel memory, cgroup enforcement, host exhaustion, and an intentionally low limit. A killed process is a symptom; the allocation owner and workload change are the cause to investigate.

## Recover

- stop load generation or shed non-critical work;
- restore the last known-good release if growth followed a change;
- restart only after capacity exists and a recurrence guard is in place;
- adjust limits and requests from measured working sets, not merely to silence OOM;
- capture a profile or heap evidence when safe.

## Disposable drill

`02-memory-pressure.sh` starts a transient unit with `MemoryMax=32M` and `RuntimeMaxSec=20`. It verifies an OOM result or SIGKILL, then resets the failed unit.
