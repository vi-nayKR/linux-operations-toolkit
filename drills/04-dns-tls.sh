#!/usr/bin/env bash
set -Eeuo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=drills/lib.sh
source "$script_directory/lib.sh"
require_disposable_drill_host

drill_name="dns-tls"
sandbox=/var/lib/sre-drills/dns-tls
port=19443
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -f -- "$sandbox/cert.pem" "$sandbox/key.pem" "$sandbox/server.log"
  rmdir "$sandbox" 2>/dev/null || true
}
trap cleanup EXIT

install -d -m 0700 "$sandbox"
if getent hosts sre-drill-does-not-exist.invalid. >/dev/null 2>&1; then
  record_drill "$drill_name" "failed reserved_domain_resolved=true"
  exit 1
fi
record_drill "$drill_name" "detected dns_name_not_found=true"

if ss -lnt | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
  record_drill "$drill_name" "failed local_port_in_use=$port"
  exit 1
fi
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -sha256 \
  -subj '/CN=127.0.0.1' -addext 'subjectAltName=IP:127.0.0.1' \
  -keyout "$sandbox/key.pem" -out "$sandbox/cert.pem" >/dev/null 2>&1
openssl s_server -quiet -www -accept "127.0.0.1:$port" \
  -key "$sandbox/key.pem" -cert "$sandbox/cert.pem" >"$sandbox/server.log" 2>&1 &
server_pid=$!

for _ in $(seq 1 20); do
  if curl --silent --show-error --max-time 1 --insecure "https://127.0.0.1:$port/" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
if curl --silent --show-error --max-time 2 "https://127.0.0.1:$port/" >/dev/null 2>&1; then
  record_drill "$drill_name" "failed untrusted_certificate_accepted=true"
  exit 1
fi
record_drill "$drill_name" "detected tls_untrusted_issuer=true"
curl --fail --silent --show-error --max-time 2 --cacert "$sandbox/cert.pem" \
  "https://127.0.0.1:$port/" >/dev/null
record_drill "$drill_name" "recovered explicit_ca_verification=true"
