````md
# TD4 — TEST_CARDS.md
TLS Audit and Hardening with Nginx

This file documents the main verification tests performed during TD4.
Each test card describes the security claim, the preconditions, the exact
test procedure, the expected result, the observed result, and the evidence
file associated with the test.

---

## Test Card TD4-T01 — Baseline configuration accepts legacy TLS 1.0

### Claim
The initial TLS configuration is intentionally weak and accepts TLS 1.0.

### Security relevance
Support for TLS 1.0 is considered deprecated and weakens the security posture
of the exposed web service. Demonstrating that TLS 1.0 is accepted in the
baseline state is necessary to justify the hardening phase.

### Preconditions
- `srv-web` is running nginx with the weak baseline TLS configuration
- The server listens on `10.10.20.10:8443`
- The baseline configuration includes:
  - `ssl_protocols TLSv1 TLSv1.1 TLSv1.2;`
  - weak/legacy cipher support
- The client can reach `10.10.20.10:8443`

### Test procedure
From `client`, run:

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1 </dev/null
````

Optional complementary command:

```bash
./testssl.sh --fast --warnings batch https://10.10.20.10:8443
```

### Expected result

* The TLS 1.0 handshake succeeds
* OpenSSL reports `Protocol : TLSv1`
* The scanner reports that TLS 1.0 is offered/supported

### Observed result

* TLS 1.0 was accepted in the baseline state
* The handshake succeeded before hardening

### Pass criteria

The test passes if TLS 1.0 is accepted before hardening.

### Evidence

* `evidence/before/openssl.txt`
* `evidence/before/tls_scan.txt`

### Interpretation

This confirms that the baseline posture is intentionally weak and that
hardening is justified.

---

## Test Card TD4-T02 — Baseline configuration accepts legacy TLS 1.1

### Claim

The initial TLS configuration accepts TLS 1.1.

### Security relevance

TLS 1.1 is deprecated and should not remain enabled on a modern web service.

### Preconditions

* Baseline configuration deployed on `srv-web`
* Client connectivity to `10.10.20.10:8443` is functional

### Test procedure

From `client`, run either:

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1_1 </dev/null
```

or confirm through the scanner:

```bash
./testssl.sh --fast --warnings batch https://10.10.20.10:8443
```

### Expected result

* The TLS 1.1 handshake succeeds
* The scanner reports that TLS 1.1 is offered

### Observed result

* TLS 1.1 was accepted in the baseline state

### Pass criteria

The test passes if TLS 1.1 is accepted before hardening.

### Evidence

* `evidence/before/tls_scan.txt`

### Interpretation

This result further confirms that the initial TLS posture is outdated.

---

## Test Card TD4-T03 — Baseline configuration exposes weak cipher policy

### Claim

The baseline TLS configuration allows weaker cipher suites than desired.

### Security relevance

Weak cipher policy can expose the service to cryptographic downgrade risk or
reduced confidentiality guarantees.

### Preconditions

* Weak baseline TLS configuration is active
* Scanner is available on `client`

### Test procedure

From `client`, run:

```bash
./testssl.sh --fast --warnings batch https://10.10.20.10:8443
```

Optional complementary test:

```bash
curl -vk https://10.10.20.10:8443
```

### Expected result

* The scan reports weak/legacy cipher families, typically including CBC-based suites
* The cipher policy is broader than the hardened target profile

### Observed result

* Weak ciphers were visible in the baseline configuration

### Pass criteria

The test passes if the scan shows a non-hardened cipher policy before changes.

### Evidence

* `evidence/before/tls_scan.txt`
* `evidence/before/curl_vk.txt`

### Interpretation

This confirms that the baseline configuration is not aligned with a modern TLS profile.

---

## Test Card TD4-T04 — Baseline certificate matches documented lab trust model

### Claim

The baseline certificate is self-signed and matches the expected lab trust model.

### Security relevance

The certificate is not trusted publicly, but this is acceptable in the lab as long
as the trust model is documented and the certificate properties are consistent.

### Preconditions

* Self-signed certificate generated on `srv-web`
* Certificate file available on server

### Test procedure

On `srv-web`, run:

```bash
openssl x509 -in /etc/nginx/certs/server.crt -noout -text
```

Optional remote inspection from `client`:

```bash
openssl s_client -connect 10.10.20.10:8443 -servername td4.local </dev/null
```

### Expected result

* Certificate subject contains `CN=td4.local`
* Certificate validity is short (lab certificate)
* Key size and algorithm are visible
* Certificate is self-signed or otherwise non-publicly trusted

### Observed result

* The certificate subject and validity were consistent with the lab setup
* The certificate was self-signed as expected

### Pass criteria

The test passes if the certificate properties match the documented lab design.

### Evidence

* `config/cert_info_before.txt`
* `evidence/before/openssl.txt`

### Interpretation

This validates the certificate assumptions and ensures the TLS tests are grounded
in a documented trust model.

---

## Test Card TD4-T05 — Hardened configuration rejects TLS 1.0

### Claim

After hardening, the web server rejects TLS 1.0.

### Security relevance

Rejecting TLS 1.0 is a key hardening requirement and demonstrates that legacy
protocols were successfully disabled.

### Preconditions

* Hardened Nginx configuration deployed
* The server configuration includes:

  * `ssl_protocols TLSv1.2 TLSv1.3;`
* Nginx test succeeded and the service was reloaded
* Client connectivity is functional

### Test procedure

From `client`, run:

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1 </dev/null
```

