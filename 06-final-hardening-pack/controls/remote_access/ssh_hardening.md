# SSH hardening - srv-web (10.10.20.10)

## Objective

Restrict SSH access to public key authentication only, disable password authentication, and limit the allowed users.

## Changes made to `/etc/ssh/sshd_config`

```
# Protocol
Protocol 2

# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes

# User restriction
AllowUsers admin1

# Timeouts and limits
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 5

# Disable unneeded features
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitUserEnvironment no
PrintLastLog yes

# Banner
Banner /etc/ssh/banner.txt
```

## Deployed key

Type: ED25519 (generated for this lab)  
Client-side file: `/home/student/.ssh/id_td5`  
Server-side file: `/home/admin1/.ssh/authorized_keys`

```bash
# Generation (client side)
ssh-keygen -t ed25519 -C "td5-kara" -f ~/.ssh/id_td5

# Deployment (client side)
ssh-copy-id -i ~/.ssh/id_td5.pub admin1@10.10.20.10
```

## Checks

```bash
# Key-based login test (must succeed)
ssh -i ~/.ssh/id_td5 -o BatchMode=yes admin1@10.10.20.10 whoami
# → admin1

# Password login test (must fail)
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password \
    -o BatchMode=yes admin1@10.10.20.10 whoami
# → Permission denied (publickey,password).
```

## Banner file

```
/etc/ssh/banner.txt :
-------------------------------------------------------------------
Restricted access - TD5 lab system
All connections are logged.
Unauthorized users: disconnect immediately.
-------------------------------------------------------------------
```

## Service restart

```bash
sudo systemctl restart ssh
sudo systemctl status ssh   # check active (running)
```
