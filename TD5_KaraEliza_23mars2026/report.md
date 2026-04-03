
# 1. Introduction

The objective of this lab was to design, secure, and validate a **multi-site network architecture** using two complementary security mechanisms:

* **SSH hardening** to secure administrative access
* **IPsec site-to-site VPN** to ensure confidentiality of inter-site communications

The lab simulates a real-world scenario where two remote infrastructures must communicate securely over an untrusted network (WAN), while enforcing strict access control on critical systems.

This work required not only implementation but also **deep troubleshooting**, highlighting the dependency between networking and security layers.

---

# 2. Architecture Overview

## 2.1 Logical Topology

```id="arch1"
Site A (LAN)                         Site B (DMZ)
---------------------               ---------------------
siteA-client                        siteB-srv
10.10.10.10                         10.10.20.10
        |                                   |
        |                                   |
   siteA-gw ----------------------- siteB-gw
   10.10.10.1                      10.10.20.1
   10.10.99.1                      10.10.99.2
           \_______________________________/
                    WAN (10.10.99.0/24)
```

---

## 2.2 Network Segmentation

| Network       | Purpose               |
| ------------- | --------------------- |
| 10.10.10.0/24 | Site A LAN            |
| 10.10.20.0/24 | Site B DMZ            |
| 10.10.99.0/24 | WAN (interconnection) |

---

## 2.3 Design Rationale

* Separation of LAN and DMZ reflects real infrastructure isolation
* WAN is treated as **untrusted network**
* Gateways act as:

  * routers
  * security enforcement points
  * VPN endpoints

---

# 3. Phase 1 — Network Configuration

---

## 3.1 Interface Configuration

Each gateway was configured with two interfaces:

### siteA-gw

```id="confA"
LAN → 10.10.10.1/24  
WAN → 10.10.99.1/24
```

### siteB-gw

```id="confB"
DMZ → 10.10.20.1/24  
WAN → 10.10.99.2/24
```

---

## 3.2 IP Forwarding

To allow packet forwarding between interfaces:

```bash
sysctl -w net.ipv4.ip_forward=1
```

This enables gateways to function as routers.

---

## 3.3 Static Routing

Routing was manually configured:

```bash
# siteA-gw
ip route add 10.10.20.0/24 via 10.10.99.2

# siteB-gw
ip route add 10.10.10.0/24 via 10.10.99.1
```

---

## 3.4 End-to-End Routing Logic

Example flow:

```id="flow"
siteA-client → siteA-gw → WAN → siteB-gw → siteB-srv
```

Each hop depends on:

* correct interface
* correct route
* IP forwarding enabled

---

## 3.5 Validation Before Security Layer

Connectivity tests confirmed:

```bash
ping 10.10.10.1
ping 10.10.99.2
ping 10.10.20.10
```

---

## 3.6 Traffic Observation (Before IPsec)

```bash
tcpdump -ni enp0s8 icmp
```

Result:

* ICMP packets visible in cleartext

👉 This demonstrates:

* no confidentiality
* full exposure on WAN

---

# 4. Phase 2 — SSH Hardening

---

## 4.1 Security Objective

Reduce attack surface by:

* eliminating password-based attacks
* preventing root access
* restricting user access

---

## 4.2 Key-Based Authentication

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_td5
ssh-copy-id -i ~/.ssh/id_td5.pub admin1@10.10.20.10
```

---

## 4.3 SSH Configuration

```text
PasswordAuthentication no
PermitRootLogin no
AllowUsers admin1
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
```

---

## 4.4 Security Impact

| Control          | Effect                       |
| ---------------- | ---------------------------- |
| Disable password | prevents brute-force         |
| Disable root     | prevents privilege abuse     |
| AllowUsers       | limits access                |
| Key auth         | strong identity verification |

---

## 4.5 Validation

### Successful login

```bash
ssh -i ~/.ssh/id_td5 admin1@10.10.20.10
```

### Failed attempts

* password login rejected
* root login rejected

---

## 4.6 Logging

```bash
/var/log/auth.log
```

Provides:

* traceability
* forensic capability

---

# 5. Phase 3 — IPsec VPN

---

## 5.1 Security Objective

Ensure:

* confidentiality
* integrity
* authentication

Between:

```id="scope"
10.10.10.0/24 ↔ 10.10.20.0/24
```

---

## 5.2 Protocol Choice

* IKEv2 → key exchange
* ESP → encrypted payload

---

## 5.3 Configuration Overview

### Key parameters

| Parameter   | Role                    |
| ----------- | ----------------------- |
| left/right  | tunnel endpoints        |
| leftsubnet  | protected local network |
| rightsubnet | remote network          |
| ike         | negotiation algorithms  |
| esp         | encryption algorithms   |

---

## 5.4 Cryptographic Choices

```text
AES-256 → confidentiality  
SHA-256 → integrity  
MODP2048 → key exchange
```

👉 Strong modern configuration

---

## 5.5 Tunnel Establishment

```bash
ipsec restart
ipsec statusall
```

Expected:

```text
ESTABLISHED
INSTALLED
```

---

## 5.6 Traffic Flow After IPsec

Flow becomes:

```id="flow2"
siteA-client → siteA-gw → [ENCRYPTED] → siteB-gw → siteB-srv
```

---

## 5.7 Validation

### Connectivity

```bash
ping 10.10.20.10
```

→ still works

---

### Traffic analysis

```bash
tcpdump -ni enp0s8
```

Result:

* ESP packets
* no ICMP visible

👉 Proof of encryption

---

# 6. Troubleshooting and Failure Analysis

---

## 6.1 WAN Misconfiguration

Incorrect IP assignment:

* WAN had DMZ IP

Impact:

* no gateway connectivity
* IPsec failure

---

## 6.2 Missing WAN Connectivity

IPsec attempted before:

```bash
ping 10.10.99.2
```

Impact:

* tunnel never established

---

## 6.3 Residual IPsec Policies

Even after stopping IPsec:

* traffic blocked

Fix:

```bash
ip xfrm state flush
ip xfrm policy flush
```

---

## 6.4 Routing Conflict

Static routes + IPsec conflict

Fix:

```bash
ip route del ...
```

---

## 6.5 Debugging Methodology

Initial issue:

* focus on IPsec instead of network

Final approach:

1. interfaces
2. routing
3. connectivity
4. IPsec

---

# 7. Security Evaluation

---

## 7.1 Before Hardening

* open SSH access
* cleartext traffic
* high attack surface

---

## 7.2 After Hardening

| Aspect   | Improvement |
| -------- | ----------- |
| SSH      | secured     |
| Access   | restricted  |
| Traffic  | encrypted   |
| Exposure | reduced     |

---

## 7.3 Threat Mitigation

| Threat           | Mitigation        |
| ---------------- | ----------------- |
| brute-force      | password disabled |
| sniffing         | IPsec             |
| lateral movement | restricted users  |
| interception     | encryption        |

---

# 8. Lessons Learned

---

## 🔹 Networking First, Security Second

Security mechanisms depend on network correctness.

---

## 🔹 IPsec Is Transparent

* should not break connectivity
* only encrypt traffic

---

## 🔹 Debugging Must Be Layered

* L1 → interface
* L2 → ARP
* L3 → routing
* L7 → services

---

## 🔹 Misconfiguration Impact

A single wrong IP:
→ breaks entire architecture

---

# 9. Conclusion

This lab demonstrates the integration of:

* **Access control (SSH)**
* **Confidentiality (IPsec)**

into a coherent security architecture.

The final system ensures:

* secure administration
* encrypted inter-site communication
* controlled exposure

This reflects real-world secure network design principles.

---
