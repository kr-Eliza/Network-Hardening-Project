```markdown
# TD3 — Failure Modes Encountered

This document describes the main technical issues encountered during the deployment and testing of the Suricata IDS in the TD3 laboratory environment.

Each issue is documented with its symptoms, root cause, and resolution.

---

# 1. Custom Rule File Not Loaded

## Symptom

The custom rule created to detect requests to `/admin` did not trigger any alerts, even when executing:

```

curl [http://10.10.20.10/admin](http://10.10.20.10/admin)

```

No alert with SID **9000001** appeared in:

```

/var/log/suricata/fast.log

```

## Root Cause

The file containing the custom rule (`local.rules`) was not referenced in the Suricata configuration file.

In `suricata.yaml`, the configuration initially contained only:

```

rule-files:

* suricata.rules

```

Therefore Suricata did not load the custom rule file.

## Resolution

The configuration was corrected by adding the custom rule file:

```

rule-files:

* suricata.rules
* local.rules

```

After restarting Suricata, the rule was correctly loaded.

---

# 2. Incorrect Rule File Path

## Symptom

Suricata returned the following error when testing the configuration:

```

No rule files match the pattern
/var/lib/suricata/rules/local.rules

```

## Root Cause

Suricata attempted to load the rule file from the wrong directory.

The correct location of the rule file was:

```

/etc/suricata/rules/local.rules

```

## Resolution

The rule file was moved or referenced correctly so that Suricata could load it from the expected directory.

The configuration test was then executed successfully:

```

sudo suricata -T -c /etc/suricata/suricata.yaml -i enp0s3

```

---

# 3. Rule Syntax Parsing Error

## Symptom

Suricata returned the following error:

```

Signature missing required value "sid"

```

## Root Cause

The rule syntax was not parsed correctly by Suricata.

Possible causes included:

- incorrect formatting
- rule split across multiple lines
- missing semicolons
- improper parentheses structure

Because the rule parser failed, Suricata did not recognize the `sid` field.

## Resolution

The rule was rewritten in a valid Suricata signature format:

```

alert http $HOME_NET any -> $HOME_NET 80 (msg:"TD3 CUSTOM - HTTP request to /admin detected"; flow:to_server,established; http.uri; content:"/admin"; sid:9000001; rev:1; classtype:policy-violation;)

```

After correction, the rule loaded successfully.

---

# 4. Threshold Rule Placed in Wrong File

## Symptom

Suricata produced configuration errors when starting after adding a threshold rule.

## Root Cause

The threshold configuration was initially placed inside:

```

local.rules

```

However, this file only accepts **detection signatures**.

Threshold rules must be defined in a separate configuration file.

## Resolution

A dedicated threshold configuration file was created:

```

/etc/suricata/threshold.config

```

The threshold rule was added:

```

threshold gen_id 1, sig_id 2024364, type limit, track by_src, count 1, seconds 60

```

The file was then referenced in `suricata.yaml`:

```

threshold-file: /etc/suricata/threshold.config

```

---

# 5. Typographical Error in Threshold Rule

## Symptom

Suricata failed to parse the threshold rule due to a syntax error.

## Root Cause

A typographical error was present in the rule:

```

trak by_src

```

instead of

```

track by_src

```

Since Suricata requires exact syntax, the rule could not be parsed.

## Resolution

The rule was corrected to:

```

threshold gen_id 1, sig_id 2024364, type limit, track by_src, count 1, seconds 60

```

---

# 6. Misinterpretation of HTTP 404 Response

## Symptom

When testing the custom rule with:

```

curl [http://10.10.20.10/admin](http://10.10.20.10/admin)

```

the web server returned:

```

404 Not Found

```

This initially suggested that the rule might not work correctly.

## Root Cause

The confusion came from misunderstanding how IDS rules operate.

The custom rule inspects the **HTTP request URI**, not the server response.

Therefore the request:

```

GET /admin

```

still triggers the IDS rule even if the resource does not exist on the server.

## Resolution

It was confirmed that the IDS correctly detected the `/admin` request regardless of the HTTP response code.

---

# 7. Multiple Alerts from Nmap Scan

## Symptom

Running the following command:

```

nmap -sS -sV -p 1-1000 10.10.20.10

```

generated many identical alerts for the same rule:

```

SID 2024364
ET SCAN Possible Nmap User-Agent Observed

```

## Root Cause

Nmap generates multiple HTTP requests with the same user-agent, which triggers the rule repeatedly.

This behavior is normal but can produce excessive alert noise.

## Resolution

A threshold rule was implemented to limit alert frequency:

```

threshold gen_id 1, sig_id 2024364, type limit, track by_src, count 1, seconds 60

```

This reduced duplicate alerts while preserving detection capability.

---

# Conclusion

Several configuration and syntax issues were encountered during the deployment of the IDS.  
Resolving these problems required understanding Suricata configuration structure, rule syntax, and detection behavior.

These troubleshooting steps are representative of real-world IDS deployment challenges and are an important part of detection engineering workflows.
```

---
