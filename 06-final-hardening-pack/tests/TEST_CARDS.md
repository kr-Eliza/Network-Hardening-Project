# Test Cards - Final Hardening Pack

**Date:** 22 March 2026

---

## R1 - Firewall (nftables)

**Claim:** The firewall allows HTTPS traffic to srv-web:8443 and blocks unauthorized ports (e.g. MySQL 3306).

| # | Action | Command | Expected | Result |
|---|---|---|---|---|
| 1 | HTTPS traffic allowed | `curl -sk -o /dev/null -w "%{http_code}" https://10.10.20.10:8443` | HTTP 200 | PASS |
| 2 | Port 3306 blocked | `nc -vz -w 3 10.10.20.10 3306` | Connection refused (exit 1) | PASS |

**Script:** `tests/regression/R1_firewall.sh`  
**Evidence:** `evidence/after/R1_firewall_after.txt`, `evidence/after/gwfw_ruleset_after_final.txt`

---

## R2 - TLS Edge (nginx)

**Claim:** The HTTPS endpoint on 8443 only accepts TLS 1.2+ and returns an HSTS header.

| # | Action | Command | Expected | Result |
|---|---|---|---|---|
| 1 | TLS 1.2 accepted | `openssl s_client -connect 10.10.20.10:8443 -tls1_2` | `Protocol : TLSv1.2` | PASS |
| 2 | TLS 1.0 rejected | `openssl s_client -connect 10.10.20.10:8443 -tls1` | `alert protocol version` | PASS |
| 3 | HSTS present | `curl -skI https://10.10.20.10:8443` | `Strict-Transport-Security` | PASS |

**Script:** `tests/regression/R2_tls.sh`  
**Evidence:** `evidence/after/R2_tls_after.txt`, `evidence/after/tls12_after.txt`, `evidence/after/tls1_after.txt`, `evidence/after/tls10_after.txt`

---

## R3 - Remote access (SSH + IPsec)

**Claim:** SSH access is restricted to public keys. The site-to-site IPsec tunnel is established.

| # | Action | Command | Expected | Result |
|---|---|---|---|---|
| 1 | Key-based SSH succeeds | `ssh -i /home/student/.ssh/id_td5 admin1@10.10.20.10 whoami` | `admin1` | PASS |
| 2 | Password SSH refused | `ssh -o PubkeyAuthentication=no admin1@10.10.20.10` | `Permission denied` | PASS |
| 3 | Tunnel IPsec ESTABLISHED | `sudo ipsec statusall` on gw-fw | `ESTABLISHED` | PASS |

**Script:** `tests/regression/R3_remote_access.sh`  
**Evidence:** `evidence/after/R3_remote_access_after.txt`, `evidence/after/ipsec_status_after.txt`

---

## R4 - IDS detection (Suricata)

**Claim:** Suricata detects HTTP access to `/admin` (SID 9000001, aligned with the TD3 rule).

| # | Action | Command | Expected | Result |
|---|---|---|---|---|
| 1 | Alert count before | SSH → `grep -c '"signature_id":9000001' eve.json` | N=3 | PASS |
| 2 | Trigger alert | `curl -s http://10.10.20.10/admin` | Request sent | PASS |
| 3 | Alert count after | SSH → `grep -c '"signature_id":9000001' eve.json` | N+1=4 | PASS |
| 4 | Show last alert | `grep '"signature_id":9000001' eve.json \| tail -5` | Alert JSON line | PASS |

**Script:** `tests/regression/R4_detection.sh`  
**Evidence:** `evidence/after/R4_detection_after.txt`, `evidence/after/ids_eve_tail_after.txt`, `evidence/after/ids_alert_excerpt_after.txt`

**Note:** SID 9000001 is the custom rule introduced in TD3 (`TD3 CUSTOM - HTTP request to /admin detected`) and kept in TD5.

---

## Summary

| Control | Script | Result |
|---|---|---|
| R1 Firewall | R1_firewall.sh | **PASS** |
| R2 TLS | R2_tls.sh | **PASS** |
| R3 Remote Access | R3_remote_access.sh | **PASS** |
| R4 Detection | R4_detection.sh | **PASS** |
