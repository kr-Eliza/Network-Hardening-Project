# TD2 — Test Cards
Firewall Policy Verification

Each test card validates a security claim derived from the firewall policy
implemented on `gw-fw`. Positive tests confirm that allowed flows still work,
while negative tests confirm that the default deny policy blocks non-authorized
traffic.

---

## TD2-T01 — HTTP access from LAN to srv-web is allowed

**Claim**

HTTP traffic from the LAN client to the web server in the DMZ is permitted by the firewall.

**Test**

From client:

curl -sI http://10.10.20.10 | head -5

**Expected result**

HTTP response headers returned.

Example:

HTTP/1.1 200 OK  
Server: nginx/1.24.0 (Ubuntu)

**Evidence**

- tests/commands.txt  
- evidence/counters_after.txt

---

## TD2-T02 — SSH access from LAN to srv-web is allowed

**Claim**

Administrative SSH access from the LAN to the web server is permitted.

**Test**

From client:

ssh -o ConnectTimeout=3 student@10.10.20.10 "hostname"

**Expected result**

Successful SSH login and hostname output.

Example:

srv-web

**Evidence**

- tests/commands.txt  
- evidence/counters_after.txt

---

## TD2-T03 — ICMP diagnostics from LAN to DMZ are allowed

**Claim**

ICMP echo requests from LAN to DMZ hosts are allowed for diagnostics.

**Test**

From client:

ping -c 2 10.10.20.10

**Expected result**

Replies received.

Example:

2 packets transmitted, 2 received, 0% packet loss

**Evidence**

- tests/commands.txt  
- evidence/counters_after.txt

---

## TD2-T04 — Administrative SSH access to gw-fw is preserved

**Claim**

Firewall configuration must not break administrative access to the gateway.

**Test**

From client:

ssh -o ConnectTimeout=3 student@10.10.10.1 "hostname"

**Expected result**

Successful SSH login.

Example:

gw-fw

**Evidence**

- tests/commands.txt

---

## TD2-T05 — Default deny blocks non-authorized ports

**Claim**

Ports not listed in the allow policy must be blocked.

**Test**

From client:

nc -vz -w 3 10.10.20.10 12345  
nc -vz -w 3 10.10.20.10 3306  
nc -vz -w 3 10.10.20.10 23

**Expected result**

Connection timeout.

Example:

Connection timed out

**Evidence**

- tests/commands.txt  
- evidence/counters_after.txt

---

## TD2-T06 — DMZ initiated connections to LAN are blocked

**Claim**

Hosts in the DMZ cannot initiate connections to the LAN.

**Test**

From srv-web:

nc -vz -w 3 10.10.10.10 22

**Expected result**

Connection timeout.

Example:

connect to 10.10.10.10 port 22 (tcp) timed out

**Evidence**

- tests/commands.txt  
- evidence/deny_logs.txt

---

## TD2-T07 — Firewall generates logs for denied traffic

**Claim**

Denied packets are logged by the firewall.

**Test**

From gw-fw:

sudo journalctl -k --since "1 hour ago" | grep "NFT_IN_DENY"

**Expected result**

Log entries containing denied packets.

Example:

NFT_IN_DENY SRC=10.10.10.10 DST=10.10.10.1 PROTO=ICMP TYPE=8

**Evidence**

- evidence/deny_logs.txt

---

## Summary

The test cards confirm that:

- Allowed services (HTTP, SSH, ICMP) remain functional.
- Administrative access to the gateway is preserved.
- Unauthorized traffic is blocked by the default deny policy.
- Firewall enforcement is observable through rule counters and logs.