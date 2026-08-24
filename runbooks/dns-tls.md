# Runbook: DNS or TLS Failure

## Signals

Name-not-found, resolver timeout, connection to an unexpected address, certificate expiry, hostname mismatch, unknown issuer, incomplete chain, or TLS negotiation failure.

## Diagnose

```bash
getent ahosts HOSTNAME
resolvectl query HOSTNAME
curl --verbose --connect-timeout 3 https://HOSTNAME/health
openssl s_client -connect HOSTNAME:443 -servername HOSTNAME -verify_return_error </dev/null
date --iso-8601=seconds
```

Test resolution and TLS as separate layers. Preserve SNI, verify system time, compare resolver answers, inspect the served chain, and avoid `curl -k` as a repair.

## Recover

Restore the correct record, resolver reachability, trust bundle, SNI/routing, or certificate chain through its owner. Validate from the affected network and through the actual application path. If rotating a certificate, prove both old and new clients across the overlap window.

## Disposable drill

`04-dns-tls.sh` verifies non-resolution of the reserved `.invalid` domain, starts a loopback TLS server with an ephemeral self-signed certificate, observes trust failure, and recovers by providing that certificate as the explicit CA. It does not alter system DNS or trust stores.
