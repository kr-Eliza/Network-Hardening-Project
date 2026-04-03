# TD4 — TLS Audit and Hardening with Nginx

## 1. Introduction

This laboratory session focuses on the analysis and hardening of a TLS configuration deployed on a web server using Nginx. The objective is not only to enable HTTPS, but to critically evaluate a deliberately weak TLS configuration, identify its weaknesses, and implement a hardened configuration aligned with modern security practices.

The work follows a structured methodology:

* Deployment of a TLS endpoint with insecure parameters
* Baseline audit and documentation of weaknesses
* Application of security hardening measures
* Post-hardening audit and comparative analysis
* Implementation of edge security controls
* Log analysis and basic triage

The final deliverable is an evidence-driven report demonstrating the effectiveness of the applied security measures.

---

## 2. Lab Environment and Architecture

The laboratory is based on a segmented virtual network composed of four virtual machines.

### 2.1 Virtual Machines

| VM Name    | Role                      | IP Address              |
| ---------- | ------------------------- | ----------------------- |
| client     | Audit and testing machine | 10.10.10.10             |
| gw-fw      | Gateway / Firewall        | 10.10.10.1 / 10.10.20.1 |
| srv-web    | Web server (nginx + TLS)  | 10.10.20.10             |
| sensor-ids | IDS (Suricata)            | 10.10.20.50             |

### 2.2 Network Segmentation

* LAN: 10.10.10.0/24 (client network)
* DMZ: 10.10.20.0/24 (exposed services)

Traffic flows from the client to the web server through the gateway/firewall.

---

## 3. Internet Connectivity and NAT Configuration

In order to install required tools (e.g., Git, testssl.sh), Internet access was necessary.

A NAT configuration was implemented on the gateway (gw-fw):

* Addition of a third network interface in NAT mode (VirtualBox)
* DHCP configuration on the NAT interface
* Enabling IPv4 forwarding
* Implementation of masquerading using nftables

This configuration allows outbound connectivity from internal VMs while preserving network isolation.

---

## 4. Tools and Technologies

The following tools were used throughout the lab:

* Nginx: TLS termination and reverse proxy
* OpenSSL: TLS handshake inspection and certificate analysis
* curl: HTTP and HTTPS testing
* testssl.sh (optional): automated TLS scanner
* nftables: NAT and packet filtering
* tcpdump / nginx logs: traffic observation and analysis

---

## 5. Phase 1 — Deployment of Weak TLS Configuration

A self-signed certificate was generated on the web server:

```bash
openssl req -x509 -nodes -days 7 \
-newkey rsa:2048 \
-keyout server.key \
-out server.crt \
-subj "/CN=td4.local"
```

A deliberately weak TLS configuration was then applied in Nginx:

```nginx
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_ciphers HIGH:MEDIUM:!aNULL;
```

### 5.1 Identified Weaknesses

* Support for deprecated protocols (TLS 1.0 and TLS 1.1)
* Presence of weak cipher suites (CBC-based)
* Absence of HTTP Strict Transport Security (HSTS)
* Incomplete enforcement of forward secrecy

This configuration simulates a legacy or misconfigured production system.

---

## 6. Phase 2 — Baseline TLS Audit (Before Hardening)

A set of tools was used to evaluate the TLS configuration.

### 6.1 OpenSSL

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1
```

Result: successful handshake using TLS 1.0

### 6.2 curl

```bash
curl -vk https://10.10.20.10:8443
```

Observation: TLS connection established with weak configuration

### 6.3 testssl.sh

```bash
./testssl.sh --fast --warnings batch https://10.10.20.10:8443
```

### 6.4 Summary of Findings

| Item            | Result      |
| --------------- | ----------- |
| TLS 1.0         | Supported   |
| TLS 1.1         | Supported   |
| TLS 1.2         | Supported   |
| Weak ciphers    | Present     |
| Forward secrecy | Partial     |
| Certificate     | Self-signed |
| HSTS            | Not enabled |

---

## 7. Phase 3 — TLS Hardening

The Nginx configuration was updated to enforce a secure TLS policy.

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE+AESGCM:ECDHE+CHACHA20:!aNULL:!MD5:!RC4;
ssl_prefer_server_ciphers on;

add_header Strict-Transport-Security "max-age=300" always;
```

