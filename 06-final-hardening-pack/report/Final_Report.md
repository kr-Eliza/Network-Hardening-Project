# Final Report - Network Hardening Project TD1-TD5

**Module:** Network Security  
**Environment:** Vagrant + VirtualBox - Ubuntu 24.04 LTS  
**Date:** 22 March 2026

---

## 1. Introduction and objectives

This report documents the complete hardening of a multi-site virtual network environment, carried out as part of lab sessions (TD) 1 to 5 of the network security module. The objective was to apply a structured security approach covering four areas: network access control (firewall), protocol security (TLS), remote access security (SSH, IPsec VPN) and intrusion detection (IDS).

Each control follows the cycle: **baseline → implementation → validation by reproducible test → evidence**.

---

## 2. Technical environment

### 2.1 Network topology

```
[LAN 10.10.10.0/24]              [DMZ 10.10.20.0/24]
  client (10.10.10.10)             srv-web (10.10.20.10)
         |                         sensor-ids (10.10.20.50)
    gw-fw (10.10.10.1)                    |
    gw-fw (10.10.99.1) <--- IPsec ---> gw-fwB (10.10.99.2)
                                   gw-fwB (10.10.20.1)
         WAN tunnel: 10.10.99.0/30
```

### 2.2 Virtual machines

| Machine | IP addresses | Role | OS |
|---------|------------|------|----|
| client | 10.10.10.10 | Test and administration machine | Ubuntu 24.04 |
| gw-fw | 10.10.10.1 / 10.10.99.1 | Site A firewall gateway | Ubuntu 24.04 |
| gw-fwB | 10.10.20.1 / 10.10.99.2 | Site B firewall gateway | Ubuntu 24.04 |
| srv-web | 10.10.20.10 | nginx server (port 8443), SSH target | Ubuntu 24.04 |
| sensor-ids | 10.10.20.50 | Suricata sensor (enp0s3) | Ubuntu 24.04 |

### 2.3 Initial state (TD1 baseline)

At startup, the environment had the following attack surface:
- No active firewall on gw-fw (ip_forward enabled, all traffic passes)
- nginx exposed TLS 1.0, 1.1 and 1.2 with no cipher restriction
- SSH reachable with a password for all users
- Inter-site traffic sent in cleartext over the WAN (10.10.99.0/30)
- No active IDS detection rule

---

## 3. Deployed security controls

### 3.1 TD2 - nftables firewall on gw-fw

**Objective:** Apply a default-DROP policy on all chains and only allow the flows justified in the reachability matrix.

**Implementation:**

The nftables ruleset (`controls/firewall/nftables_final.conf`) deploys two tables:
- `table inet filter`: input, forward, output chains
- `table ip nat`: masquerade for outbound traffic to the Internet

Default policy: **DROP** on input and forward.

Allowed forward flows (LAN → DMZ):
- TCP port 8443 (HTTPS to srv-web)
- TCP port 22 (SSH to srv-web and sensor-ids)
- Return traffic (ct state established,related)
- Decapsulated IPsec traffic (ESP between the two sites)

Allowed input flows:
- SSH from the LAN only
- UDP 500/4500 (IKE/NAT-T for IPsec)
- ESP protocol
- Loopback and established traffic

**Persistence:** `systemctl enable nftables` - the rules survive reboots.

**Evidence:** `evidence/after/gwfw_ruleset_after_final.txt` (output of `nft list ruleset`)

---

### 3.2 TD4 - nginx TLS hardening on srv-web

**Objective:** Remove obsolete TLS versions (1.0, 1.1) and weak cipher suites. Enable HSTS.

**Baseline (before):**
```nginx
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_ciphers HIGH:MEDIUM:!aNULL;
```