Optional scanner verification:

```bash
./testssl.sh --fast --warnings batch https://10.10.20.10:8443
```

### Expected result

* The handshake fails
* OpenSSL reports a protocol version alert or no negotiated cipher
* The scanner reports TLS 1.0 as not offered

### Observed result

* TLS 1.0 handshake failed after hardening
* OpenSSL displayed a protocol version rejection
* No cipher was negotiated

### Pass criteria

The test passes if TLS 1.0 is rejected after hardening.

### Evidence

* `evidence/after/openssl.txt`
* `evidence/after/tls_scan.txt`

### Interpretation

This confirms that legacy protocol support was successfully removed.

---

## Test Card TD4-T06 — Hardened configuration rejects TLS 1.1

### Claim

After hardening, the web server rejects TLS 1.1.

### Security relevance

Disabling TLS 1.1 is part of a defensible modern TLS posture.

### Preconditions

* Hardened configuration loaded
* Nginx reload successful

### Test procedure

From `client`, run:

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1_1 </dev/null
```

Optional scanner verification:

```bash
./testssl.sh --fast --warnings batch https://10.10.20.10:8443
```

### Expected result

* The handshake fails
* The scanner reports TLS 1.1 as not offered

### Observed result

* TLS 1.1 was no longer accepted after hardening

### Pass criteria

The test passes if TLS 1.1 is rejected.

### Evidence

* `evidence/after/tls_scan.txt`

### Interpretation

This demonstrates correct enforcement of the minimum protocol version.

---

## Test Card TD4-T07 — Hardened configuration accepts TLS 1.2

### Claim

After hardening, TLS 1.2 remains supported and functional.

### Security relevance

Hardening must not break secure client access. The service must remain available
with a modern supported protocol.

### Preconditions

* Hardened configuration loaded
* Service reachable on `10.10.20.10:8443`

### Test procedure

From `client`, run:

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1_2 </dev/null
```

Optional complementary request:

```bash
curl -vk https://10.10.20.10:8443
```

### Expected result

* The handshake succeeds
* OpenSSL reports `Protocol : TLSv1.2`
* A secure cipher is negotiated
* `curl` successfully receives the HTTPS response

### Observed result

* TLS 1.2 was accepted after hardening
* Secure connection remained functional

### Pass criteria

The test passes if TLS 1.2 is accepted and the service remains reachable.

### Evidence

* `evidence/after/openssl.txt`
* `evidence/after/curl_vk.txt`

### Interpretation

This confirms that the hardening strengthened the service without breaking
legitimate secure access.

---

## Test Card TD4-T08 — Hardened configuration exposes a stronger cipher policy

### Claim

After hardening, weak cipher suites are removed and the server follows a stronger
cipher policy.

### Security relevance

Cipher policy is a central part of TLS hardening. The service should prefer modern,
strong suites supporting forward secrecy and AEAD.

### Preconditions

* Hardened TLS configuration deployed
* Scanner available

### Test procedure

From `client`, run:

```bash
./testssl.sh --fast --warnings batch https://10.10.20.10:8443
```

### Expected result

* Weak CBC-based suites are no longer present
* The negotiated policy is more restrictive
* The remaining suites are aligned with the hardened configuration

