# TD1 — Network Baseline for Hardening

## Team information
- **Group ID:** 
- **Team name:** Eliza KARA
- **Date:** 12/02/2026

### Team members and roles
- **ELiza KARA** — Everything

## Lab topology summary

This lab is based on a 4-VM baseline used to establish an auditable network baseline before applying hardening controls in later TDs.

### Zones
- **LAN (NH-LAN)** — `10.10.10.0/24`
- **DMZ (NH-DMZ)** — `10.10.20.0/24`

### Trust boundary
- **gw-fw** acts as the trust boundary and gateway between the LAN and the DMZ.

### Assets

| VM | Role | Zone | IP |
|---|---|---|---|
| gw-fw | Gateway / firewall / trust boundary | LAN + DMZ | 10.10.10.1 / 10.10.20.1 |
| client | Scanner, traffic generator, evidence collector | LAN | 10.10.10.10 |
| srv-web | Target services (HTTP, HTTPS, SSH) | DMZ | 10.10.20.10 |
| sensor-ids | Promiscuous capture, IDS validation | DMZ | 10.10.20.50 |

## Objective

The objective of TD1 was to establish a baseline of the lab network before implementing hardening controls. This baseline includes:
- asset identification,
- zone and trust-boundary mapping,
- expected flow definition,
- defensive service inventory,
- packet capture of representative traffic,
- risk identification and quick wins.

## What Was Tested and How

To validate the baseline network configuration before applying any firewall
hardening, several connectivity and service tests were performed across the
environment.

### 1. Host Configuration Verification

Each machine was inspected to confirm correct network configuration.

Commands used:

hostname
ip addr
ip route
ss -tulpn

These commands allowed verification of:

- correct IP addresses for each host
- correct routing configuration
- exposed network services
- listening ports

The expected network configuration observed was:

| Host | IP Address | Role |
|-----|-----|-----|
gw-fw | 10.10.10.1 / 10.10.20.1 | Firewall / router |
srv-web | 10.10.20.10 | Web server in DMZ |
sensor-ids | 10.10.20.50 | IDS monitoring host |
client (kali) | 10.10.10.10 | LAN client |

---

### 2. Gateway Forwarding Validation

The firewall gateway must route traffic between the LAN and the DMZ.

Command used:

sysctl net.ipv4.ip_forward

Result:

Packet forwarding is enabled (`net.ipv4.ip_forward = 1`), allowing routing
between networks.

---

### 3. Basic Connectivity Tests

Connectivity between hosts was validated using ICMP.

Command used:

ping -c 3 10.10.10.1

This verified that the client could reach the gateway in the LAN.

Command used:

ping -c 3 10.10.20.10

This confirmed that packets were successfully routed through the firewall
from the LAN to the DMZ.

---

### 4. Web Service Reachability

The web service hosted on the DMZ server was tested using HTTP requests.

Command used:

curl http://10.10.20.10

Result:

The default nginx web page was returned, confirming that the HTTP service
is reachable and operational.

---

### 5. Remote Administrative Access

Secure remote access to the DMZ server was validated.

Command used:

ssh student@10.10.20.10 "hostname"

Result:

The hostname of the remote system (`srv-web`) was returned, confirming that
the SSH service is accessible.

---

### 6. Service Exposure Verification

Services exposed by the web server were identified using:

ss -tulpn

Observed services included:

- TCP port 80 (nginx web server)
- TCP port 22 (SSH)

---

### 7. Defensive Inventory Scan

A basic network scan was performed to identify open ports on the DMZ server.

Command used:

nmap -sS -sV -p 1-1000 10.10.20.10

The results were saved to:

evidence/nmap_srvweb.txt

This scan confirmed the externally visible services running on the server.

---

### 8. Network Traffic Baseline Capture

A baseline packet capture was collected using the IDS sensor.

Command executed on sensor-ids:

sudo tcpdump -i enp0s3 -w evidence/baseline.pcap -nn

While the capture was running, network traffic was generated from the client:

curl http://10.10.20.10  
ping -c 3 10.10.20.10  
ssh student@10.10.20.10  

The resulting capture file provides evidence of baseline traffic flows
between the LAN and the DMZ.



### Host and route identification
On each VM, the following commands were used:
- `hostname`
- `ip addr`
- `ip route`
- `ss -tulpn`

### Reachability validation
From `client`, the following checks were performed:
- connectivity to `gw-fw` on the LAN side,
- connectivity to `srv-web` through `gw-fw`,
- HTTP access to `srv-web`,
- SSH access to `srv-web` when needed.

### Defensive inventory
A defensive service scan was run from `client` against `srv-web` only:
- `nmap -sS -sV -p 1-1000 10.10.20.10`

### Baseline traffic capture
A packet capture was recorded on `sensor-ids` in promiscuous mode while generating representative traffic from `client`, including:
- HTTP,
- HTTPS if available,
- ICMP,
- SSH,
- DNS if configured.

## Delivered artifacts

- `diagram.pdf`
- `reachability_matrix.csv`
- `report.md`
- `tests/commands.txt`
- `tests/TEST_CARDS.md`
- `evidence/nmap_srvweb.txt`
- `evidence/baseline.pcap`
- `appendix/failure_modes.md`

## Known limitations

- The analysis is limited to the authorized lab environment only.
- The defensive scan was restricted to `srv-web` and to ports `1-1000`.
- DNS and NTP observations depend on whether these services were configured in the lab.
- HTTPS observations depend on whether TLS was already enabled on `srv-web`.
- Packet capture visibility depends on correct promiscuous mode configuration on `sensor-ids`.

## Conclusion

TD1 established the initial evidence-based network baseline required for subsequent hardening work. The resulting map, flow matrix, capture, and risk analysis provide the reference point for firewalling, IDS deployment, TLS hardening, and later validation tasks.