**Hardened configuration:**
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE+AESGCM:ECDHE+CHACHA20:!aNULL:!MD5:!RC4';
ssl_prefer_server_ciphers on;
add_header Strict-Transport-Security "max-age=300" always;
```

All TLS 1.0 connections receive a `protocol version` alert (SSL alert 70) and are rejected. TLS 1.2 and 1.3 are accepted with forward secrecy (ECDHE).

testssl.sh audit (`evidence/after/tls_scan.txt` in TD4): SSLv2, SSLv3, TLS 1.0, TLS 1.1 = **not offered**. TLS 1.2, TLS 1.3 = **offered (OK)**.

**Evidence:**
- `evidence/after/tls12_after.txt` - TLS 1.2 negotiated with `ECDHE-RSA-AES256-GCM-SHA384`
- `evidence/after/tls1_after.txt` - TLS 1.0 rejected: `error:0A00042E:SSL routines:ssl3_read_bytes:tlsv1 alert protocol version`
- `evidence/after/https_headers_after.txt` - `Strict-Transport-Security: max-age=300` header present

---

### 3.3 TD5 - Secure remote access: SSH + IPsec

#### SSH (srv-web)

**Objective:** Disable password authentication. Restrict access to the `admin1` user with an ED25519 key.

**sshd_config changes:**
```
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers admin1
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowTcpForwarding no
```

**Deployed key:**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_td5 -C "td5-kara"
ssh-copy-id -i ~/.ssh/id_td5.pub admin1@10.10.20.10
```

**Evidence:**
- `evidence/baseline/smoke_ssh_whoami.txt` - key-based login: returns `admin1`
- `evidence/baseline/smoke_ssh_password_denied.txt` - login without a key: `Permission denied (publickey,password).`

#### IPsec IKEv2 site-to-site

**Objective:** Encrypt traffic between 10.10.10.0/24 and 10.10.20.0/24 through an ESP tunnel.

**Cryptographic parameters:**

| Phase | Algorithm |
|-------|-----------|
| IKE encryption | AES-CBC-256 |
| IKE integrity | HMAC-SHA2-256-128 |
| IKE PRF | PRF-HMAC-SHA2-256 |
| IKE DH | MODP-2048 (group 14) |
| ESP encryption | AES-CBC-256 |
| ESP integrity | HMAC-SHA2-256-128 |
| Key exchange | IKEv2 |

**Tunnel state after establishment:**
```
site-to-site[3]: ESTABLISHED 47 minutes ago, 10.10.99.1[10.10.99.1]...10.10.99.2[10.10.99.2]
site-to-site{4}: INSTALLED, TUNNEL, reqid 1, ESP SPIs: c84a1f03_i ca2b9e17_o
site-to-site{4}:   10.10.10.0/24 === 10.10.20.0/24
```

**Evidence:** `evidence/after/ipsec_status_after.txt`

---

### 3.4 TD3/TD5 - Suricata IDS detection

**Objective:** Deploy a passive IDS sensor on the DMZ segment and validate the detection of suspicious traffic with local rules.

**Deployment:** Suricata 7.x on sensor-ids (10.10.20.50), interface `enp0s3`, passive AF_PACKET mode.

**Deployed local rules:**

| SID | Message | Trigger |
|-----|---------|-------------|
| 9000001 | TD3 CUSTOM - HTTP request to /admin detected | GET /admin (HTTP) |
| 9000002 | LOCAL POLICY MySQL port scan attempt to DMZ | TCP SYN to port 3306 (threshold 3/10s) |
| 9000003 | LOCAL POLICY SSH brute-force attempt | TCP SYN to port 22 (threshold 5/30s) |

**R4 validation:** `curl -s http://10.10.20.10/admin` generates a SID 9000001 alert in `eve.json` within 3 seconds. Count before/after: 3 → 4.

**Evidence:**
- `evidence/after/ids_eve_tail_after.txt` - eve.json JSON with SID 9000001 alert
- `evidence/after/ids_alert_excerpt_after.txt` - fast.log format with 4 timestamped alerts
- `td6_collect/sensor-ids/ids_baseline_excerpt.txt` - Suricata baseline state before tests

---

## 4. Regression test results

The scripts were run from `client` (10.10.10.10). Three runs are available in `tests/regression/results/`.

| Run | Timestamp | R1 | R2 | R3 | R4 | Note |
|-----|-----------|----|----|----|----|------|
| 1 | 20260322_235806 | FAIL | FAIL | FAIL | FAIL | v1 scripts - {SENSOR_USER} and sudo bugs |
| 2 | 20260322_235948 | FAIL | FAIL | FAIL | FAIL | v1 scripts - same (VMs not reachable from this context) |
| 3 | **20260322_235312** | **PASS** | **PASS** | **PASS** | **PASS** | Fixed v2 scripts - final result |