### Observed result

* Weak ciphers were removed from the hardened profile

### Pass criteria

The test passes if the scanner no longer reports weak legacy cipher support.

### Evidence

* `evidence/after/tls_scan.txt`

### Interpretation

This confirms that the hardening goals were applied at the cipher level.

---

## Test Card TD4-T09 — HSTS header is enabled after hardening

### Claim

The hardened configuration returns the `Strict-Transport-Security` header.

### Security relevance

HSTS helps enforce HTTPS usage and reduces downgrade opportunities in real browser
contexts.

### Preconditions

* Hardened configuration includes:

  * `add_header Strict-Transport-Security "max-age=300" always;`
* Service reachable over HTTPS

### Test procedure

From `client`, run:

```bash
curl -vk https://10.10.20.10:8443 2>&1
```

### Expected result

The response headers include a line similar to:

```text
Strict-Transport-Security: max-age=300
```

### Observed result

* HSTS header present in the hardened configuration response

### Pass criteria

The test passes if the HSTS header is visible in the HTTPS response.

### Evidence

* `evidence/after/curl_vk.txt`

### Interpretation

This confirms that an additional transport security control was enabled.

---

## Test Card TD4-T10 — Rate limiting triggers under burst traffic

### Claim

The reverse proxy limits excessive request bursts and returns rejection responses
when the configured threshold is exceeded.

### Security relevance

Rate limiting provides basic availability protection against burst or abusive
traffic patterns.

### Preconditions

* `limit_req_zone` defined in `http {}`
* `/api` location configured with:

  * `limit_req zone=api_limit burst=5 nodelay;`
* Nginx configuration reloaded successfully

### Test procedure

From `client`, run:

```bash
for i in $(seq 1 30)
do
  curl -sk -o /dev/null -w "%{http_code}\n" https://10.10.20.10:8443/api
done
```

### Expected result

* Initial requests return HTTP 200
* Excess burst requests return HTTP 503
* The transition appears within the test output

### Observed result

* The burst test produced a mix of 200 and 503 responses
* Nginx access logs recorded the requests

### Pass criteria

The test passes if excessive requests are rejected during the burst.

### Evidence

* `evidence/after/rate_limit_test.txt`
* `evidence/after/nginx_access_log_rate.txt`

### Interpretation

This confirms that the configured rate limiting mechanism is active and effective.

---

## Test Card TD4-T11 — Normal API request remains functional with rate limiting enabled

### Claim

The rate limiting control does not block normal API usage.

### Security relevance

A security control must not break ordinary service operation. A correct control
distinguishes between legitimate and abusive traffic.

### Preconditions

* Rate limiting active on `/api`
* No burst load currently generated

### Test procedure

From `client`, run:

```bash
curl -sk https://10.10.20.10:8443/api
```

### Expected result

* HTTP 200 response
* Body contains `API response`

### Observed result

* Normal request succeeded with HTTP 200

### Pass criteria

The test passes if a standard request to `/api` is accepted.

### Evidence

* `evidence/after/rate_limit_test.txt` or separate local output/log observation
* `evidence/after/nginx_access_log_rate.txt`

### Interpretation

This confirms that the availability control is not overly restrictive under
normal usage conditions.

---

## Test Card TD4-T12 — Request filtering blocks suspicious User-Agent

### Claim

Requests with a suspicious User-Agent such as `sqlmap` are blocked by Nginx.

### Security relevance

This demonstrates a simple edge enforcement control capable of identifying and
blocking obviously suspicious request patterns.

### Preconditions

* Filtering rule present in the `server {}` block:

  * `if ($http_user_agent ~* "sqlmap|nikto|dirbuster") { return 403; }`
* Nginx configuration successfully reloaded

### Test procedure

From `client`, run:

```bash
curl -sk -A "sqlmap" -o /dev/null -w "%{http_code}\n" https://10.10.20.10:8443/
```

### Expected result

* The request returns HTTP 403

### Observed result

* The request with User-Agent `sqlmap` was blocked with HTTP 403

### Pass criteria

The test passes if the suspicious User-Agent is rejected.

### Evidence

* `evidence/after/filter_test.txt`
* `evidence/after/nginx_access_log_filter.txt`

### Interpretation

This validates the request filtering rule and demonstrates basic edge protection.

---

## Test Card TD4-T13 — Normal request is not blocked by the filtering rule

### Claim

