
# Appendix — Failure Modes (TD2)

This appendix documents potential failure modes encountered during the
implementation and verification of the firewall policy in TD2.

Each issue is analyzed with its symptoms, root cause, and resolution.

The goal is to document troubleshooting steps and ensure reproducibility
of the firewall deployment process.

---

# FM-01 — Administrator lockout from gw-fw

## Symptoms

After applying restrictive firewall rules, SSH access to the gateway
(`gw-fw`) could be lost.

Example:

ssh student@10.10.10.1

Result:

Connection timed out

This situation would prevent administrators from modifying or reverting
the firewall configuration.

## Root Cause

If the INPUT chain is set to `policy drop` before allowing SSH access,
the firewall will block incoming SSH connections.

Example incorrect sequence:

1. set INPUT policy to DROP
2. forget to add SSH allow rule

## Resolution

Administrative access rules must always be configured **before**
activating restrictive policies.

Example rule:

```

ip saddr 10.10.10.0/24 tcp dport 22 accept

```

This rule ensures SSH access from the LAN network.

---

# FM-02 — Forwarded traffic blocked unexpectedly

## Symptoms

After deploying the firewall, services such as HTTP or SSH to `srv-web`
may stop working.

Example:

```

curl [http://10.10.20.10](http://10.10.20.10)

```

Result:

Connection timed out.

## Root Cause

The FORWARD chain default policy is set to `DROP`.  
If the allow rules for specific services are missing or incorrectly
configured, legitimate traffic will be blocked.

Common causes include:

• missing rule for the service port  
• incorrect destination address  
• rule placed after a blocking rule  

## Resolution

Verify that explicit allow rules exist for each required service.

Example HTTP rule:

```

ip saddr 10.10.10.0/24 ip daddr 10.10.20.10 tcp dport 80 accept

```

After adding the correct rule, connectivity is restored.

---

# FM-03 — HTTPS test appears to fail

## Symptoms

Testing HTTPS connectivity may produce no visible output.

Example command:

```

curl -skI [https://10.10.20.10](https://10.10.20.10)

```

Result:

No response or connection refusal.

## Root Cause

The firewall allows TCP port 443, but the web server does not run an
HTTPS service.

The nginx configuration on `srv-web` only listens on port 80.

Therefore the firewall is functioning correctly but the application
service is not available.

## Resolution

This behavior was interpreted as:

• firewall path allowed  
• service not configured  

No firewall modification was required.

---

# FM-04 — ICMP requests to the gateway blocked

## Symptoms

Ping requests sent to the gateway receive no reply.

Example:

```

ping -c 2 10.10.10.1

```

Result:

```

2 packets transmitted, 0 received

```

## Root Cause

The firewall INPUT chain uses a default policy of `DROP` and does not
include a rule allowing ICMP echo requests.

This configuration protects the firewall host itself.

## Resolution

This behavior is expected and consistent with a hardened firewall
configuration.

No change was required.

---

# FM-05 — Negative tests produce connection timeouts

## Symptoms

During negative testing, blocked ports may return a timeout rather than
a connection refused message.

Example:

```

nc -vz -w 3 10.10.20.10 3306

```

Result:

```

Connection timed out

```

## Root Cause

The firewall drops packets silently rather than rejecting them.

With a DROP policy, the client receives no response and eventually
times out.

## Resolution

Timeout responses confirm that the firewall is enforcing the default
deny policy correctly.

---

# FM-06 — No evidence of blocked traffic in logs

## Symptoms

After running negative tests, the system logs may appear empty.

Example command:

```

journalctl -k | grep NFT_FWD_DENY

```

Result:

No output.

## Root Cause

Logging rules may not have been configured correctly, or the tests may
not have generated sufficient traffic to trigger logging.

Another possibility is that the logging rule was placed after a rule
that already dropped the packet.

## Resolution

Ensure that logging rules are placed before the final drop behavior and
include rate limiting.

Example:

```

counter log prefix "NFT_FWD_DENY " limit rate 10/minute

```

After correct placement, denied packets appear in system logs.

---

# Summary

The firewall implementation in TD2 introduces several potential failure
modes primarily related to rule ordering, missing allow rules, and
interpretation of firewall behavior.

The troubleshooting process confirmed that:

• administrative access to the firewall must always be preserved  
• required services must be explicitly allowed  
• the default deny policy blocks all other traffic  
• timeout responses are expected with DROP policies  
• firewall logging provides valuable operational visibility  

Documenting these scenarios ensures that the firewall configuration can
be safely deployed and verified in future environments.
```
