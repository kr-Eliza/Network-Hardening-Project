# Suricata deployment notes - TD3/TD5

## Installation

Suricata 7.0.x installed from the official PPA on Ubuntu 24.04 (sensor-ids, 10.10.20.50).

```bash
sudo add-apt-repository ppa:oisf/suricata-stable
sudo apt update && sudo apt install suricata -y
```

## Network configuration

Capture interface: `enp0s3` (DMZ segment 10.10.20.0/24)
Mode: passive IDS (AF_PACKET, single copy)

`/etc/suricata/suricata.yaml` - key excerpts:

```yaml
af-packet:
  - interface: enp0s3
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes

HOME_NET: "[10.10.10.0/24,10.10.20.0/24]"
EXTERNAL_NET: "!$HOME_NET"

default-rule-path: /etc/suricata/rules
rule-files:
  - local.rules

outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: /var/log/suricata/eve.json
      types:
        - alert
        - http
        - dns
        - tls
  - fast:
      enabled: yes
      filename: /var/log/suricata/fast.log
      append: yes
```

## Deployed rules

Only the local rules (`local.rules`) are enabled. The ET-Open rules are disabled to limit noise in the lab environment (except SID 2024364, used in TD3 for the Nmap test).

Active rules:
- SID 9000001: HTTP access to `/admin` (aligned with TD3)
- SID 9000002: MySQL port 3306 scan
- SID 9000003: SSH brute-force attempt

## Verification commands

```bash
# Check that Suricata is running
sudo systemctl status suricata

# Reload the rules without a restart
sudo suricatasc -c reload-rules

# Watch alerts in real time
sudo tail -f /var/log/suricata/eve.json | jq 'select(.event_type=="alert")'

# Count alerts per SID
sudo jq -r 'select(.event_type=="alert") | .alert.signature_id' \
    /var/log/suricata/eve.json | sort | uniq -c | sort -rn
```

## Switching to IPS mode (not deployed - documented for reference)

To switch to inline IPS with NFQUEUE:
```bash
# suricata.yaml
nfqueue:
  - queue-num: 0

# iptables to redirect the traffic
iptables -I FORWARD -j NFQUEUE --queue-num 0
```

This mode is not enabled in this lab to avoid blocking the test traffic.
