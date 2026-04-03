
# 1. Objective

The objective of this section is to secure remote administrative access to the server (`siteB-srv`) by:

* Eliminating weak authentication mechanisms
* Restricting access to authorized users only
* Ensuring traceability of connections

---

# 2. Initial State (Before Hardening)

By default, the SSH service allows:

* Password authentication → vulnerable to brute-force attacks
* Root login → high-risk privilege escalation
* Multiple users → uncontrolled access

👉 This configuration is **not acceptable in a production environment**.

---

# 3. Hardening Strategy

The following security principles were applied:

| Principle                | Implementation          |
| ------------------------ | ----------------------- |
| Strong authentication    | SSH key-based login     |
| Least privilege          | Dedicated admin user    |
| Access control           | AllowUsers directive    |
| Attack surface reduction | Disable password + root |
| Monitoring               | Authentication logs     |

---

# 4. Step 1 — Create a Dedicated Admin User

On `siteB-srv`:

```bash
sudo useradd -m -s /bin/bash admin1
sudo passwd admin1
```

👉 A temporary password is required for initial key deployment.

---

# 5. Step 2 — Generate SSH Key (Client Side)

On `siteA-client`:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_td5 -C "admin1@td5"
```

This generates:

* Private key → `~/.ssh/id_td5`
* Public key → `~/.ssh/id_td5.pub`

---

# 6. Step 3 — Deploy Public Key

```bash
ssh-copy-id -i ~/.ssh/id_td5.pub admin1@10.10.20.10
```

👉 This copies the key into:

```bash
/home/admin1/.ssh/authorized_keys
```

---

# 7. Step 4 — Validate Key Authentication (CRITICAL)

Before modifying SSH configuration:

```bash
ssh -i ~/.ssh/id_td5 admin1@10.10.20.10 whoami
```

Expected result:

```text
admin1
```

⚠️ This step is essential to avoid locking yourself out.

---

# 8. Step 5 — Harden SSH Configuration

File:

```bash
/etc/ssh/sshd_config
```

Configuration applied:

```text
PasswordAuthentication no
PermitRootLogin no
AllowUsers admin1
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
```

---

# 9. Step 6 — Validate Configuration

Before restart:

```bash
sudo sshd -t
```

If no errors:

```bash
sudo systemctl restart ssh
```

---

# 10. Step 7 — Functional Tests

---

## 10.1 Positive Test (Expected SUCCESS)

```bash
ssh -i ~/.ssh/id_td5 admin1@10.10.20.10 "echo SSH_KEY_OK"
```

Result:

```text
SSH_KEY_OK
```

---

## 10.2 Negative Test — Password Authentication (Expected FAILURE)

```bash
ssh -o PubkeyAuthentication=no admin1@10.10.20.10
```

Result:

```text
Permission denied (publickey)
```

---

## 10.3 Negative Test — Root Login (Expected FAILURE)

```bash
ssh -i ~/.ssh/id_td5 root@10.10.20.10
```

Result:

```text
Permission denied
```

---

# 11. Logging and Monitoring

Authentication logs were collected using:

```bash
sudo tail -n 50 /var/log/auth.log
```

These logs show:

* Successful key-based authentication
* Failed login attempts
* Rejected root connections

👉 This ensures **traceability and auditability**.

---

# 12. Security Analysis

---

## 12.1 Threat Mitigation

| Threat               | Mitigation                       |
| -------------------- | -------------------------------- |
| Brute-force attack   | Password authentication disabled |
| Credential theft     | Key-based authentication         |
| Privilege escalation | Root login disabled              |
| Unauthorized access  | AllowUsers restriction           |

---

## 12.2 Security Benefits

* Strong authentication using asymmetric cryptography
* Reduced attack surface
* Controlled access
* Improved logging visibility

---

# 13. Common Issues Encountered

---

## 13.1 Key Not Accepted

Cause:

* Key not properly copied

Fix:

```bash
ssh-copy-id -i ~/.ssh/id_td5.pub admin1@10.10.20.10
```

---

## 13.2 Locked Out After Config Change

Cause:

* SSH hardened before testing key

Prevention:

* Always test key authentication first

---

## 13.3 Typo in SSH Options

Example:

```bash
PreferedAuthentications ❌
PreferredAuthentications ✅
```

---

## 13.4 Permission Denied Errors

Possible causes:

* wrong key
* wrong user
* incorrect permissions in `.ssh`

---

# 14. Final Result

| Control                  | Status |
| ------------------------ | ------ |
| Key-based authentication | ✅      |
| Password login disabled  | ✅      |
| Root login disabled      | ✅      |
| Access restricted        | ✅      |
| Logging active           | ✅      |

---

# 15. Conclusion

The SSH service is now hardened according to best practices:

* Only authorized users can connect
* Authentication is strong and secure
* Attack surface is minimized
* System activity is traceable

👉 This configuration reflects a **production-grade secure remote access setup**.

---

