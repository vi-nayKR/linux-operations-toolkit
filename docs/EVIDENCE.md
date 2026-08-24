# Evidence Contract

The CI harness writes runtime files under `evidence/runtime/` and uploads them for seven days. Runtime output is ignored by Git because it changes with container IDs, ports, timestamps, package mirrors, and runner kernels.

Every accepted run must contain:

- first and second Ansible recaps for both nodes;
- two second-run recap lines with `changed=0 unreachable=0 failed=0`;
- per-node active/enabled service checks;
- an operator-key login plus non-interactive sudo check;
- checksum and freshness verification for a newly created archive;
- an exporter sample containing `sre_backup_last_success_unixtime`;
- six drill logs, each with a detected symptom and a recovered state;
- diagnostics from the disk and failed-service drills.

The public workflow URL binds the evidence to a commit SHA and the pinned container manifests. A curated record belongs in `evidence/README.md` only after the workflow is green.

Do not upload private host diagnostics, live inventory, SSH keys, archive payloads, or raw production logs as portfolio evidence.
