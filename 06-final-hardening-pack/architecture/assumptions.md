# Architecture Assumptions - Final Hardening Pack

**Date:** 22 March 2026

---

## 1. Project scope

The hardening project covers only the components deployed in the Vagrant/VirtualBox lab environment. Infrastructure services (DNS, DHCP, NTP, Active Directory, external monitoring) are out of scope.

The four hardening areas covered are:
- **TD2**: nftables firewall on gw-fw (default-DROP policy)
- **TD3/TD5**: Suricata IDS deployment on sensor-ids
- **TD4**: TLS hardening on nginx (srv-web)
- **TD5**: key-only SSH + site-to-site IKEv2 IPsec tunnel

---

## 2. Threat model

**Attacker considered:** an external attacker who has gained network access to the DMZ segment (10.10.20.0/24), for example by compromising an exposed device. Internal (insider) threats are not modeled in this lab.

**Attacker objectives:**
- Reach non-exposed services (MySQL, internal services)
- Intercept cleartext inter-site traffic on the WAN (10.10.99.0/30)
- Gain SSH administration access through brute force or credential theft
- Operate without being detected by the IDS

**Controls put in place against them:**

| Threat | Control | Mechanism |
|--------|----------|-----------|
| Access to non-exposed services | nftables firewall | Default-DROP + minimal whitelist |
| WAN interception | IKEv2 IPsec tunnel | AES-256/SHA-256, encrypted ESP |
| SSH brute-force | Key-only authentication | PasswordAuthentication no |
| TLS downgrade | nginx ssl_protocols TLSv1.2 TLSv1.3 | TLS 1.0/1.1 disabled |
| Undetected malicious traffic | Suricata IDS | Local rules SID 9000001-9000003 |

---

## 3. Technical assumptions

**H1 - Self-signed TLS certificate acceptable in the lab**
The certificate used on srv-web (CN=td4.local, RSA 2048 bits, SHA-256 signed) is self-signed and had a short validity period (15-22 March 2026). This choice is deliberate for the lab. In production, a certificate issued by a recognized CA (Let's Encrypt, internal PKI) would be mandatory. Clients have to use `-k` (curl) or ignore the verification error.

**H2 - IPsec pre-shared key acceptable in the lab**
The strongSwan PSK is defined statically in `/etc/ipsec.secrets`. In production, X.509 certificate authentication (strongSwan PKI) would be used to avoid compromise through disclosure of the shared secret.

**H3 - SSH key generated and distributed manually**
The ED25519 key pair (`id_td5` / `id_td5.pub`) was generated on the `client` machine and copied manually to srv-web with `ssh-copy-id`. Key rotation is not automated in this lab.

**H4 - Suricata in passive IDS mode only**
The sensor-ids sensor runs in AF_PACKET single-copy mode on the `enp0s3` interface. It observes and alerts, but does not block traffic. IPS mode (inline NFQUEUE) is not deployed so as not to disrupt the tests.

**H5 - nftables persistence through systemd**
The nftables rules on gw-fw are made persistent with `systemctl enable nftables` and the `/etc/nftables.conf` file. A VM reboot keeps the rules without manual intervention.

**H6 - IP forwarding enabled on the gateways**
`net.ipv4.ip_forward = 1` is configured permanently in `/etc/sysctl.d/99-ipforward.conf` on gw-fw and gw-fwB. Without this setting, inter-zone traffic and the IPsec tunnel do not work.

**H7 - Only the admin1 user has SSH access to srv-web**
The `AllowUsers admin1` directive in sshd_config restricts SSH connections to this account. The `student` account used by Vagrant for provisioning is separate and kept for VM management.

---

## 4. Known limitations and accepted risks

| Limitation | Impact | Justification |
|--------|--------|---------------|
| Expired TLS certificate | Browser warnings, curl -k required | Acceptable in the lab, documented |
| IPsec PSK in cleartext in ipsec.secrets | Compromise if the file is exfiltrated | Acceptable in the lab, rotation in production |
| HSTS max-age=300 (5 min) | Weak HSTS protection | Lab value, production = 31536000 |
| Non-blocking Suricata IDS | Malicious traffic not interrupted | Deliberate choice so as not to block the tests |
| sudo not configured NOPASSWD for ipsec | Automated R3 test partial | Fixed in R3_remote_access.sh v2 |
| No fail2ban | SSH exposed to repeated attempts | Out of lab scope, documented in Risk_Register |

---

## 5. Naming and addressing conventions

| Item | Value | Notes |
|---------|--------|-------|
| LAN network | 10.10.10.0/24 | Site A |
| DMZ network | 10.10.20.0/24 | Site B |
| WAN/tunnel network | 10.10.99.0/30 | Inter-gateway link |
| client | 10.10.10.10 | Test and administration machine |
| gw-fw | 10.10.10.1 / 10.10.99.1 | Site A gateway |
| gw-fwB | 10.10.20.1 / 10.10.99.2 | Site B gateway |
| srv-web | 10.10.20.10 | nginx server, port 8443 |
| sensor-ids | 10.10.20.50 | Suricata sensor, interface enp0s3 |
| HTTPS port | 8443 | Non-standard, lab choice |
| IPsec algorithms | AES-256 / SHA-256 / MODP-2048 | IKEv2 |
| SSH key type | ED25519 | File id_td5 |
| Admin rule SID | 9000001 | Defined in TD3, kept in TD5 |
