# Runbook: Database Lock Contention

## Signals

Lock-wait timeout, `database is locked`, rising transaction duration, blocked sessions, deadlock errors, connection-pool saturation, or request latency isolated to writes.

## Diagnose

Identify the engine first. Inspect blocking and blocked sessions, transaction start time, lock type, query fingerprint, application owner, and rollback cost using engine-native views. Correlate with deploys, migrations, maintenance, and batch jobs.

Do not terminate a session merely because it is old. A blocker can own a critical transaction whose rollback is more expensive than waiting.

## Recover

- stop the workload creating new contention;
- let a bounded transaction finish when that is the safer path;
- cancel the lowest-risk query before terminating a session;
- roll back a causal deploy or migration;
- verify pool recovery, transaction latency, replication, and application errors;
- add timeouts, indexing, transaction-scope reductions, or migration controls based on the cause.

## Disposable drill

`05-database-lock.sh` uses Python's local SQLite library. One process holds an exclusive transaction, a second writer must report `database is locked`, the holder is stopped, and a final write proves recovery. This is symptom practice, not PostgreSQL/MySQL operational evidence.
