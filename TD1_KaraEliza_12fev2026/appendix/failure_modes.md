TD1 — Failure Modes Encountered
Network Hardening Lab

---

## Introduction

During the setup and execution of the virtualized lab environment several
technical issues were encountered. These issues occurred mainly during the
deployment of the virtualization infrastructure and the configuration of the
multi-zone network architecture.

The lab environment is composed of four virtual machines connected through
isolated virtual networks representing two security zones:

* LAN network
* DMZ network

Each virtual machine performs a specific role within the architecture:

* client (LAN workstation)
* gw-fw (gateway and firewall)
* srv-web (web server located in the DMZ)
* sensor-ids (network monitoring sensor)

This section documents the main technical difficulties encountered during
the setup process, their causes, and the solutions implemented.

---

1. Host System Graphics Initialization Issues

---

Problem

After installing Kali Linux on the host system, the graphical environment did
not load correctly and the system repeatedly returned to the login screen.

Cause

This issue was related to GPU initialization problems involving the AMD
graphics driver and compatibility between the kernel and the display manager.

Resolution

The graphical environment was started manually using the XFCE session.

Command used:

startxfce4

This confirmed that the issue was related to the display manager configuration
rather than a failure of the operating system installation.

---

2. VirtualBox Kernel Module Configuration

---

Problem

While preparing the virtualization environment, VirtualBox kernel modules
failed to load correctly.

Cause

VirtualBox requires kernel modules to interact with the host operating system.
If these modules are not loaded or compiled correctly, the hypervisor cannot
start virtual machines.

Resolution

The correct kernel module was loaded manually.

Command used:

sudo modprobe vboxdrv

Additionally, the required kernel headers were installed to ensure that the
VirtualBox modules could be compiled properly.

---

3. Virtual Network Configuration in VirtualBox

---

Problem

Initial communication between virtual machines failed due to incorrect virtual
network assignments.

Cause

VirtualBox internal networks must match exactly across virtual machines.
If a VM is attached to an incorrect network name, it becomes isolated from
other hosts.

Resolution

Network adapters were reviewed and aligned with the intended network topology.

Final configuration:

client      → NH-LAN
gw-fw       → NH-LAN + NH-DMZ
srv-web     → NH-DMZ
sensor-ids  → NH-DMZ

Once the network assignments were corrected, connectivity between hosts
was restored.

---

4. Static Routing Between Network Zones

---

Problem

Communication between the LAN and DMZ networks initially failed.

Cause

Each host must know how to reach remote subnets through the gateway.
Without correct routing configuration, packets cannot be delivered across
network boundaries.

Resolution

Routing tables were verified and corrected to ensure that traffic destined
for the DMZ was forwarded to the gateway.

Example routing entry observed on the client machine:

10.10.20.0/24 via 10.10.10.1

This ensured that traffic for the DMZ network was routed through the gateway.

---

5. Gateway Packet Forwarding Configuration

---

Problem

Hosts located in different network zones could not communicate even when
routing tables were correctly configured.

Cause

Linux systems do not forward packets between network interfaces unless
IP forwarding is explicitly enabled.

Resolution

The forwarding configuration was verified on the gateway system.

Command used:

sysctl net.ipv4.ip_forward

Result:

net.ipv4.ip_forward = 1

This confirmed that packet forwarding was enabled and routing between
network zones was possible.

---

6. IDS Traffic Visibility in Virtualized Environment

---

Problem

The IDS monitoring host initially failed to observe traffic exchanged between
the client and the web server.

Cause

VirtualBox restricts packet visibility between virtual machines unless
promiscuous mode is enabled on the network adapter.

Resolution

Promiscuous mode was enabled on the IDS network adapter.

Configuration path:

VirtualBox → Network Adapter → Advanced → Promiscuous Mode → Allow All

This allowed the IDS sensor to capture traffic exchanged between hosts in
the DMZ network.

---

7. Service Availability on the Web Server

---

Problem

Connectivity tests can fail if required services are not active on the
destination host.

Cause

The web server must run both the HTTP service (nginx) and the SSH daemon
in order to respond to application and administrative requests.

Resolution

Service availability was verified on the web server using:

ss -tulpn
systemctl status nginx
systemctl status ssh

The verification confirmed that:

* SSH was listening on TCP port 22
* nginx was listening on TCP port 80

---

8. Baseline Traffic Generation for Packet Capture

---

Problem

Initial network captures contained very limited traffic.

Cause

Packet capture tools require active communication between hosts in order to
produce meaningful network traces.

Resolution

Traffic was manually generated from the client host using the following
commands:

curl http://10.10.20.10
ping -c 3 10.10.20.10
ssh student@10.10.20.10

These commands produced HTTP, ICMP, and SSH traffic that could then be
observed within the baseline packet capture.

---

## Conclusion

The issues encountered during the lab setup were primarily related to common
challenges associated with virtualized networking environments.

Key areas of difficulty included:

* virtualization driver configuration
* virtual network topology alignment
* static routing configuration
* packet forwarding on the gateway
* traffic visibility within virtualized networks
* service availability validation

Once these issues were identified and resolved, the lab environment operated
correctly and the baseline connectivity between all hosts was successfully
validated.

This troubleshooting process improved understanding of Linux networking,
virtualized infrastructure behavior, and packet capture methodologies used
in network security monitoring.
