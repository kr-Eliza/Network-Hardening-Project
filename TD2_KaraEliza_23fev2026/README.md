
# TD2 — Firewall Policy From Flows

## Overview

This repository contains the implementation and verification artifacts for **TD2 — Firewall Policy From Flows** in the Network Hardening laboratory.

The objective of this lab is to translate a previously identified network baseline (from TD1) into an enforceable firewall policy using **nftables** on the gateway host.

The firewall enforces a **default-deny security posture**, where only explicitly allowed traffic flows between network zones.

The repository includes the firewall policy definition, implementation ruleset, test procedures, verification evidence, and a detailed report describing the deployment and validation process.

---

# Lab Architecture

The lab environment consists of four virtual machines organized into two network zones.

| Host | Role | Zone | IP Address |
|-----|------|------|-----------|
| client | traffic generator and testing host | LAN | 10.10.10.10 |
| gw-fw | gateway and firewall | LAN / DMZ | 10.10.10.1 / 10.10.20.1 |
| srv-web | web server and SSH host | DMZ | 10.10.20.10 |
| sensor-ids | passive monitoring host | DMZ | 10.10.20.50 |

### Network Zones

**LAN (trusted zone)**  
10.10.10.0/24

**DMZ (semi-trusted zone)**  
10.10.20.0/24

The gateway (`gw-fw`) connects both networks and enforces the firewall policy.

---

# Security Model

The firewall follows a **least-privilege allow-list approach**.

Default policies:

| Chain | Policy |
|------|-------|
| INPUT | DROP |
| FORWARD | DROP |
| OUTPUT | ACCEPT |

This ensures that all traffic is blocked unless explicitly authorized.

---

# Allowed Traffic

The firewall allows only the following flows:

| Source | Destination | Protocol | Port | Purpose |
|------|-------------|----------|------|--------|
| LAN | srv-web | TCP | 80 | HTTP web access |
| LAN | srv-web | TCP | 443 | HTTPS path |
| LAN | srv-web | TCP | 22 | SSH administration |
| LAN | DMZ | ICMP | echo-request | diagnostics |
| LAN | gw-fw | TCP | 22 | firewall administration |

Stateful traffic handling is implemented using:

```

ct state established,related accept

```

---

# Repository Structure

```

.
├── config
│   ├── firewall_ruleset.txt
│   ├── policy.md
│   └── rollback.sh
│
├── tests
│   ├── commands.txt
│   └── TEST_CARDS.md
│
├── evidence
│   ├── baseline.pcap
│   ├── counters_before.txt
│   ├── counters_after.txt
│   ├── deny_logs.txt
│   └── nmap_srvweb.txt
│
├── appendix
│   └── failure_modes.md
│
├── report.md
└── README.md

```

---

# Firewall Implementation

The firewall was implemented on `gw-fw` using **nftables**.

Example rule:

```

ip saddr 10.10.10.0/24 ip daddr 10.10.20.10 tcp dport 80 accept

```

Rules were implemented incrementally to avoid administrative lockout.

The final ruleset was exported with:

```

sudo nft list ruleset

```

and stored in:

```

config/firewall_ruleset.txt

```

---

# Verification Methodology

The firewall configuration was validated through structured testing.

Two types of tests were executed:

### Positive tests

Confirm required services remain available:

- HTTP to `srv-web`
- SSH to `srv-web`
- SSH to `gw-fw`
- ICMP diagnostics

### Negative tests

Confirm unauthorized traffic is blocked:

- random high ports
- MySQL
- Telnet
- DNS
- DMZ-initiated connections to LAN

Test commands and results are recorded in:

```

tests/commands.txt

```

Test case descriptions are documented in:

```

tests/TEST_CARDS.md

```

---

# Evidence Collection

Firewall behavior was validated using multiple evidence sources.

### Packet capture

Baseline traffic capture:

```

evidence/baseline.pcap

```

### Port scanning

Service discovery:

```

evidence/nmap_srvweb.txt

```

### Firewall counters

Before testing:

```

evidence/counters_before.txt

```

After testing:

```

evidence/counters_after.txt

```

### Firewall logs

Blocked traffic logs:

```

evidence/deny_logs.txt

```

---

# Rollback Procedure

In case of configuration errors or administrative lockout, the firewall rules can be reset using:

```

./config/rollback.sh

```

This script flushes the nftables ruleset and restores permissive forwarding.

---

# Results

The firewall policy successfully enforced the intended network segmentation.

Observed results:

• authorized services remained functional  
• unauthorized traffic was blocked  
• firewall counters confirmed rule usage  
• denied packets were logged  

These results confirm that the firewall implementation correctly enforces the security policy derived from the TD1 reachability matrix.

---

# Conclusion

This lab demonstrates how a baseline network flow analysis can be translated into a practical firewall configuration.

The implementation illustrates several core security principles:

- least privilege
- default deny
- stateful packet filtering
- observable enforcement through logging and counters

The final firewall configuration effectively protects the gateway while allowing only the minimal traffic required for the lab environment.
```
