TD1 — Baseline Security Assessment
Network Hardening Lab

------------------------------------------------------------
1. Introduction
------------------------------------------------------------

The objective of this lab is to establish a baseline understanding of a small
networked environment before applying any hardening measures. The exercise
focuses on identifying network connectivity, exposed services, and potential
security weaknesses in the current configuration.

The lab environment consists of two logical security zones separated by a
gateway acting as a firewall. The LAN network contains the client host used
for testing and administration, while the DMZ contains the web server and an
IDS monitoring sensor.

The goal of this baseline assessment is to:

- verify the network topology
- confirm host configuration and routing
- identify exposed services
- collect baseline traffic evidence
- document potential risks prior to firewall implementation

All results gathered during this phase will be used later to design a proper
network hardening policy.

------------------------------------------------------------
2. Network Architecture
------------------------------------------------------------

The network topology consists of two distinct zones separated by a gateway.

LAN Network
10.10.10.0/24

DMZ Network
10.10.20.0/24

The gateway machine "gw-fw" acts as the trust boundary between the two zones
and routes traffic between them.

Hosts in the environment:

Host: client
IP: 10.10.10.10
Role: Testing and scanning client

Host: gw-fw
IP: 10.10.10.1 / 10.10.20.1
Role: Gateway and firewall

Host: srv-web
IP: 10.10.20.10
Role: Web server located in DMZ

Host: sensor-ids
IP: 10.10.20.50
Role: Network monitoring sensor

Gateway interfaces:

LAN interface
enp0s3 → 10.10.10.1/24

DMZ interface
enp0s8 → 10.10.20.1/24

Packet forwarding is enabled:

net.ipv4.ip_forward = 1

This allows the gateway to route traffic between the LAN and DMZ networks.

------------------------------------------------------------
3. Host Configuration Verification
------------------------------------------------------------

Each host was inspected to confirm proper network configuration.

Commands used:

hostname
ip addr
ip route
ss -tulpn

These commands allowed verification of:

- correct IP addresses
- correct routing tables
- listening services and ports

Observed configuration summary:

client → 10.10.10.10
gw-fw → 10.10.10.1 / 10.10.20.1
srv-web → 10.10.20.10
sensor-ids → 10.10.20.50

Routing tables confirmed that the gateway is used to reach the other network.

Example client routing entry:

10.10.20.0/24 via 10.10.10.1

------------------------------------------------------------
4. Service Exposure
------------------------------------------------------------

The services exposed by the DMZ server were inspected using:

ss -tulpn

The following services were observed on srv-web.

Service: SSH
Port: TCP 22
Purpose: Remote administration

Service: HTTP
Port: TCP 80
Purpose: nginx web server

The HTTP service returns the default nginx landing page.

Example request from the client:

curl http://10.10.20.10

Result:

<title>Welcome to nginx!</title>

This confirms that the web server is operational and reachable from the LAN.

------------------------------------------------------------
5. Connectivity Validation
------------------------------------------------------------

Several connectivity tests were performed to ensure proper network operation.

LAN connectivity test:

ping -c 3 10.10.10.1

Result:

3 packets transmitted, 3 received, 0% packet loss

The client can successfully reach the gateway.

Cross-zone connectivity test:

ping -c 3 10.10.20.10

Result:

3 packets transmitted, 3 received, 0% packet loss

This confirms that routing between the LAN and DMZ networks is functional.

The TTL value of 63 indicates that packets are routed through the gateway.

HTTP service validation:

curl http://10.10.20.10

The nginx web page was successfully returned.

SSH remote access validation:

ssh student@10.10.20.10 "hostname"

Result:

srv-web

Remote administrative access is operational.

------------------------------------------------------------
6. Defensive Inventory Scan
------------------------------------------------------------

A network scan was performed from the client host using nmap.

Command:

nmap -sS -sV -p 1-1000 10.10.20.10

The results were saved in:

evidence/nmap_srvweb.txt

The scan confirmed the following open ports:

22 → SSH
80 → HTTP

