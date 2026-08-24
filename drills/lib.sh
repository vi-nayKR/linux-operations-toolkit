#!/usr/bin/env bash

require_disposable_drill_host() {
  if [[ "${SRE_DRILL_ACK:-}" != "disposable" ]]; then
    printf 'refusing fault injection: set SRE_DRILL_ACK=disposable on a disposable node\n' >&2
    exit 64
  fi
  if [[ ! -f /run/.containerenv && ! -f /.dockerenv && "${SRE_DRILL_ALLOW_VM:-}" != "1" ]]; then
    printf 'refusing fault injection outside a container; see the runbook for VM opt-in\n' >&2
    exit 64
  fi
  install -d -m 0700 /var/lib/sre-drills/evidence
}

record_drill() {
  local drill_name="$1"
  shift
  printf '%s drill=%s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$drill_name" "$*" |
    tee -a "/var/lib/sre-drills/evidence/${drill_name}.log"
}
