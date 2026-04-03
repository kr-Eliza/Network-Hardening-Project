

# 📄 TD5 — SSH Hardening & Site-to-Site IPsec VPN

---

# 1. Overview

This lab focuses on two major aspects of network security:

* **Secure remote administration** using SSH hardening
* **Secure inter-site communication** using a site-to-site IPsec VPN

The objective is to transform a basic multi-VM network into a **secure, production-like architecture**, ensuring:

* Controlled administrative access
* Encrypted communication between sites
* Proper network segmentation and routing

---

# 2. Network Architecture

The infrastructure is composed of two sites connected through a WAN network.

```
Site A (LAN)                        Site B (DMZ)
---------------------              ---------------------
Client                             Server (Bastion)
10.10.10.10                        10.10.20.10
        |                                  |
        |                                  |
   siteA-gw ---------------------- siteB-gw
   10.10.10.1                     10.10.20.1
   10.10.99.1                     10.10.99.2
          \______________________________/
                    WAN (10.10.99.0/24)
```

---

# 3. VM Roles

| VM             | Role              | Description                  |
| -------------- | ----------------- | ---------------------------- |
| `siteA-client` | Admin workstation | Used to access remote server |
| `siteA-gw`     | Gateway + IPsec   | Routing + VPN endpoint       |
| `siteB-gw`     | Gateway + IPsec   | Routing + VPN endpoint       |
| `siteB-srv`    | Bastion server    | Target host for SSH          |

---

# 4. Objectives

## SSH Hardening

* Disable password authentication
* Disable root login
* Restrict access to a dedicated user
* Enforce key-based authentication

## IPsec VPN

* Establish a **site-to-site IKEv2 tunnel**
* Encrypt traffic between:

  * `10.10.10.0/24` (Site A)
  * `10.10.20.0/24` (Site B)
* Ensure only scoped traffic is tunneled

---

# 5. Implementation Steps

---

## 5.1 Network Setup

* Configured LAN, DMZ, and WAN interfaces
* Enabled IP forwarding on gateways:

```bash
sysctl -w net.ipv4.ip_forward=1
```

* Configured static routes:

```bash
# Site A gateway
ip route add 10.10.20.0/24 via 10.10.99.2

# Site B gateway
ip route add 10.10.10.0/24 via 10.10.99.1
```

---

## 5.2 SSH Hardening

### Key generation (client)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_td5
ssh-copy-id -i ~/.ssh/id_td5.pub admin1@10.10.20.10
```

### SSH configuration (server)

File: `/etc/ssh/sshd_config`

```
PasswordAuthentication no
PermitRootLogin no
AllowUsers admin1
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
```

### Validation

* Successful login with key
* Password authentication denied
* Root login denied

---

## 5.3 IPsec Configuration (strongSwan)

Installed on both gateways:

```bash
sudo apt install strongswan
```

---

### siteA-gw — `/etc/ipsec.conf`

```
config setup
    charondebug="ike 2, knl 2, cfg 2"

conn site-to-site
    authby=secret
    left=10.10.99.1
    leftsubnet=10.10.10.0/24
    right=10.10.99.2
    rightsubnet=10.10.20.0/24
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256-modp2048!
    keyexchange=ikev2
    auto=start
```

---

### siteB-gw — `/etc/ipsec.conf`

```
conn site-to-site
    authby=secret
    left=10.10.99.2
    leftsubnet=10.10.20.0/24
    right=10.10.99.1
    rightsubnet=10.10.10.0/24
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256-modp2048!
    keyexchange=ikev2
    auto=start
```

---

### Shared Secret — `/etc/ipsec.secrets`

```
10.10.99.1 10.10.99.2 : PSK "<REDACTED>"
```

---

## 5.4 IPsec Activation

```bash
sudo systemctl restart strongswan-starter
sudo ipsec restart
sudo ipsec statusall
```

Expected:

```
ESTABLISHED
INSTALLED
10.10.10.0/24 === 10.10.20.0/24
```

---

# 6. Validation

---

## Before IPsec

* Ping works between sites
* Traffic visible in cleartext (ICMP)

```bash
tcpdump -ni enp0s8 icmp
```

---

## After IPsec

* Ping still works
* Traffic encrypted (ESP)

```bash
tcpdump -ni enp0s8
```

Observed:

* ESP packets
* No clear ICMP traffic

---

# 7. Results

| Test                                   | Result    |
| -------------------------------------- | --------- |
| SSH key authentication                 | ✅ Success |
| Password authentication                | ❌ Blocked |
| Root login                             | ❌ Blocked |
| Inter-site connectivity (before IPsec) | ✅         |
| IPsec tunnel establishment             | ✅         |
| Encrypted traffic (ESP)                | ✅         |

---

# 8. Security Improvements Achieved

* Elimination of password-based attacks
* Controlled administrative access
* Confidentiality of inter-site traffic
* Reduced attack surface
* Scoped VPN tunnel (no overexposure)

---

# 9. Lessons Learned

* IPsec depends on correct network configuration
* Always validate connectivity before enabling security layers
* Misconfigured interfaces can break entire infrastructure
* Static routing and IPsec must not conflict
* Debugging must follow a layered approach

---

# 10. Repository Structure

```
TD5/
├── README.md
├── report.md
├── config/
├── evidence/
├── tests/
└── appendix/
```

---

# 11. Conclusion

This lab demonstrates the transition from a basic network setup to a secure architecture by combining:

* **Access control (SSH hardening)**
* **Confidentiality (IPsec encryption)**

The final infrastructure ensures that:

* Only authorized users can access the system
* All inter-site communication is protected
* The network behaves as a secure enterprise environment

---