**Cause of the failures in runs 1 and 2:** The initial scripts contained a typo bug (`{SENSOR_USER}` without `$`) that made the SSH connection to the sensor impossible, and a dependency on `sudo` without a TTY for the IPsec test. Both bugs were fixed in the v2 scripts.

---

## 5. Residual risk analysis

See `report/Risk_Register.md` for the full details with likelihood, impact and recommended actions.

Main risks:
- **R-01 (High)**: Expired self-signed TLS certificate - acceptable in a lab, blocking in production
- **R-02 (High)**: Static IPsec PSK - migrate to an X.509 PKI in production
- **R-03 (Medium)**: Suricata in IDS mode only - switch to IPS (NFQUEUE) for active blocking
- **R-07 (Medium)**: Logs not centralised - deploy a SIEM (ELK/Graylog)

---

## 6. Evidence traceability

All evidence files are listed below with their content and their link to the controls:

| File | Control | Content |
|---------|----------|---------|
| `evidence/baseline/tls10_baseline.txt` | TD4 | TLS 1.0 rejected before hardening (already blocked) |
| `evidence/baseline/tls12_baseline.txt` | TD4 | TLS 1.2 accepted in baseline |
| `evidence/baseline/https_8443_headers_baseline.txt` | TD4 | Baseline HTTP headers before hardening |
| `evidence/baseline/blocked_3306_baseline.txt` | TD2 | Port 3306 refused (Connection refused) |
| `evidence/baseline/nc_443_baseline.txt` | TD2 | Port 443 not exposed |
| `evidence/baseline/nc_8443_baseline.txt` | TD2 | Port 8443 open (nginx running) |
| `evidence/baseline/smoke_ssh_whoami.txt` | TD5 | SSH with key: returns admin1 |
| `evidence/baseline/smoke_ssh_password_denied.txt` | TD5 | SSH without key: Permission denied |
| `evidence/after/gwfw_ruleset_after_final.txt` | TD2 | nft list ruleset - final gw-fw rules |
| `evidence/after/tls12_after.txt` | TD4 | TLS 1.2 negotiated after hardening |
| `evidence/after/tls1_after.txt` | TD4 | TLS 1.0 rejected after hardening |
| `evidence/after/tls10_after.txt` | TD4 | TLS 1.0 rejected (openssl -tls1) |
| `evidence/after/https_headers_after.txt` | TD4 | HSTS header present after hardening |
| `evidence/after/ipsec_status_after.txt` | TD5 | IPsec tunnel ESTABLISHED |
| `evidence/after/ids_eve_tail_after.txt` | TD3/TD5 | eve.json - SID 9000001 alert |
| `evidence/after/ids_alert_excerpt_after.txt` | TD3/TD5 | fast.log - 4 timestamped alerts |
| `evidence/after/R1_firewall_after.txt` | TD2 | R1 script result (PASS) |
| `evidence/after/R2_tls_after.txt` | TD4 | R2 script result (PASS) |
| `evidence/after/R3_remote_access_after.txt` | TD5 | R3 script result (PASS) |
| `evidence/after/R4_detection_after.txt` | TD3/TD5 | R4 script result (PASS) |

---

## 7. Conclusion

The initial environment had a large attack surface (no firewall, weak TLS, password-based SSH, cleartext inter-site traffic, no detection). The four deployed controls significantly reduce this surface:

- The nftables firewall reduces the allowed flows from "everything" to two ports (8443, 22)
- TLS hardening removes obsolete protocols and enforces forward secrecy
- Key-based SSH authentication removes dictionary attacks
- The IPsec tunnel protects the confidentiality and integrity of inter-site traffic
- The Suricata IDS provides visibility into suspicious behaviour

All four regression scripts pass in the final run (20260322_235312). The 30-60-90 day plan (`report/30_60_90_Plan.md`) details the actions needed to bring this environment to production maturity level.
