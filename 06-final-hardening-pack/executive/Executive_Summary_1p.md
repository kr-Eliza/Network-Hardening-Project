# Executive Summary - Network Hardening Project TD1-TD5

**Project:** Network Security - TD1 to TD5  
**Date:** 22 March 2026  
**Environment:** 5 Vagrant/VirtualBox VMs - Ubuntu 24.04 LTS

---

## Context

A multi-site virtual network environment (LAN 10.10.10.0/24 ↔ DMZ 10.10.20.0/24) had a maximal attack surface at baseline: no network filtering, weak TLS, password-based SSH access, cleartext inter-site traffic, no intrusion detection. This project consisted of applying four complementary security controls and validating them with reproducible tests.

---

## Deployed controls

**nftables firewall (TD2)** - Default-DROP policy on gw-fw. Only two flows are allowed from the LAN to the DMZ: HTTPS (port 8443) and SSH (port 22). Sensitive ports (MySQL 3306, HTTP 80) are blocked. Configuration made persistent through systemd.

**TLS hardening (TD4)** - nginx on srv-web now only accepts TLS 1.2 and 1.3, with ECDHE-AES256-GCM suites only. TLS 1.0 and 1.1 are rejected (alert protocol version). The `Strict-Transport-Security` header is enabled. testssl.sh audit: no weak suite offered.

**Secure remote access (TD5)** - SSH restricted to ED25519 key authentication for the `admin1` user only. IKEv2 site-to-site IPsec tunnel established between the two gateways (AES-256/SHA-256/MODP-2048), encrypting all inter-site traffic.

**IDS detection (TD3/TD5)** - Suricata 7 deployed in passive mode on sensor-ids (interface enp0s3). Three active local rules (SID 9000001-9000003) targeting access to `/admin`, MySQL scans and SSH brute-force attempts. Alerts logged in JSON (eve.json) and in text (fast.log).

---

## Validation results

Four bash regression scripts (`R1` to `R4`) validate each control in an automated and reproducible way. The final run (`20260322_235312`) gives **4/4 PASS** after fixing two typo bugs in the initial scripts.

| Control | Script | Result |
|----------|--------|----------|
| R1 - Firewall | R1_firewall.sh | PASS |
| R2 - TLS | R2_tls.sh | PASS |
| R3 - SSH + IPsec | R3_remote_access.sh | PASS |
| R4 - Suricata IDS | R4_detection.sh | PASS |

---

## Main residual risks

Three risks are accepted within the scope of the lab and documented in the risk register:
- Self-signed and expired TLS certificate → replace with Let's Encrypt in production
- Static IPsec PSK → migrate to a strongSwan X.509 PKI
- Passive Suricata IDS → enable IPS mode (NFQUEUE) after validation in staging

The 30-60-90 day plan (`report/30_60_90_Plan.md`) details the corrective actions.
