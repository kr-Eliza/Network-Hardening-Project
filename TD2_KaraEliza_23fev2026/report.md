
```md
# TD2 — Firewall Policy From Flows
Network Hardening Laboratory

Author: <Group Name>  
Course: Network Hardening  
Lab: TD2 — Firewall Policy Implementation  
Environment: Virtualized 4-VM Lab  

---

# 1. Introduction

This lab focuses on implementing and verifying a firewall policy based on a
previously established network baseline. In TD1, the network topology and the
expected communication flows between hosts were identified and documented
through a reachability matrix.

TD2 transforms that baseline into an enforceable security control by deploying
a firewall policy on the gateway host (`gw-fw`). The firewall enforces a
default-deny security model where only explicitly authorized traffic is
allowed to cross network zones.

The objective of this lab is to demonstrate that the firewall implementation
faithfully enforces the intended security policy while maintaining required
services.

The work follows a structured security engineering process:

1. Define the security policy (intent)
2. Implement the firewall ruleset (configuration)
3. Verify behavior through testing (validation)
4. Collect operational evidence (telemetry)

This approach reflects real-world security change management practices and
aligns with recommendations from **NIST SP 800-41 Rev.1 — Guidelines on
Firewalls and Firewall Policy**.

---

# 2. Lab Environment

The lab environment consists of four virtual machines connected through two
subnets. The gateway host acts as the firewall enforcement point.

| Host | Role | Zone | IP Address |
|-----|------|------|-----------|
| client | Traffic generator and testing host | LAN | 10.10.10.10 |
| gw-fw | Gateway and firewall enforcement point | LAN / DMZ | 10.10.10.1 / 10.10.20.1 |
| srv-web | Web server and SSH host | DMZ | 10.10.20.10 |
| sensor-ids | Passive monitoring host | DMZ | 10.10.20.50 |

### Network Segmentation

The environment is divided into two logical zones:

**LAN (Trusted Zone)**  
Network: `10.10.10.0/24`  
Hosts: client

**DMZ (Semi-trusted Zone)**  
Network: `10.10.20.0/24`  
Hosts: srv-web, sensor-ids

The gateway (`gw-fw`) connects both networks and acts as the trust boundary.
All inter-zone traffic must traverse this host and is therefore subject to
firewall filtering.

---

# 3. Security Objectives

The firewall policy aims to achieve the following objectives:

• enforce least privilege between LAN and DMZ  
• block unauthorized traffic by default  
• maintain access to required services  
• protect the gateway itself from unauthorized access  
• generate telemetry for denied traffic  
• maintain an auditable and minimal ruleset  

This design ensures that only traffic identified in the TD1 reachability
matrix is allowed.

---

# 4. Firewall Architecture

The firewall is implemented using **nftables**, the modern packet filtering
framework available in Linux.

The firewall operates at the network layer and filters traffic traversing the
gateway between network zones.

Three nftables chains are used:

| Chain | Purpose |
|------|--------|
| INPUT | Traffic destined for the gateway |
| FORWARD | Traffic passing through the gateway |
| OUTPUT | Traffic originating from the gateway |

### Default Policies

| Chain | Default Action |
|------|---------------|
| INPUT | DROP |
| FORWARD | DROP |
| OUTPUT | ACCEPT |

This configuration implements a **default-deny model** for inbound and
forwarded traffic.

---

# 5. Firewall Policy

The firewall policy is derived directly from the TD1 flow matrix.

### Allowed Flows

| Source | Destination | Protocol | Port | Purpose |
|------|-------------|----------|------|--------|
| LAN | srv-web | TCP | 80 | HTTP web access |
| LAN | srv-web | TCP | 443 | HTTPS path reserved |
| LAN | srv-web | TCP | 22 | SSH administration |
| LAN | DMZ | ICMP | echo-request | Network diagnostics |
| LAN | gw-fw | TCP | 22 | Firewall administration |

### Stateful Traffic

Return traffic for allowed sessions is automatically permitted through the
stateful rule:

```

ct state established,related accept

```

This ensures that response packets belonging to valid sessions are not
blocked.

### Logging

Denied traffic is logged using the prefixes:

```

NFT_FWD_DENY
NFT_IN_DENY

```

Logging is rate-limited to prevent excessive log generation.

---

# 6. Implementation

The firewall rules were implemented on the gateway host (`gw-fw`) using
nftables commands.

### Implementation Principles

The firewall was deployed incrementally following a safe procedure:

1. Allow administrative SSH access before enabling restrictive policies.
2. Enable loopback traffic.
3. Enable stateful traffic handling.
4. Add allow-list rules derived from the reachability matrix.
5. Enable logging for denied traffic.

### Example Rule

```

