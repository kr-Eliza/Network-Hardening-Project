

# 1. Overview

This laboratory exercise focuses on **Intrusion Detection System (IDS) engineering** using Suricata.  
The goal is to demonstrate how an IDS can be deployed, validated, and tuned to detect suspicious activity within a controlled network environment.

The exercise covers the following objectives:

- IDS visibility verification
- Deterministic triggering of community detection rules
- Creation of a custom detection rule
- Validation of detection using positive and negative tests
- Reduction of alert noise using threshold tuning
- Documentation and reproducibility of the detection workflow

All experiments are performed inside an isolated virtual lab environment.

---

# 2. Lab Architecture

The network topology consists of four virtual machines arranged in a segmented architecture with a DMZ.

```

client -------- LAN -------- gw-fw -------- DMZ -------- srv-web
|
|
sensor-ids

```

### Hosts

| Host | Role | IP Address |
|-----|------|------------|
| client | User workstation generating traffic | 10.10.10.10 |
| gw-fw | Gateway / firewall between LAN and DMZ | 10.10.10.1 / 10.10.20.1 |
| srv-web | Web server located in the DMZ | 10.10.20.10 |
| sensor-ids | Suricata IDS monitoring DMZ traffic | 10.10.20.50 |

### Network Segments

LAN network:
```

10.10.10.0/24

```

DMZ network:
```

10.10.20.0/24

```

The IDS sensor is connected to the DMZ network and operates in **promiscuous mode**, allowing it to observe traffic between the gateway and the web server.

---

# 3. IDS Platform

The IDS used in this laboratory is **Suricata**.

Suricata provides:

- deep packet inspection
- signature-based detection
- protocol-aware analysis
- customizable detection rules
- JSON structured logging

Detection results are primarily stored in:

```

/var/log/suricata/fast.log

```

Additional structured logs are available in:

```

/var/log/suricata/eve.json

```

---

# 4. Detection Engineering Tasks

The lab demonstrates several key aspects of IDS engineering.

## 4.1 Sensor Visibility

Before detection rules can operate correctly, the IDS must be able to observe network traffic.

Visibility was verified using:

```

tcpdump

```

Example command executed on the sensor:

```

sudo tcpdump -i enp0s3 host 10.10.20.10

```

Traffic generated from the client:

```

curl [http://10.10.20.10/](http://10.10.20.10/)
ping -c 3 10.10.20.10

```

The sensor successfully captured packets exchanged between the client and the DMZ server.

Evidence:

```

evidence/visibility_proof.txt

```

---

# 5. Community Rule Detection

Suricata ships with community rules capable of detecting known scanning patterns.

To demonstrate deterministic detection, an Nmap scan was performed.

Command executed from the client:

```

nmap -sS -sV -p 1-1000 10.10.20.10

```

This scan triggers the following Suricata rule:

```

ET SCAN Possible Nmap User-Agent Observed
SID: 2024364

```

Multiple alerts are generated because the scan produces many HTTP requests with the Nmap user-agent.

Evidence:

```

evidence/alerts_excerpt.txt

```

---

# 6. Custom Detection Rule

A custom rule was created to detect HTTP requests targeting the `/admin` path.

Custom rule file:

```

config/local.rules

```

Rule definition:

```

alert http $HOME_NET any -> $HOME_NET 80 (msg:"TD3 CUSTOM - HTTP request to /admin detected"; flow:to_server,established; http.uri; content:"/admin"; sid:9000001; rev:1; classtype:policy-violation;)

```

### Rule explanation

| Field | Purpose |
|------|--------|
| alert | generate an IDS alert |
| http | restrict rule to HTTP traffic |
| $HOME_NET | internal network |
| flow:to_server | request sent to server |
| http.uri | inspect HTTP URI |
| content:"/admin" | match the path `/admin` |
| sid | unique rule identifier |
| rev | rule revision |

---

# 7. Rule Validation

## Positive Test

Command executed on the client:

```

curl [http://10.10.20.10/admin](http://10.10.20.10/admin)

```

Expected result:

```

[1:9000001:1] TD3 CUSTOM - HTTP request to /admin detected

```

Note:

The server may return **404 Not Found**, but the IDS detects the request URI regardless of the server response.

---

## Negative Test

Command:

```

curl [http://10.10.20.10/index.html](http://10.10.20.10/index.html)

```

Expected result:

No alert with SID **9000001** is generated.

This demonstrates that the rule is specific to `/admin`.

Evidence:

```

evidence/alerts_excerpt.txt

```

---

# 8. Alert Noise and IDS Tuning

Repeated alerts can overwhelm analysts in real environments.

The Nmap rule **SID 2024364** generated multiple alerts during a single scan.

To reduce noise while preserving detection capability, a threshold rule was applied.

File:

```

config/threshold.config

```

Rule:

```

threshold gen_id 1, sig_id 2024364, type limit, track by_src, count 1, seconds 60

```

### Threshold explanation

| Parameter | Meaning |
|----------|--------|
| gen_id | rule generator |
| sig_id | rule identifier |
| track by_src | limit alerts per source IP |
| count 1 | allow one alert |
| seconds 60 | within a 60-second window |

This configuration limits repeated alerts produced by the same scanning activity.

---

# 9. Before / After Comparison

Test command:

```

nmap -sS -sV -p 1-1000 10.10.20.10

```

Results:

| Stage | Alert Count |
|------|-------------|
| Before tuning | multiple alerts |
| After tuning | reduced alerts (typically 1) |

This confirms that the threshold successfully reduces duplicate alerts.

Evidence:

```

evidence/before_after_counts.txt

```

---

# 10. Reproducibility

All detection behaviors can be reproduced by executing the commands listed in:

```

tests/commands.txt

```

This file documents the full experimental workflow.

---

# 11. Repository Structure

```

TD3/
│
├── README.md
├── report.md
│
├── config/
│   ├── local.rules
│   ├── threshold.config
│   └── interface_selection.txt
│
├── evidence/
│   ├── visibility_proof.txt
│   ├── alerts_excerpt.txt
│   └── before_after_counts.txt
│
├── tests/
│   ├── commands.txt
│   └── TEST_CARDS.md
│
└── appendix/
└── failure_modes.md

```

---

# 12. Key Takeaways

This laboratory demonstrates several important IDS engineering concepts:

- validating sensor visibility
- deterministic triggering of detection rules
- writing custom Suricata signatures
- verifying rule specificity through positive and negative tests
- reducing alert noise through threshold tuning
- documenting detection workflows for reproducibility

These skills are essential for **Security Operations Center (SOC)** detection engineering.

---

# 13. Conclusion

The lab successfully demonstrates how Suricata can be deployed to detect suspicious activity in a segmented network environment.

Through the creation of custom rules and the application of tuning mechanisms, it is possible to maintain effective detection while minimizing alert noise.

The final configuration provides:

- reliable detection of specific HTTP patterns
- controlled alert generation for scanning activity
- a reproducible detection workflow suitable for operational environments
```

---

