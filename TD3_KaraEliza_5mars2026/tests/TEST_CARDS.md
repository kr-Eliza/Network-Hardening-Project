
```markdown
# TD3 — TEST_CARDS.md
IDS/IPS Detection Engineering with Proof

Environment:
- client: 10.10.10.10
- gw-fw: 10.10.10.1 / 10.10.20.1
- srv-web: 10.10.20.10
- sensor-ids: 10.10.20.50
- IDS: Suricata 7.x

---

# TD3-T01 — Sensor visibility in the DMZ

## Claim
The IDS sensor (sensor-ids) can observe traffic flowing between the client and the web server in the DMZ.

## Setup
The sensor interface connected to the DMZ is placed in promiscuous mode.

## Command
Executed on **client**:

```

curl [http://10.10.20.10/](http://10.10.20.10/)
ping -c 3 10.10.20.10

```

Executed on **sensor-ids**:

```

sudo tcpdump -i enp0s3 host 10.10.20.10

```

## Expected Result
Network packets between `10.10.10.10` and `10.10.20.10` are visible on the sensor.

## Evidence
```

evidence/visibility_proof.txt

```

---

# TD3-T02 — Community rule deterministic trigger

## Claim
A community Suricata rule triggers deterministically when Nmap performs service detection.

## Setup
Suricata is running with the default community rule set enabled.

## Command
Executed on **client**:

```

nmap -sS -sV -p 1-1000 10.10.20.10

```

## Expected Result
Suricata generates alerts related to Nmap scanning activity.

Example alert:

```

ET SCAN Possible Nmap User-Agent Observed
SID: 2024364

```

## Evidence
```

evidence/alerts_excerpt.txt

```

---

# TD3-T03 — Custom rule detection

## Claim
A custom Suricata rule detects HTTP requests to the `/admin` path.

## Custom rule

```

alert http $HOME_NET any -> $HOME_NET 80 (msg:"TD3 CUSTOM - HTTP request to /admin detected"; flow:to_server,established; http.uri; content:"/admin"; sid:9000001; rev:1; classtype:policy-violation;)

```

## Command
Executed on **client**:

```

curl [http://10.10.20.10/admin](http://10.10.20.10/admin)

```

## Expected Result
Suricata generates an alert with SID `9000001`.

Example alert:

```

[1:9000001:1] TD3 CUSTOM - HTTP request to /admin detected

```

## Evidence
```

evidence/alerts_excerpt.txt

```

---

# TD3-T04 — Custom rule specificity (negative test)

## Claim
The custom rule only triggers for `/admin` and not for unrelated URIs.

## Command
Executed on **client**:

```

curl [http://10.10.20.10/index.html](http://10.10.20.10/index.html)

```

## Expected Result
No new alert with SID `9000001` is generated.

## Evidence
```

evidence/alerts_excerpt.txt

```

---

# TD3-T05 — Alert noise identification

## Claim
Some community rules generate multiple alerts for the same scanning activity.

## Command
Executed on **client**:

```

nmap -sS -sV -p 1-1000 10.10.20.10

```

## Observation
Multiple alerts appear with the same rule ID.

Example:

```

SID: 2024364
ET SCAN Possible Nmap User-Agent Observed

```

## Evidence
```

evidence/alerts_excerpt.txt

```

---

# TD3-T06 — IDS alert tuning using threshold

## Claim
Applying a threshold rule reduces repeated alerts from the same source while preserving detection.

## Tuning configuration

```

threshold gen_id 1, sig_id 2024364, type limit, track by_src, count 1, seconds 60

```

## Procedure

### BEFORE tuning

Execute on **client**:

```

nmap -sS -sV -p 1-1000 10.10.20.10

```

Count alerts on **sensor-ids**:

```

sudo grep -c "2024364" /var/log/suricata/fast.log

```

### AFTER tuning

Execute the same scan again:

```

nmap -sS -sV -p 1-1000 10.10.20.10

```

Count alerts again:

```

sudo grep -c "2024364" /var/log/suricata/fast.log

```

## Expected Result

```

BEFORE tuning  → multiple alerts
AFTER tuning   → reduced number of alerts (typically 1)

```

## Evidence

```

evidence/before_after_counts.txt

```

---

# TD3-T07 — Reproducibility

## Claim
All detection behaviors can be reproduced using the documented commands.

## Procedure

Run the commands listed in:

```

tests/commands.txt

```

## Expected Result

The same alerts and alert counts are observed.

## Evidence

```

tests/commands.txt
evidence/alerts_excerpt.txt
evidence/before_after_counts.txt

```

---

# Summary

The test suite demonstrates:

- IDS visibility on the monitored network segment
- Deterministic triggering of community rules
- Successful implementation of a custom detection rule
- Validation through positive and negative tests
- Reduction of alert noise through threshold tuning
- Full reproducibility of the detection workflow
```

---

