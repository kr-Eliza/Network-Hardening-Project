

# 1. Introduction

During the execution of TD5, multiple technical issues were encountered across networking, routing, and IPsec configuration phases. These failure modes reflect realistic deployment challenges in multi-site infrastructures and highlight the importance of systematic troubleshooting.

The main categories of issues observed were:

* Network misconfiguration (IP addressing / interfaces)
* Routing inconsistencies
* IPsec tunnel establishment failures
* Residual configuration conflicts (xfrm policies, routes)
* Service management issues (strongSwan)

Each failure mode is documented below with its symptoms, root cause, impact, and resolution.

---

# 2. Failure Modes

---

## FM-01 — Incorrect WAN Interface Addressing

### Description

The WAN interfaces on the gateways were incorrectly configured, leading to communication failure between `siteA-gw` and `siteB-gw`.

### Symptoms

* IPsec logs:

```text
error writing to socket: Network is unreachable
sending packet: from 10.10.99.1 to 10.10.99.2
```

* Ping failure:

```bash
ping -c 2 10.10.99.2
→ Destination Host Unreachable
```

* `ip -br a` showed incorrect addressing:

```text
siteA-gw:
enp0s8 → 10.10.20.1 (should be 10.10.99.1)

siteB-gw:
missing 10.10.99.2
```

### Root Cause

Interfaces inherited incorrect IP configuration from previous TD (DMZ/LAN reused instead of WAN).
WAN segment (10.10.99.0/24) was not properly assigned.

### Impact

* No connectivity between gateways
* IPsec tunnel could not initiate
* All inter-site communication failed

### Resolution

Reassigned correct IPs:

```bash
# siteA-gw
ip addr flush dev enp0s8
ip addr add 10.10.99.1/24 dev enp0s8

# siteB-gw
ip addr flush dev enp0s8
ip addr add 10.10.99.2/24 dev enp0s8
```

---

## FM-02 — Missing WAN Connectivity Before IPsec

### Description

IPsec was configured and started before validating basic WAN connectivity.

### Symptoms

* IPsec stuck in `CONNECTING`
* No `ESTABLISHED` state
* Repeated retries in logs

### Root Cause

Failure to perform pre-flight checks:

```bash
ping 10.10.99.2
```

### Impact

* Misleading debugging effort on IPsec
* Time loss troubleshooting wrong layer

### Resolution

Validated connectivity before IPsec:

```bash
ping -c 2 10.10.99.2
```

---

## FM-03 — Residual IPsec Policies (xfrm) After Stop

### Description

Even after stopping IPsec, traffic remained blocked due to leftover kernel policies.

### Symptoms

* Ping failed even after:

```bash
ipsec stop
```

* Network behavior inconsistent

### Root Cause

IPsec policies (`xfrm`) were still active in the kernel.

### Impact

* Traffic silently dropped
* Debugging complexity increased

### Resolution

Flushed policies:

```bash
ip xfrm state flush
ip xfrm policy flush
```

---

## FM-04 — Conflict Between Static Routing and IPsec

### Description

Static routes were still present after enabling IPsec, causing conflicts.

### Symptoms

* Ping failure after IPsec activation:

```text
Destination Host Unreachable
```

* Gateway responding instead of remote host

### Root Cause

Traffic attempted to use static route instead of IPsec policy.

### Impact

* Tunnel not used
* Traffic dropped or misrouted

### Resolution

Removed conflicting routes:

```bash
# siteA-gw
ip route del 10.10.20.0/24 via 10.10.99.2

# siteB-gw
ip route del 10.10.10.0/24 via 10.10.99.1
```

---

## FM-05 — IPsec Tunnel Not Established

### Description

Tunnel remained in `CONNECTING` state.

### Symptoms

* `ipsec statusall`:

```text
CONNECTING
```

* No ESP traffic visible

### Root Cause

Underlying network issue (WAN unreachable)

### Impact

* No encrypted communication
* No inter-site connectivity

### Resolution

Fixed WAN configuration → restarted IPsec:

```bash
systemctl restart strongswan-starter
ipsec restart
```

---

## FM-06 — Misinterpretation of Expected Behavior After IPsec

### Description

It was initially assumed that ping should fail after IPsec activation.

### Symptoms

* Expectation of packet loss after enabling tunnel

### Root Cause

Misunderstanding of IPsec behavior:

* IPsec encrypts traffic
* It does NOT block connectivity

### Impact

* Incorrect validation criteria

### Resolution

Correct understanding:

| State        | Expected                 |
| ------------ | ------------------------ |
| Before IPsec | Ping works, ICMP visible |
| After IPsec  | Ping works, ESP visible  |

---

## FM-07 — StrongSwan Service Mismanagement

### Description

Incorrect service name used for restart.

### Symptoms

```bash
systemctl restart strongswan
→ Unit not found
```

### Root Cause

Wrong service name (distribution uses `strongswan-starter`)

### Impact

* IPsec not restarted
* Configuration not applied

### Resolution

```bash
systemctl restart strongswan-starter
```

---

## FM-08 — Incorrect Debug Focus (IPsec vs Network)

### Description

Debugging was initially focused on IPsec instead of network layer.

### Symptoms

* Investigating configs instead of connectivity
* Ignoring ping failures on WAN

### Root Cause

Incorrect troubleshooting methodology

### Impact

* Increased debugging time
* Confusion in diagnosis

### Resolution

Adopted layered approach:

1. Interface
2. Routing
3. Connectivity
4. IPsec

---

## FM-09 — ARP Resolution Failure

### Description

ARP requests were observed without replies.

### Symptoms

```text
ARP Request who-has 10.10.20.1 tell 10.10.20.10
(no reply)
```

### Root Cause

Incorrect interface/IP mapping

### Impact

* No Layer 2 resolution
* Traffic blocked

### Resolution

Corrected interface addressing

---

## FM-10 — Partial Connectivity (Gateway OK, Client Fails)

### Description

`siteA-gw` could reach `siteB-srv`, but client could not.

### Symptoms

* GW → OK
* Client → FAIL

### Root Cause

Missing route on client

### Impact

* End-to-end communication broken

### Resolution

```bash
ip route add 10.10.20.0/24 via 10.10.10.1
```

---

# 3. Key Lessons Learned

---

## 🔹 Always Validate Network First

Before configuring IPsec:

```bash
ping WAN
ping inter-site
```

---

## 🔹 IPsec Depends on Underlying Connectivity

If WAN fails → IPsec fails

---

## 🔹 Remove Static Routes When Using IPsec

Avoid routing conflicts

---

## 🔹 Flush xfrm Policies When Debugging

```bash
ip xfrm policy flush
```

---

## 🔹 Debug Layer by Layer

1. Interfaces
2. Routing
3. Connectivity
4. Security (IPsec)

---

# 4. Conclusion

The issues encountered during TD5 were representative of real-world deployment problems in secure network architectures. Most failures were not due to IPsec itself, but to underlying network misconfigurations.

This highlights a critical principle:

> Security mechanisms depend on correct network foundations.

Once the network was properly configured, IPsec functioned correctly, and encrypted communication was successfully established between the two sites.

---

