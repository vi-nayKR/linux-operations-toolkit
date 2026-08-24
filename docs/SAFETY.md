# Safety Model

## Before a real convergence

- preserve an independent console or second SSH session;
- confirm the management source will remain allowed on TCP 22;
- inspect `nft -c -f` output and the rendered rule set;
- verify at least one public key before disabling password authentication;
- decide whether operators receive password-backed sudo or the explicitly enabled `baseline_passwordless_sudo` policy;
- put password hashes and live inventory in Ansible Vault or an external secret system;
- confirm backup source, destination, capacity, ownership, restore procedure, and off-host copy;
- run `--check --diff` on one canary before a fleet-wide serial rollout.

The baseline keeps root public-key SSH available with `PermitRootLogin prohibit-password` to avoid an automatic lockout during initial adoption. A stricter environment should prove the operator path and then override this with a separately reviewed policy.

`baseline_manage_sshd` and `baseline_manage_firewall` both default to `false`. CI turns them on against disposable nodes. A real inventory must opt in after the current SSH daemon includes and firewall ownership model are understood; the nftables template intentionally owns and flushes the ruleset when enabled.

## Drill guardrails

Do not run `scripts/run-drills.sh` on production, on the two Medha workload nodes, or on the proposed Lenovo control node while it is providing monitoring or automation.

The integration harness runs privileged containers because systemd, cgroups, nftables, mounts, and OOM behavior cannot be validated in an ordinary unprivileged container. Privileged mode is a test-host risk boundary, not a deployment requirement for the roles.

To use a disposable VM instead of a container, require both acknowledgements:

```bash
SRE_DRILL_ACK=disposable SRE_DRILL_ALLOW_VM=1 ./scripts/run-drills.sh
```

Destroy or revert the VM after collecting evidence. The scripts perform recovery checks, but snapshot rollback is the final isolation boundary.

## Diagnostics and sharing

The collector intentionally omits high-risk sources. Even metadata can reveal hostnames, kernel versions, listening ports, mount names, and capacity. Review every output file before attaching it to an issue, interview packet, or public postmortem.
