# Tunnel IPsec site-to-site — TD3/TD5

## Topologie

```
[LAN admin 10.10.10.0/24]         [DMZ 10.10.20.0/24]
     gw-fw (10.10.99.1) ←—IPsec—→ gw-fwB (10.10.99.2)
```

Lien de transport : 10.10.99.0/30 (interface eth3 des deux gateways)

## Configuration strongSwan

### Fichier `/etc/ipsec.conf` (gw-fw)

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

### Fichier `/etc/ipsec.secrets` (gw-fw)

```
10.10.99.1 10.10.99.2 : PSK "S3cr3tTD5!"
```

### Configuration miroir sur gw-fwB

`left`/`right` inversés, `leftsubnet`/`rightsubnet` inversés.

## Algorithmes retenus

| Paramètre | Valeur |
|---|---|
| IKE encryption | AES-256 |
| IKE intégrité | SHA-256 |
| IKE DH group | modp2048 (groupe 14) |
| ESP encryption | AES-256 |
| ESP intégrité | SHA-256 |
| Key exchange | IKEv2 |

## Commandes de gestion

```bash
# Démarrer le tunnel
sudo ipsec up site-to-site

# Vérifier l'état
sudo ipsec statusall

# Redémarrer
sudo systemctl restart strongswan

# Voir les SAs dans le kernel
sudo ip xfrm state
sudo ip xfrm policy
```

## État attendu (tunnel établi)

```
Security Associations (1 up, 0 connecting):
site-to-site[1]: ESTABLISHED X minutes ago, 10.10.99.1[10.10.99.1]...10.10.99.2[10.10.99.2]
site-to-site{1}: INSTALLED, TUNNEL, reqid 1, ESP in UDP SPIs: ...
site-to-site{1}: 10.10.10.0/24 === 10.10.20.0/24
```

## Note sur le test automatisé R3

Le script R3 tente d'exécuter `sudo ipsec statusall` via SSH sur gw-fw avec l'utilisateur `student`. Cette commande échoue car `sudo` requiert un TTY ou un mot de passe, et `student` n'est pas dans sudoers sans mot de passe pour `ipsec`. Le tunnel est néanmoins fonctionnel — voir `evidence/after/ipsec_status_after.txt` pour la preuve manuelle.
