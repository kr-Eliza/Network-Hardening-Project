# TD1 — Test Cards
Network Hardening Lab — Baseline Validation

These test cards validate that the network topology, routing and exposed
services are functioning correctly before implementing firewall hardening.

Environment topology:

LAN
10.10.10.0/24
client (10.10.10.10)

↓

gw-fw
LAN: 10.10.10.1
DMZ: 10.10.20.1

↓

DMZ
srv-web (10.10.20.10)
sensor-ids (10.10.20.50)

---

# T01 — Gateway Reachability (LAN)

## Goal

Verify that the client can reach the firewall gateway in the LAN network.

## Command

ping -c 3 10.10.10.1

## Expected Result

The client receives ICMP replies from the gateway.

## Observed Result

3 packets transmitted, 3 received, 0% pack

PASS

---

# T02 — Routing Through Firewall (LAN → DMZ)

## Goal

Verify that traffic from the LAN can reach the DMZ server
## Command

ping -c 3 10.10.20.10

## Expected Result

ICMP replies 
3 packets transmitted, 3 received, 0% packet loss.

T
# T03 — HTTP Service Availability

## Goal

Verify that the HTTP service on srv-web is reachable from the client.

## Command

curl http://10.10.20.10

## Expected Result

The nginx default web page is returned.

## Observed Result

HTML response containing:

<title>Welcome to nginx!</title>

The default nginx page confirms that the web server is operational.

## Status

PASS

---

# T04 — SSH Remote Access

## Goal

Verify administrative remote access to the DMZ server.

## Command

ssh student@10.10.20.10 "hostname"

## Expected Result

The remote hostname of srv-web is returned.

## Observed Result

srv-web

## Status

PASS

---

# T05 — Gateway Packet Forwarding

## Goal

Ensure that the firewall gateway forwards packets between LAN and DMZ networks.

## Command

sysctl net.ipv4.ip_forward

## Expected Result

net.ipv4.ip_forward = 1

## Observed Result

Forwarding is enabled on gw-fw.

## Status

PASS

---

# T06 — Services Listening on srv-web

## Goal

Identify the services exposed by the web server.

## Command

ss -tulpn

## Expected Result

The server should expose:

• SSH (port 22)  
• HTTP (port 80)

## Observed Result

0.0.0.0:80  → nginx web server  
0.0.0.0:22  → OpenSSH server  

## Status

PASS

---

# T07 — Network Baseline Capture

## Goal

Collect baseline network traffic from the DMZ using the IDS sensor.

## Command (sensor-ids)

sudo tcpdump -i enp0s3 -w evidence/baseline.pcap -nn

## Traffic Generated from Client

curl http://10.10.20.10  
ping -c 3 10.10.20.10  
ssh student@10.10.20.10  

## Expected Result

Network packets are captured and stored in baseline.pcap.

## Observed Result

Capture file successfully created.

Captured traffic includes:

• ICMP (ping)  
• HTTP requests  
• SSH session establishment  

## Status

PASS

---

# Test Summary

| Test ID | Description | Result |
|-------|-------------|-------|
| T01 | LAN connectivity (client → gateway) | PASS |
| T02 | Routing LAN → DMZ | PASS |
| T03 | HTTP service availability | PASS |
| T04 | SSH remote access | PASS |
| T05 | Gateway forwarding enabled | PASS |
| T06 | Service exposure verification | PASS |
| T07 | Baseline network capture | PASS |

---

# Conclusion

All connectivity, routing and services are functional in the baseline
environment. The network is ready for firewall policy implementation
and further hardening analysis.