The request filtering logic does not block a normal request.

### Security relevance

Filtering rules must not introduce false positives for benign requests.

### Preconditions

* Filtering rule active
* Service reachable

### Test procedure

From `client`, run:

```bash
curl -sk -o /dev/null -w "%{http_code}\n" https://10.10.20.10:8443/
```

### Expected result

* HTTP 200 returned
* Service remains available for normal clients

### Observed result

* A normal request returned HTTP 200

### Pass criteria

The test passes if a standard request succeeds while the malicious one is blocked.

### Evidence

* `evidence/after/filter_test.txt`
* `evidence/after/nginx_access_log_filter.txt`

### Interpretation

This confirms the rule is selective and does not break nominal traffic.

---

## Test Card TD4-T14 — Log visibility supports triage

### Claim

Nginx access logs provide sufficient visibility to support basic event triage.

### Security relevance

Security controls are more useful when their effects are observable and analyzable.

### Preconditions

* Nginx access logging enabled
* At least one relevant request has been generated (200, 403, or 503)

### Test procedure

On `srv-web`, run:

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

Optionally observe logs live:

```bash
sudo tail -f /var/log/nginx/access.log
```

Generate a test request from `client`, for example:

```bash
curl -sk -A "sqlmap" https://10.10.20.10:8443/
```

### Expected result

A log line appears containing:

* source IP
* timestamp
* request path
* HTTP status code
* user-agent

### Observed result

* Log entries provided the IP, path, status code, and User-Agent needed for triage

### Pass criteria

The test passes if the log lines contain enough fields to analyze the event.

### Evidence

* `evidence/after/nginx_access_log_rate.txt`
* `evidence/after/nginx_access_log_filter.txt`

### Interpretation

This confirms that the system provides usable observability for operational analysis.

---

## Test Card TD4-T15 — Before/after audit is reproducible

### Claim

The TLS audit can be reproduced with the same commands before and after hardening.

### Security relevance

A defensible security assessment requires repeatable procedures and comparable results.

### Preconditions

* Baseline evidence collected before modifications
* Hardened configuration applied
* Same test tools and endpoints used

### Test procedure

Run the same core commands in both states:

```bash
openssl s_client -connect 10.10.20.10:8443 </dev/null
curl -vk https://10.10.20.10:8443
./testssl.sh --fast --warnings batch https://10.10.20.10:8443
```

### Expected result

* Before: weaker posture observed
* After: strengthened posture observed
* The difference is attributable to configuration changes, not to a change in method

### Observed result

* The same methodology produced different before/after results consistent with the applied hardening

### Pass criteria

The test passes if the before/after comparison is based on identical test logic and yields coherent differences.

### Evidence

* `evidence/before/openssl.txt`
* `evidence/before/curl_vk.txt`
* `evidence/before/tls_scan.txt`
* `evidence/after/openssl.txt`
* `evidence/after/curl_vk.txt`
* `evidence/after/tls_scan.txt`

### Interpretation

This confirms that the hardening results are measurable, reproducible, and attributable.

---

## Final Validation Summary

| Test ID | Claim Summary                              | Expected Outcome        |
| ------- | ------------------------------------------ | ----------------------- |
| TD4-T01 | Baseline accepts TLS 1.0                   | Accepted                |
| TD4-T02 | Baseline accepts TLS 1.1                   | Accepted                |
| TD4-T03 | Baseline exposes weak ciphers              | Weak policy observed    |
| TD4-T04 | Baseline certificate matches lab model     | Consistent              |
| TD4-T05 | Hardened config rejects TLS 1.0            | Rejected                |
| TD4-T06 | Hardened config rejects TLS 1.1            | Rejected                |
| TD4-T07 | Hardened config accepts TLS 1.2            | Accepted                |
| TD4-T08 | Hardened config removes weak cipher policy | Stronger policy         |
| TD4-T09 | HSTS enabled after hardening               | Header present          |
| TD4-T10 | Rate limiting triggers on burst            | 503 observed            |
| TD4-T11 | Normal API traffic still works             | 200 observed            |
| TD4-T12 | Suspicious User-Agent is blocked           | 403 observed            |
| TD4-T13 | Normal request is not blocked              | 200 observed            |
| TD4-T14 | Logs support triage                        | Relevant fields present |
| TD4-T15 | Audit is reproducible                      | Before/after comparable |

```