No unexpected services were discovered.

------------------------------------------------------------
7. Network Baseline Capture
------------------------------------------------------------

A baseline packet capture was collected using the IDS monitoring host.

Command executed on sensor-ids:

sudo tcpdump -i enp0s3 -w evidence/baseline.pcap -nn

During the capture, traffic was generated from the client:

curl http://10.10.20.10
ping -c 3 10.10.20.10
ssh student@10.10.20.10

The capture file contains:

- ICMP traffic (ping)
- HTTP requests and responses
- SSH session establishment

This capture represents normal baseline traffic before firewall rules
are applied.

------------------------------------------------------------
8. Security Observations
------------------------------------------------------------

Observation 1 — HTTP traffic is unencrypted

The web service uses HTTP without encryption.

Impact:
Sensitive information could potentially be intercepted.

Mitigation:
Enable HTTPS using TLS certificates.


Observation 2 — No firewall filtering policy

The gateway routes traffic but no filtering rules are currently applied.

Impact:
Unrestricted communication increases the attack surface.

Mitigation:
Implement a default deny firewall policy using nftables.


Observation 3 — SSH exposed

SSH is accessible from the LAN network.

Impact:
Potential exposure to brute force attacks.

Mitigation:
Restrict SSH access by source IP and enforce stronger authentication.


Observation 4 — Passive monitoring only

The IDS sensor currently performs passive traffic capture only.

Impact:
Intrusions may not be automatically detected.

Mitigation:
Deploy IDS rules using tools such as Suricata or Snort.

------------------------------------------------------------
9. Risk Summary
------------------------------------------------------------

Risk: HTTP cleartext communication
Impact: High
Mitigation: Enable HTTPS

Risk: No firewall filtering
Impact: Critical
Mitigation: Implement firewall policy

Risk: SSH exposure
Impact: Medium
Mitigation: Restrict source access

Risk: Limited monitoring
Impact: Medium
Mitigation: Deploy IDS rules

------------------------------------------------------------
10. Failure Modes Encountered
------------------------------------------------------------

Several issues were encountered during the configuration of the virtual
machines and network environment.

Failure Mode 1 — Missing evidence directory

Initial packet capture attempts failed because the destination directory
did not exist.

Error observed:

tcpdump: evidence/baseline.pcap: No such file or directory

Resolution:

mkdir -p evidence


Failure Mode 2 — IDS traffic visibility

The IDS host initially risked capturing only its own traffic.

Cause:

VirtualBox networks do not automatically allow passive monitoring of
traffic between VMs.

Resolution:

Promiscuous mode was enabled for the IDS adapter:

VirtualBox → Network Adapter → Advanced → Promiscuous Mode → Allow All


Failure Mode 3 — Routing configuration

Cross-network connectivity required verification of routing tables.

Resolution:

Static routes were configured to ensure communication between LAN and DMZ.


Failure Mode 4 — Packet forwarding

The gateway required verification that IP forwarding was enabled.

Command used:

sysctl net.ipv4.ip_forward

Result:

net.ipv4.ip_forward = 1


Failure Mode 5 — Interface identification

Different VMs used different interface names such as:

eth0
enp0s3
enp0s8

Interfaces had to be identified using:

ip addr


Failure Mode 6 — Traffic generation for capture

Initial packet captures contained little traffic.

Resolution:

Traffic was manually generated from the client:

curl http://10.10.20.10
ping 10.10.20.10
ssh student@10.10.20.10


------------------------------------------------------------
11. Conclusion
------------------------------------------------------------

The baseline analysis confirms that the network environment is operational
and correctly configured in terms of connectivity and routing.

All hosts are reachable and the expected services are running on the DMZ
web server.

However, several security weaknesses were identified, including the absence
of a firewall filtering policy and the use of unencrypted HTTP communication.

These findings will guide the implementation of firewall rules and service
hardening in the next phase of the lab.

The evidence collected during this phase, including packet captures and
service scans, provides a reliable reference point for comparing the system
state before and after hardening measures are applied.