ip saddr 10.10.10.0/24 ip daddr 10.10.20.10 tcp dport 80 counter accept

```

This rule permits HTTP traffic from the LAN network to the web server in the
DMZ.

All rules include packet counters in order to provide measurable evidence of
traffic processing.

The final ruleset was exported using:

```

sudo nft list ruleset

```

and saved as:

```

config/firewall_ruleset.txt

```

---

# 7. Verification Methodology

The firewall configuration was validated through both **positive tests**
(allowed traffic) and **negative tests** (blocked traffic).

Positive tests confirm that authorized communication remains functional.

Negative tests confirm that unauthorized traffic is blocked by the firewall.

All test commands were executed from the client machine or from the DMZ host
and recorded in `tests/commands.txt`.

Evidence of firewall activity was collected through rule counters and system
logs.

---

# 8. Positive Test Results

### HTTP Access

Command:

```

curl -sI [http://10.10.20.10](http://10.10.20.10)

```

Observed result:

```

HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)

```

Interpretation:

HTTP traffic from LAN to DMZ is successfully forwarded by the firewall.

---

### SSH Access to srv-web

Command:

```

ssh student@10.10.20.10 hostname

```

Result:

```

srv-web

```

Interpretation:

SSH administrative access to the DMZ host is permitted.

---

### ICMP Diagnostics

Command:

```

ping -c 2 10.10.20.10

```

Result:

```

2 packets transmitted, 2 received

```

Interpretation:

ICMP echo requests from LAN to DMZ hosts are correctly allowed.

---

### SSH Access to gw-fw

Command:

```

ssh student@10.10.10.1 hostname

```

Result:

```

gw-fw

```

Interpretation:

Administrative access to the gateway remains functional despite restrictive
firewall policies.

---

# 9. Negative Test Results

Negative tests were executed to verify that the firewall blocks unauthorized
services.

### Random High Port

Command:

```

nc -vz -w 3 10.10.20.10 12345

```

Result:

```

Connection timed out

```

Interpretation:

Traffic blocked by the firewall default deny policy.

---

### MySQL Port

Command:

```

nc -vz -w 3 10.10.20.10 3306

```

Result:

```

Connection timed out

```

Interpretation:

MySQL service access correctly blocked.

---

### Telnet Port

Command:

```

nc -vz -w 3 10.10.20.10 23

```

Result:

```

Connection timed out

```

Interpretation:

Legacy Telnet access blocked.

---

### DNS Port

Command:

```

nc -vuz -w 3 10.10.20.10 53

```

Result:

```

Connection timed out

```

Interpretation:

DNS traffic to srv-web is not permitted.

---

### DMZ to LAN Connection

Command (executed from srv-web):

```

nc -vz -w 3 10.10.10.10 22

```

Result:

```

Connection timed out

```

Interpretation:

Firewall prevents DMZ hosts from initiating connections to the LAN.

---

# 10. Counter Analysis

Firewall rule counters were collected before and after testing.

Before testing:

```

evidence/counters_before.txt

```

After testing:

```

evidence/counters_after.txt

```

Observed behavior:

• allow rules show packet counter increments  
• deny rule counters increased during negative tests  

Example counter entry:

```

counter packets 15 bytes 900 log prefix "NFT_FWD_DENY"

```

This confirms that blocked traffic attempts were detected and processed by
the firewall.

---

# 11. Log Analysis

Firewall logs were collected using:

```

journalctl -k | grep NFT_IN_DENY

```

Example log entry:

```

NFT_IN_DENY SRC=10.10.10.10 DST=10.10.10.1 PROTO=ICMP TYPE=8

```

Interpretation:

ICMP packets targeting the gateway were blocked by the INPUT chain policy.

Logs confirm that the firewall is actively recording denied traffic events.

---

# 12. Limitations

The firewall policy implemented in this lab intentionally excludes several
advanced security controls.

Not implemented:

• outbound traffic filtering (egress control)  
• deep packet inspection  
• network address translation (NAT)  
• host-based firewall policies  
• IDS or IPS blocking mechanisms  

These features are outside the scope of TD2 and may be explored in later
laboratory exercises.

---

# 13. Conclusion

The firewall policy was successfully implemented and validated within the lab
environment.

Key results include:

• enforcement of a strict default-deny policy  
• preservation of required services (HTTP, SSH, ICMP)  
• blocking of unauthorized traffic  
• generation of telemetry through firewall logs  
• confirmation of enforcement through rule counters  

The final firewall configuration demonstrates how a minimal and well-defined
policy derived from a reachability matrix can effectively enforce network
segmentation between LAN and DMZ environments.

This exercise highlights the importance of policy-driven firewall
configuration and structured verification processes in achieving secure
network hardening.
```
