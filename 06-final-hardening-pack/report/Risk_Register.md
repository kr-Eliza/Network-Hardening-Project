# Risk Register - TD1-TD5 Hardening Project

**Date:** 22 March 2026  
**Scoring method:** Likelihood (1-3) × Impact (1-3) = Raw score (1-9)

---

## Risk matrix

| ID | Risk | Component | Prob. | Impact | Score | Severity | Status |
|----|--------|-----------|-------|--------|-------|-----------|--------|
| R-01 | Self-signed and expired TLS certificate | srv-web / nginx | 3 | 2 | 6 | **High** | Accepted (lab) |
| R-02 | Static IPsec pre-shared key in cleartext | gw-fw, gw-fwB | 2 | 3 | 6 | **High** | Accepted (lab) |
| R-03 | Suricata in passive IDS mode only | sensor-ids | 3 | 2 | 6 | **High** | Accepted (lab) |
| R-04 | Logs not centralized (Suricata, nginx, sshd) | All | 2 | 2 | 4 | **Medium** | Open |
| R-05 | SSH interface exposed without anti-brute-force protection | srv-web | 2 | 2 | 4 | **Medium** | Open |
| R-06 | HSTS max-age too short (300 seconds) | srv-web / nginx | 3 | 1 | 3 | **Medium** | Accepted (lab) |
| R-07 | No automatic SSH key rotation | srv-web | 1 | 2 | 2 | **Low** | Open |
| R-08 | No custom DH params in nginx | srv-web / nginx | 1 | 2 | 2 | **Low** | Open |
| R-09 | No OCSP Stapling (self-signed certificate) | srv-web / nginx | 1 | 1 | 1 | **Low** | Accepted (lab) |
| R-10 | Limited IDS rules (3 local SIDs, no ET-Open) | sensor-ids | 2 | 2 | 4 | **Medium** | Open |

---

## Risk details

### R-01 - Self-signed and expired TLS certificate

**Description:** The X.509 certificate deployed on srv-web (CN=td4.local) is self-signed and had a validity period of 7 days (15-22 March 2026). It is expired at the time of submission.

**Technical impact:** Browsers and tools (curl without `-k`) reject the connection. A MITM attacker could substitute their own certificate without the client noticing the difference (no chain of trust).

**Existing control:** None (self-signed certificate on purpose for the lab).

**Recommended action:** In production - deploy certbot with automatic renewal (`certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"`) or use an internal PKI. Raise HSTS max-age to 31536000 at the same time.

---

### R-02 - Static IPsec pre-shared key

**Description:** The strongSwan PSK is defined in cleartext in `/etc/ipsec.secrets`. If this file is exfiltrated (e.g. through a sudo flaw or a root account compromise), the tunnel can be decrypted retrospectively from network captures.

**Technical impact:** After-the-fact decryption of inter-site traffic. Impersonation of a gateway.

**Existing control:** File `/etc/ipsec.secrets` with 600 permissions, owned by root.

**Recommended action:** Migrate to strongSwan X.509 certificate authentication. Generate a dedicated CA, issue one certificate per gateway, configure `leftcert=` / `rightcert=` in ipsec.conf.

---

### R-03 - Suricata in passive IDS mode

**Description:** Suricata observes traffic in AF_PACKET but cannot block packets. An attacker whose traffic triggers an alert can still complete their connection.

**Technical impact:** Detection without prevention. Exploitation window between the alert being generated and an operator reacting.

**Existing control:** Alerts in `eve.json` and `fast.log`. Manual review possible.

**Recommended action:** Switch to inline NFQUEUE IPS mode: `suricata -c /etc/suricata/suricata.yaml -q 0` with the iptables rule `NFQUEUE --queue-num 0`. Test in staging before production.

---

### R-04 - Logs not centralized

**Description:** Logs are stored locally on each machine (Suricata on sensor-ids, nginx on srv-web, sshd on srv-web, nftables on gw-fw). If a machine is compromised, the logs can be erased.

**Existing control:** Local logs, logrotate rotation.

**Recommended action:** Deploy Filebeat on each host towards a centralized ELK stack. Configure Kibana alerts on the critical SIDs and on repeated 4xx/5xx errors.

---

### R-05 - SSH without anti-brute-force protection

**Description:** Although `PasswordAuthentication no` prevents classic dictionary attacks, an attacker can still scan and attempt repeated connections, generating noise and consuming resources.

**Existing control:** `MaxAuthTries 3`, `LoginGraceTime 30`. Suricata rule SID 9000003 (SSH brute-force alert).

**Recommended action:** Install fail2ban with an `sshd` jail: ban after 5 failures in 10 minutes, for 1 hour. Configure an email alert on bans.

---

### R-06 - HSTS max-age too short

**Description:** The value `max-age=300` (5 minutes) does not protect effectively against HTTPS downgrade attacks. After 5 minutes, the browser no longer remembers the HSTS directive.

**Existing control:** HSTS enabled (header present).

**Recommended action:** Raise to `max-age=31536000` (1 year) with `includeSubDomains` in production. Test first with a short value to make sure there are no side effects.

---

### R-07 - No SSH key rotation

**Description:** The ED25519 key `id_td5` has been static since it was generated. A compromised key stays valid indefinitely.

**Recommended action:** Implement a quarterly rotation with Ansible: generate a new key pair, deploy the public key, remove the old one after validation.

---

### R-08 - No custom DH params in nginx

**Description:** Without `ssl_dhparam`, nginx uses the OpenSSL default DH parameters (usually 1024 or 2048 bits depending on the version). For DHE suites (not ECDHE), this may be insufficient.

**Recommended action:** Generate dedicated DH parameters: `openssl dhparam -out /etc/nginx/certs/dhparam.pem 2048` and add `ssl_dhparam /etc/nginx/certs/dhparam.pem;` to nginx.conf. In the current configuration (ECDHE only), this risk is mitigated.

---

### R-10 - Limited IDS coverage

**Description:** Only 3 local rules are active. The ET-Open (Emerging Threats) signatures covering thousands of known threats are not enabled.

**Recommended action:** Enable the ET-Open rules in IDS mode first to measure the alert volume. Filter by relevant categories (exploit, malware, policy). Use `suricata-update` to keep the rules up to date automatically.
