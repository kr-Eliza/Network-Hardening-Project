# TD2 — Firewall Policy
Network Hardening Lab

## 1. Purpose

This document defines the intended firewall policy for the TD2 lab environment.
The goal is to translate the baseline flow analysis from TD1 into a minimal,
auditable and enforceable network filtering policy on the gateway `gw-fw`.

The firewall is implemented as a **network-based policy enforcement point**
on the forwarding path between the LAN and the DMZ.

The policy follows a **least privilege** approach:
only explicitly justified traffic is allowed, and all other traffic is denied
by default.

---

## 2. Scope

This policy applies only to the lab environment and only to the following
virtual machines:

- `client` in the LAN
- `gw-fw` as the gateway / firewall
- `srv-web` in the DMZ
- `sensor-ids` in the DMZ

No traffic outside the lab environment is in scope.

---

## 3. Zones

| Zone | Network | Assets | Trust level |
|---|---|---|---|
| LAN | 10.10.10.0/24 | client (10.10.10.10) | trusted |
| DMZ | 10.10.20.0/24 | srv-web (10.10.20.10), sensor-ids (10.10.20.50) | semi-trusted |
| Gateway | 10.10.10.1 / 10.10.20.1 | gw-fw | enforcement point |

### Zone descriptions

**LAN**  
The LAN contains the administrative and testing workstation used to generate
traffic, perform validation and access services hosted in the DMZ.

**DMZ**  
The DMZ contains exposed service hosts. In this lab, `srv-web` provides the
web service and SSH access, while `sensor-ids` is used for passive monitoring
and packet capture.

**Gateway**  
`gw-fw` connects both subnets and acts as the trust boundary. All inter-zone
traffic must traverse this host and is subject to firewall filtering.

---

## 4. Security Objectives

The firewall policy is designed to achieve the following objectives:

- allow only justified flows identified during TD1
- block non-required traffic between LAN and DMZ
- protect the gateway itself from unauthorized access
- preserve administrative connectivity to the gateway
- log denied traffic for verification and troubleshooting
- maintain a ruleset that is minimal, readable and traceable to the flow matrix

---

## 5. Default Stance

The default security posture is deny by default.

### FORWARD chain
**Default action: DROP**

All traffic crossing from one zone to another is denied unless explicitly
allowed by policy.

### INPUT chain
**Default action: DROP**

Traffic destined to `gw-fw` itself is denied unless explicitly allowed.

### OUTPUT chain
**Default action: ACCEPT**

Traffic originating from `gw-fw` is allowed, as the gateway may need to
communicate with both connected subnets for administration and troubleshooting.

---

## 6. General Rules

The following general principles apply to the policy:

1. **Stateful handling is enabled**  
   Return traffic for established and related connections is allowed.

2. **Loopback traffic is always allowed**  
   Local services on `gw-fw` must continue to operate correctly.

3. **Rules must be scoped**  
   Each allow rule must specify source, destination and service/port whenever
   possible.

4. **No broad any-any allow rules**  
   Rules such as "allow all" or unrestricted source/destination policies are
   not permitted.

5. **Policy must remain reversible**  
   A rollback procedure must be available to restore permissive connectivity.

---

## 7. Allow-List Policy Statements

The following flows are allowed because they are justified by the baseline
environment and by the TD1 reachability matrix.

### 7.1 Administrative access to the gateway

- **ALLOW** LAN → `gw-fw` TCP/22  
  Purpose: administrative access to the gateway during the lab  
  Source: `10.10.10.0/24`  
  Destination: `10.10.10.1`  
  Rationale: prevents administrator lockout and allows safe firewall management

### 7.2 Web service access

- **ALLOW** LAN → DMZ `srv-web` TCP/80  
  Purpose: HTTP web access and application testing  
  Source: `10.10.10.0/24`  
  Destination: `10.10.20.10`  
  Rationale: baseline service identified in TD1

### 7.3 HTTPS service path

- **ALLOW** LAN → DMZ `srv-web` TCP/443  
  Purpose: HTTPS access if TLS is configured later  
  Source: `10.10.10.0/24`  
  Destination: `10.10.20.10`  
  Rationale: prepares the firewall path for encrypted web service testing

### 7.4 Administrative access to the web server

- **ALLOW** LAN → DMZ `srv-web` TCP/22  
  Purpose: remote administration during the lab  
  Source: `10.10.10.0/24`  
  Destination: `10.10.20.10`  
  Rationale: SSH was identified as an exposed and required service in TD1

### 7.5 Diagnostic ICMP

- **ALLOW** LAN → DMZ ICMP echo-request  
  Purpose: connectivity verification and diagnostics  
  Source: `10.10.10.0/24`  
  Destination: `10.10.20.0/24`  
  Rationale: useful for troubleshooting and test validation  
  Constraint: rate limited

### 7.6 Established / related return traffic

- **ALLOW** established, related traffic  
  Purpose: stateful return traffic for permitted flows  
  Rationale: ensures responses to valid sessions are not blocked

---

## 8. Explicitly Denied / Not Allowed Flows

The following traffic categories are not justified by the baseline and must be
blocked by default:

- LAN → DMZ traffic to ports not explicitly allowed
- DMZ → LAN initiated traffic
- DMZ → `gw-fw` administrative traffic unless explicitly justified
- traffic to random high ports on `srv-web`
- Telnet (TCP/23)
- MySQL (TCP/3306)
- DNS to `srv-web` if not intentionally deployed
- any non-documented service not present in the allow-list

This deny-by-default posture is the main control objective of the TD2 firewall.

---

## 9. Logging Strategy

Logging is required to verify that denied traffic is actually blocked and to
provide evidence for the lab report.

### 9.1 Denied forward traffic
Denied traffic crossing the gateway must be logged with a dedicated prefix,
for example:

- `NFT_FWD_DENY`

### 9.2 Denied input traffic
Denied traffic directed at the gateway itself must be logged with a dedicated
prefix, for example:

- `NFT_IN_DENY`

### 9.3 Log rate limiting
Logging must be rate-limited in order to avoid flooding the system logs and
degrading performance.

### 9.4 Sensitive administrative traffic
Administrative access rules, especially SSH, should be identifiable and
auditable.

---

## 10. Rule Quality Requirements

Each firewall rule must satisfy the following requirements:

- traceable to a requirement from TD1
- narrow in scope
- understandable without ambiguity
- exported to a persistent evidence file
- testable using positive or negative verification commands

The final ruleset must remain short and readable.

---

## 11. Exception Handling

Any new allow rule must satisfy all of the following:

- be requested explicitly
- have a documented purpose
- have an identified owner
- be reviewed for necessity
- be tested after implementation
- be removed if no longer justified

Temporary exceptions should be reviewed and removed after the lab if they are
not part of the approved baseline.

---

## 12. Known Limitations

This policy intentionally does not implement:

- fine-grained outbound egress restrictions from `gw-fw`
- deep application inspection
- host-based firewall rules on `srv-web`
- IDS blocking logic
- NAT or internet access control

These controls are outside the scope of this TD and may be addressed in later
labs.

---

## 13. Summary

This policy enforces a simple but strong rule:

- permit only the minimum traffic required for the lab
- protect the gateway itself
- deny everything else by default
- collect logging evidence for blocked traffic

This policy is the reference intent document for the nftables implementation
applied on `gw-fw`.