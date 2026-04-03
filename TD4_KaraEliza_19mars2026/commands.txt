# TD4 — TLS Audit and Hardening Report

## 1. Introduction

This lab focuses on evaluating and improving the security of a TLS configuration deployed on a web server using Nginx. The objective is to demonstrate the ability to identify weaknesses in a baseline configuration, apply appropriate hardening measures, and validate the improvements through reproducible testing and evidence.

The approach follows a structured methodology:

1. Deploy a deliberately weak TLS configuration
2. Perform a baseline audit (before)
3. Apply hardening aligned with modern security practices
4. Perform a second audit (after)
5. Implement edge security controls
6. Analyze logs and perform basic triage

All claims made in this report are supported by evidence files.

---

## 2. Threat Model

### Asset

* Web service hosted on `srv-web` (10.10.20.10)

### Adversary

* On-path attacker in LAN/DMZ
* Remote scanning tools (e.g., automated vulnerability scanners)

### Threats

* Downgrade attacks to weak TLS versions (TLS 1.0 / 1.1)
* Negotiation of weak cipher suites (no forward secrecy)
* Exploitation of misconfigured edge behavior
* Abuse through high request rates (DoS-like patterns)
* Automated scanning using known tools (sqlmap, nikto)

### Security Goals

* Enforce modern TLS versions only
* Ensure strong cipher suites with forward secrecy
* Prevent basic abuse via rate limiting
* Detect and block simple malicious patterns
* Maintain observability via logs

---

## 3. Baseline TLS Configuration (Before)

The initial configuration was intentionally weak:

```nginx
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_ciphers HIGH:MEDIUM:!aNULL;
```

### Observed Weaknesses

| Item            | Finding       | Evidence                     |
| --------------- | ------------- | ---------------------------- |
| TLS 1.0         | Supported     | evidence/before/tls_scan.txt |
| TLS 1.1         | Supported     | evidence/before/tls_scan.txt |
| TLS 1.2         | Supported     | evidence/before/tls_scan.txt |
| Weak ciphers    | Present (CBC) | evidence/before/tls_scan.txt |
| Forward secrecy | Partial       | evidence/before/tls_scan.txt |
| Certificate     | Self-signed   | config/cert_info_before.txt  |
| HSTS            | Not enabled   | evidence/before/curl_vk.txt  |

### Risk Assessment

The presence of TLS 1.0 and TLS 1.1 exposes the system to known cryptographic weaknesses. Additionally, weak cipher suites may allow downgrade or cryptographic attacks. The absence of HSTS increases the risk of downgrade to HTTP in real-world scenarios.

---

## 4. TLS Hardening Strategy

The hardening strategy was defined based on modern best practices and NIST SP 800-52 Rev.2 recommendations.

### Target TLS Profile

* Minimum version: TLS 1.2
* Support TLS 1.3
* AEAD cipher suites only
* Enforce forward secrecy (ECDHE)
* Enable HSTS (short duration for lab)

### Hardened Configuration

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE+AESGCM:ECDHE+CHACHA20:!aNULL:!MD5:!RC4;
ssl_prefer_server_ciphers on;

add_header Strict-Transport-Security "max-age=300" always;
```

---

## 5. Post-Hardening TLS Configuration (After)

### Verification Tests

#### TLS 1.0 Test

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1
```

Result:

* Handshake failure
* No cipher negotiated

Interpretation: TLS 1.0 is correctly rejected.

#### TLS 1.2 Test

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1_2
```

Result:

* Successful handshake
* Strong cipher negotiated

---

### Before / After Comparison

| Item            | Before      | After          | Evidence              |
| --------------- | ----------- | -------------- | --------------------- |
| TLS 1.0         | Supported   | Rejected       | tls_scan before/after |
| TLS 1.1         | Supported   | Rejected       | tls_scan before/after |
| TLS 1.2         | Supported   | Supported      | tls_scan after        |
| TLS 1.3         | Not enabled | Enabled        | tls_scan after        |
| Weak ciphers    | Present     | Removed        | tls_scan after        |
| Forward secrecy | Partial     | Enforced       | openssl after         |
| HSTS            | Not present | Enabled (300s) | curl after            |

---

## 6. Edge Security Controls

### 6.1 Rate Limiting

#### Configuration

```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

location /api {
    limit_req zone=api_limit burst=5 nodelay;
    return 200 "API response\n";
}
```

#### Test

```bash
for i in $(seq 1 30)
do
curl -sk -o /dev/null -w "%{http_code}\n" https://10.10.20.10:8443/api
done
```

#### Result

* First requests: HTTP 200
* Subsequent requests: HTTP 503

#### Interpretation

The server correctly limits excessive traffic from a single client, demonstrating protection against burst traffic.

---

### 6.2 Request Filtering

#### Configuration

```nginx
if ($http_user_agent ~* "sqlmap|nikto|dirbuster") {
    return 403;
}
```

#### Test

```bash
curl -k -A "sqlmap" https://10.10.20.10:8443
```

#### Result

* Normal request: HTTP 200
* Malicious User-Agent: HTTP 403

#### Interpretation

The filtering rule successfully blocks requests associated with known scanning tools.

---

## 7. Log Analysis and Triage

### Log Example

```
10.10.10.10 - - [date] "GET / HTTP/1.1" 403 "-" "sqlmap"
```

### Analysis

* Source IP: 10.10.10.10
* Request path: `/`
* Status code: 403
* User-Agent: sqlmap

### Interpretation

The request matches a known scanning tool and was blocked by the filtering rule.

### Classification

* Simulated malicious scan

### Potential Actions (SOC Context)

* Monitor for repeated attempts from same IP
* Correlate with IDS alerts
* Expand filtering rules if needed
* Consider alerting mechanisms

---

## 8. Residual Risks

Despite the improvements, some limitations remain:

* Self-signed certificate (not trusted in real environments)
* No certificate lifecycle management (renewal automation)
* No full WAF (only basic filtering)
* No authentication or access control mechanisms
* No monitoring/alerting pipeline

---

## 9. Conclusion

This lab demonstrates that TLS security depends primarily on configuration rather than cryptographic theory alone.

The baseline configuration exposed multiple vulnerabilities, including support for deprecated protocols and weak cipher suites. Through systematic hardening, these issues were eliminated and replaced with a modern and secure TLS profile.

The addition of rate limiting and request filtering introduced basic but effective protection mechanisms, while log analysis provided visibility into system behavior.

The results highlight the importance of:

* Explicit security policies
* Evidence-based validation
* Continuous monitoring and adaptation

---
