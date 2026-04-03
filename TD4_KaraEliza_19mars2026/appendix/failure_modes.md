
# TD4 — Failure Modes Encountered

## 1. Introduction

During TD4 (TLS Audit and Hardening), several issues were encountered related to service configuration, TLS behavior, and security control validation.

This section focuses on the most relevant failure modes that directly impacted the TLS deployment, reverse proxy hardening, and security verification process.

---

## 2. Failure Modes

---

### FM-01 — TLS Configuration Changes Not Applied

#### Description

TLS hardening changes appeared ineffective after modification.

#### Symptoms

* Deprecated protocols (e.g., TLS 1.0) were still accepted
* No visible difference between before/after scans

#### Root Cause

* Nginx configuration was modified but not reloaded
* In some cases, the wrong configuration file was edited

#### Resolution

```bash
sudo systemctl reload nginx
sudo nginx -T
```

#### Lesson Learned

Configuration changes must always be explicitly applied and verified.
Assuming a configuration is active without validation leads to incorrect conclusions.

---

### FM-02 — Incorrect TLS Cipher Configuration

#### Description

TLS cipher suite configuration was invalid or ineffective.

#### Symptoms

* Nginx accepted weak or unexpected ciphers
* Hardening did not produce expected improvements in scan results

#### Root Cause

* Incorrect syntax in `ssl_ciphers` directive
* Misunderstanding of OpenSSL cipher string format

#### Resolution

Replaced invalid configuration with a valid modern cipher set:

```nginx
ssl_ciphers 'ECDHE+AESGCM:ECDHE+CHACHA20';
```

#### Lesson Learned

TLS configuration requires precise syntax.
Misconfigured cipher strings can silently weaken security posture.

---

### FM-03 — TLS Service Not Reachable on Expected Port

#### Description

The HTTPS service was not accessible on port `8443`.

#### Symptoms

* `curl: connection refused`
* No TLS handshake possible

#### Root Cause

* Nginx not listening on the expected port
* Incorrect `listen` directive

#### Resolution

Verified configuration:

```nginx
listen 8443 ssl;
```

Checked active services:

```bash
sudo ss -tulpn | grep nginx
```

#### Lesson Learned

Service availability must be validated before performing any security assessment.

---

### FM-04 — Misinterpretation of TLS Test Results

#### Description

TLS test outputs were incorrectly interpreted as errors.

#### Symptoms

* Belief that TLS was broken after hardening
* Confusion when seeing `handshake failure`

#### Root Cause

Expected secure behavior (protocol rejection) was misunderstood.

#### Resolution

Identified correct interpretation:

* `handshake failure` = insecure protocol rejected
* `Cipher : NONE` = protocol not accepted

#### Lesson Learned

Security tools must be interpreted correctly.
A failure in negotiation can indicate **stronger security**, not a malfunction.

---

### FM-05 — Rate Limiting Not Triggering

#### Description

Burst traffic did not trigger any limitation.

#### Symptoms

* All requests returned HTTP 200
* No 503 responses observed

#### Root Cause

* Missing `limit_req_zone` in `http {}` block
* Incorrect endpoint used for testing

#### Resolution

```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
```

Ensured requests targeted `/api`.

#### Lesson Learned

Rate limiting requires both global definition and correct application scope.

---

### FM-06 — Request Filtering Not Applied

#### Description

Malicious requests were not blocked.

#### Symptoms

* Requests with `sqlmap` or `nikto` User-Agent returned HTTP 200

#### Root Cause

* Filtering rule not placed in correct `server {}` block
* Nginx configuration not reloaded

#### Resolution

```nginx
if ($http_user_agent ~* "sqlmap|nikto|dirbuster") {
    return 403;
}
```

Reloaded Nginx after modification.

#### Lesson Learned

Security controls must be placed at the correct configuration level and validated after deployment.

---

### FM-07 — Lack of Real-Time Observability

#### Description

Difficulty correlating test actions with server behavior.

#### Symptoms

* No immediate visibility of request handling
* Hard to validate filtering and rate limiting

#### Root Cause

Logs were not monitored during testing.

#### Resolution

```bash
sudo tail -f /var/log/nginx/access.log
```

#### Lesson Learned

Real-time log monitoring is essential for validating security controls and performing effective troubleshooting.

---

## 3. Conclusion

The failure modes encountered during TD4 highlight key challenges in:

* TLS configuration correctness
* Service exposure and validation
* Reverse proxy hardening
* Security control verification
* Log-based observability

Addressing these issues required a structured approach based on:

* incremental configuration changes
* systematic validation (before/after testing)
* correct interpretation of tool outputs
* continuous monitoring of logs

These practices are fundamental to real-world TLS deployment, web service hardening, and SOC-level analysis.

