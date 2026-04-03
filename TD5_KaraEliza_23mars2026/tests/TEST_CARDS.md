

# 1. Introduction

This document defines the test cards used to validate the security and networking objectives of TD5.
Each test card follows a structured format:

* **ID**
* **Claim**
* **Command**
* **Expected Result**
* **Evidence File**

The goal is to provide **clear, reproducible validation** of both SSH hardening and IPsec tunnel deployment.

---

# 2. SSH Hardening Tests

---

## 🔐 TD5-T01 — SSH Key-Based Authentication Works

**Claim:**
Only key-based authentication allows access to the server.

**Command (siteA-client / Kali):**

```bash
ssh -i ~/.ssh/id_td5 admin1@10.10.20.10 "echo SSH_KEY_OK"
```

**Expected Result:**

```text
SSH_KEY_OK
```

**Evidence:**

```
evidence/ssh_success.txt
```

---

## 🔐 TD5-T02 — Password Authentication is Disabled

**Claim:**
Password-based SSH authentication is disabled.

**Command:**

```bash
ssh -o PubkeyAuthentication=no admin1@10.10.20.10
```

**Expected Result:**

```text
Permission denied (publickey)
```

**Evidence:**

```
evidence/ssh_fail_no_valid_key.txt
```

---

## 🔐 TD5-T03 — Root Login is Disabled

**Claim:**
Root login via SSH is not allowed.

**Command:**

```bash
ssh -i ~/.ssh/id_td5 root@10.10.20.10
```

**Expected Result:**

```text
Permission denied
```

**Evidence:**

```
evidence/ssh_fail_root.txt
```

---

## 🔐 TD5-T04 — SSH Access is Restricted to Authorized Users

**Claim:**
Only the specified user (`admin1`) can connect via SSH.

**Command:**

```bash
ssh testuser@10.10.20.10
```

**Expected Result:**

```text
Permission denied
```

**Evidence:**

```
evidence/authlog_excerpt.txt
```

---

## 🔐 TD5-T05 — SSH Logs Record Authentication Events

**Claim:**
Successful and failed SSH attempts are logged.

**Command (siteB-srv):**

```bash
sudo tail -n 50 /var/log/auth.log
```

**Expected Result:**

* Accepted publickey for admin1
* Failed login attempts recorded

**Evidence:**

```
evidence/authlog_excerpt.txt
```

---

# 3. Network Connectivity Tests (Before IPsec)

---

## 🌐 TD5-T06 — LAN Connectivity

**Claim:**
Client can reach its local gateway.

**Command (Kali):**

```bash
ping -c 4 10.10.10.1
```

**Expected Result:**

```text
0% packet loss
```

**Evidence:**

```
evidence/ping_lan_before.txt
```

---

## 🌐 TD5-T07 — WAN Connectivity Between Gateways

**Claim:**
Gateways can communicate over the WAN.

**Command (siteA-gw):**

```bash
ping -c 4 10.10.99.2
```

**Expected Result:**

```text
0% packet loss
```

**Evidence:**

```
evidence/ping_wan_before.txt
```

---

## 🌐 TD5-T08 — Inter-Site Connectivity Before IPsec

**Claim:**
Traffic between Site A and Site B is possible before IPsec.

**Command (Kali):**

```bash
ping -c 4 10.10.20.10
```

**Expected Result:**

```text
0% packet loss
```

**Evidence:**

```
evidence/ping_inter_site_before.txt
```

---

## 🌐 TD5-T09 — Cleartext Traffic Visible on WAN

**Claim:**
Traffic between sites is visible in cleartext before IPsec.

**Command (siteA-gw):**

```bash
sudo tcpdump -ni enp0s8 icmp
```

**Expected Result:**

* ICMP packets visible

**Evidence:**

```
evidence/tcpdump_before_ipsec.txt
```

---

# 4. IPsec Tunnel Tests

---

## 🔒 TD5-T10 — IPsec Tunnel Establishment

**Claim:**
The IPsec tunnel is successfully established.

**Command (gateway):**

```bash
sudo ipsec statusall
```

**Expected Result:**

```text
ESTABLISHED
INSTALLED
10.10.10.0/24 === 10.10.20.0/24
```

**Evidence:**

```
evidence/ipsec_status.txt
```

---

## 🔒 TD5-T11 — Encrypted Connectivity Through Tunnel

**Claim:**
Traffic between sites is still functional after IPsec activation.

**Command (Kali):**

```bash
ping -c 4 10.10.20.10
```

**Expected Result:**

```text
0% packet loss
```

**Evidence:**

```
evidence/tunnel_ping.txt
```

---

## 🔒 TD5-T12 — ESP Traffic Observed on WAN

**Claim:**
Traffic is encrypted and appears as ESP on the WAN interface.

**Command (siteA-gw):**

```bash
sudo tcpdump -ni enp0s8 'udp port 500 or udp port 4500 or esp'
```

**Expected Result:**

* ESP packets observed
* No ICMP packets in cleartext

**Evidence:**

```
evidence/tcpdump_after_ipsec.txt
```

---

## 🔒 TD5-T13 — Tunnel Scope Enforcement

**Claim:**
Only traffic between defined subnets is tunneled.

**Command:**

```bash
ipsec statusall
```

**Expected Result:**

```text
10.10.10.0/24 === 10.10.20.0/24
```

**Evidence:**

```
evidence/ipsec_status.txt
```

---

# 5. Security Validation Tests

---

## 🛡️ TD5-T14 — No Cleartext Traffic After IPsec

**Claim:**
No sensitive traffic is visible in cleartext on WAN.

**Command:**

```bash
sudo tcpdump -ni enp0s8 icmp
```

**Expected Result:**

* No ICMP packets observed

**Evidence:**

```
evidence/tcpdump_after_ipsec.txt
```

---

## 🛡️ TD5-T15 — Only Required Ports Used for IPsec

**Claim:**
Only necessary ports (UDP 500, UDP 4500) are used for IPsec negotiation.

**Command:**

```bash
sudo tcpdump -ni enp0s8 udp
```

**Expected Result:**

* Traffic only on ports 500 and/or 4500

**Evidence:**

```
evidence/tcpdump_after_ipsec.txt
```

---

# 6. Conclusion

The test cards validate:

* Secure SSH configuration
* Proper network routing
* Successful IPsec tunnel establishment
* Effective encryption of inter-site traffic

Each claim is supported by reproducible commands and associated evidence files, ensuring a complete and verifiable validation of the TD objectives.

---

