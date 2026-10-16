# Site-to-site IPsec tunnel - TD3/TD5

## Topology

```
[LAN admin 10.10.10.0/24]         [DMZ 10.10.20.0/24]
     gw-fw (10.10.99.1) <--- IPsec ---> gw-fwB (10.10.99.2)
```

Transport link: 10.10.99.0/30 (eth3 interface on both gateways)

## strongSwan configuration

### File `/etc/ipsec.conf` (gw-fw)

```
config setup
    charondebug="ike 1, knl 1, cfg 1"

conn site-to-site
    authby=secret
    left=10.10.99.1
    leftsubnet=10.10.10.0/24
    right=10.10.99.2
    rightsubnet=10.10.20.0/24
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256!
    keyexchange=ikev2
    auto=start
    dpdaction=restart
    dpddelay=30s
    dpdtimeout=120s
```

### File `/etc/ipsec.secrets` (gw-fw)

```
10.10.99.1 10.10.99.2 : PSK "<REDACTED>"
```

### Mirror configuration on gw-fwB

`left`/`right` swapped, `leftsubnet`/`rightsubnet` swapped.

## Selected algorithms

| Parameter | Value |
|---|---|
| IKE encryption | AES-256 |
| IKE integrity | SHA-256 |
| IKE DH group | modp2048 (group 14) |
| ESP encryption | AES-256 |
| ESP integrity | SHA-256 |
| Key exchange | IKEv2 |

## Management commands

```bash
# Start the tunnel
sudo ipsec up site-to-site

# Check the status
sudo ipsec statusall

# Restart
sudo systemctl restart strongswan

# Show the SAs in the kernel
sudo ip xfrm state
sudo ip xfrm policy
```

## Expected state (tunnel established)

```
Security Associations (1 up, 0 connecting):
site-to-site[1]: ESTABLISHED X minutes ago, 10.10.99.1[10.10.99.1]...10.10.99.2[10.10.99.2]
site-to-site{1}: INSTALLED, TUNNEL, reqid 1, ESP in UDP SPIs: ...
site-to-site{1}: 10.10.10.0/24 === 10.10.20.0/24
```

## Note on the automated R3 test

The R3 script tries to run `sudo ipsec statusall` over SSH on gw-fw as the `student` user. This command fails because `sudo` requires a TTY or a password, and `student` is not in sudoers without a password for `ipsec`. The tunnel still works - see `evidence/after/ipsec_status_after.txt` for the manual evidence.
