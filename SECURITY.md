# Security Policy

## Reporting a Vulnerability

If you find a security issue in `mojo-kafka` — particularly anything that could allow memory corruption, OOB reads/writes via the FFI layer, or credential leakage through misconfigured TLS / SASL — please **do not** open a public issue.

Instead, use GitHub's private vulnerability reporting:

1. Go to https://github.com/dvirarad/mojo-kafka/security/advisories/new
2. Describe the issue with a minimal repro.
3. Expect an acknowledgment within 72 hours.

For non-security bugs, regular issues are the right place.

## Scope

In scope:

- Anything inside `src/kafka/` that talks to `librdkafka`.
- Examples that mishandle untrusted input.

Out of scope:

- Vulnerabilities in `librdkafka` itself — report those upstream at https://github.com/confluentinc/librdkafka.
- Vulnerabilities in user code that happens to import `mojo-kafka`.
