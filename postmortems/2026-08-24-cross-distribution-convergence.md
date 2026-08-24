# Cross-Distribution Convergence Exposed False Portability Assumptions

**Date:** 2026-08-24 UTC  
**Status:** Resolved in the disposable acceptance environment  
**Impact:** No users or live hosts were affected. Public CI could not substantiate the repository's Debian/Arch portability and recovery claims until the final corrections landed.

## Summary

The first full two-distribution acceptance attempts repeatedly failed after static validation had passed. The failures were useful: they exposed assumptions about systemd unit semantics, Arch package metadata, OpenSSH paths and output casing, minimal userspace tools, and the memory drill's allocation behavior. Each failed workflow retained diagnostics, and the acceptance gate remained closed until one public run proved the complete chain.

Run [`32766027669`](https://github.com/vi-nayKR/linux-operations-toolkit/actions/runs/32766027669) at commit `3071d23` is the first accepted record: Debian and Arch both converge with a strict second-run `changed=0`, both verify fresh checksummed backups and service policy, and all six bounded drills detect and recover their intended faults.

## Detection

GitHub Actions detected every issue because the integration job provisions real systemd containers, connects over SSH, runs Ansible twice, checks live effective policy, starts and verifies a backup, and finally executes the fault suite. The job uploads its partial evidence even when an invariant fails.

## Timeline

- Earlier runs established a usable cgroup namespace and a purpose-built non-root SSH bootstrap account instead of relying on root login.
- Runs `32763257230` through `32764928023` exposed differing Debian/Arch time-sync and nftables states, non-idempotent pacman metadata refresh, and distribution-specific `sshd` paths and output capitalization.
- Run `32765226310` passed strict convergence and host-policy checks, then exposed a dependency on the optional `hostname` userspace command in the backup script.
- Run `32765599895` passed convergence, service policy and verified backups on both nodes, then showed that a zero-filled Python allocation did not deterministically trigger the intended OOM.
- Commit `3071d23` made the drill dirty each page under `MemoryMax=32M` and `MemorySwapMax=0`.
- Run `32766027669` completed at 19:06:42 UTC with every acceptance invariant green.

## Root causes

1. The first implementation treated identically named capabilities as identical service states. Debian's and Arch's systemd units legitimately differ between long-running and successful oneshot behavior.
2. Package metadata refresh was counted as managed-state drift even though refreshing a volatile pacman cache is not a configuration change.
3. Verification assumed one OpenSSH binary path and lowercase effective configuration. Both assumptions were narrower than the supported distributions.
4. The backup script depended on `hostname`, which is not guaranteed in a deliberately minimal system image; the kernel-provided `uname -n` is sufficient.
5. The memory drill allocated zero-filled pages. Linux can satisfy those pages lazily, so source-level allocation size was not proof of cgroup memory pressure.

## Corrective actions completed

- Model distribution-specific systemd semantics and assert the live nftables policy rather than forcing one `is-active` answer.
- Treat package-cache refresh as an observed operation, not managed-state drift, while retaining package-install changes in the idempotence gate.
- Discover `sshd` from the supported system paths and compare its effective security values case-insensitively.
- Remove the optional `hostname` dependency and print bounded service status/journal evidence if backup startup fails.
- Touch every allocated memory page and disable cgroup swap for the bounded OOM exercise.
- Keep partial evidence upload enabled on failure so the next diagnosis starts from observed state.

## What went well

- No workaround weakened the `changed=0` acceptance rule.
- The tests ran against both supported families rather than mocking package and service behavior.
- Every fault remained inside uniquely named, labelled disposable containers guarded by an explicit acknowledgement.
- The final artifact independently demonstrates the claimed state instead of relying on the workflow's green badge alone.

## Remaining limits

This exercise does not test a kernel upgrade, reboot persistence on physical machines, an off-host restore, network partition between real nodes, ARM64, fleet scale or a production incident. Those remain explicit limitations rather than inferred successes.