### 7.1 Security Improvements

* Removal of deprecated protocols (TLS 1.0 and TLS 1.1)
* Enforcement of AEAD cipher suites
* Mandatory forward secrecy through ECDHE
* Introduction of HSTS to enforce HTTPS

This configuration aligns with modern recommendations, including NIST SP 800-52 Rev.2.

---

## 8. Phase 4 — Post-Hardening Audit (After)

The same tests were executed again to ensure reproducibility.

### 8.1 Protocol Testing

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1
```

Result:

* Handshake failure
* Protocol rejected

```bash
openssl s_client -connect 10.10.20.10:8443 -tls1_2
```

Result:

* Successful handshake
* Secure cipher negotiated

### 8.2 Summary Comparison

| Item            | Before      | After     |
| --------------- | ----------- | --------- |
| TLS 1.0         | Supported   | Rejected  |
| TLS 1.1         | Supported   | Rejected  |
| TLS 1.2         | Supported   | Supported |
| TLS 1.3         | Not enabled | Enabled   |
| Weak ciphers    | Present     | Removed   |
| Forward secrecy | Partial     | Enforced  |
| HSTS            | Disabled    | Enabled   |

---

## 9. Phase 5 — Edge Security Controls

### 9.1 Rate Limiting

Configuration:

```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

location /api {
    limit_req zone=api_limit burst=5 nodelay;
    return 200 "API response\n";
}
```

### Test:

```bash
for i in $(seq 1 30)
do
curl -sk -o /dev/null -w "%{http_code}\n" https://10.10.20.10:8443/api
done
```

### Result:

* Initial requests return HTTP 200
* Excess requests return HTTP 503

This demonstrates effective rate limiting under burst conditions.

---

### 9.2 Request Filtering

Configuration:

```nginx
if ($http_user_agent ~* "sqlmap|nikto|dirbuster") {
    return 403;
}
```

### Test:

```bash
curl -k -A "sqlmap" https://10.10.20.10:8443
```

### Result:

* Normal request: HTTP 200
* Malicious User-Agent: HTTP 403

This demonstrates basic request filtering capability.

---

## 10. Phase 6 — Log Analysis (Triage)

Example log entry:

```
10.10.10.10 - - [date] "GET / HTTP/1.1" 403 "-" "sqlmap"
```

### Analysis

* Source IP: internal client
* Request: GET /
* Status code: 403
* User-Agent: sqlmap

### Interpretation

The request was identified as potentially malicious and blocked by the filtering rule.

### Classification

Simulated scanning activity.

### Potential Response Actions

* Monitor for repeated attempts
* Correlate with IDS alerts
* Adjust filtering rules if necessary

---

## 11. Issues Encountered

Several technical issues were encountered during the lab:

* Lack of Internet connectivity due to missing NAT configuration
* NAT interface initially not receiving an IP address
* Incorrect Git commands preventing repository cloning
* Confusion between Nginx configuration files (`nginx.conf` vs `sites-available`)
* Rate limiting not triggering due to incorrect placement in configuration

Each issue was diagnosed and resolved during the lab.

---

## 12. Project Structure

```
TD4/

README.md
report.md
commands.txt

config/
    nginx_before.conf
    nginx_after.conf
    cert_info_before.txt

evidence/
    before/
    after/

tests/
    TEST_CARDS.md

appendix/
    failure_modes.md
```

---

## 13. Conclusion

This lab demonstrates that TLS security is highly dependent on configuration choices.

The initial configuration exposed multiple weaknesses, including support for deprecated protocols and weak cipher suites. Through systematic hardening, these weaknesses were eliminated and replaced with a robust and defensible configuration.

The addition of edge controls further enhanced security by introducing basic protection mechanisms against abuse and scanning attempts.

Finally, log analysis provided insight into system behavior and reinforced the importance of observability in a security context.

---

## 14. References

* NIST SP 800-52 Rev.2 — Guidelines for TLS Configuration
* RFC 8446 — TLS 1.3
* Nginx Documentation
* testssl.sh Project

---
