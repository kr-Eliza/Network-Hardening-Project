# Notes de déploiement Suricata — TD3/TD5

## Installation

Suricata 7.0.x installé via le PPA officiel sur Ubuntu 24.04 (sensor-ids, 10.10.20.50).

```bash
sudo add-apt-repository ppa:oisf/suricata-stable
sudo apt update && sudo apt install suricata -y
```

## Configuration réseau

Interface de capture : `enp0s3` (segment DMZ 10.10.20.0/24)
Mode : passif IDS (AF_PACKET, single copy)

`/etc/suricata/suricata.yaml` — extraits clés :

```yaml
af-packet:
  - interface: enp0s3
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes

HOME_NET: "[10.10.10.0/24,10.10.20.0/24]"
EXTERNAL_NET: "!$HOME_NET"

default-rule-path: /etc/suricata/rules
rule-files:
  - local.rules

outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: /var/log/suricata/eve.json
      types:
        - alert
        - http
        - dns
        - tls
  - fast:
      enabled: yes
      filename: /var/log/suricata/fast.log
      append: yes
```

## Règles déployées

Seules les règles locales (`local.rules`) sont activées. Les règles ET-Open sont désactivées pour limiter le bruit dans l'environnement de TP (sauf SID 2024364 utilisé en TD3 pour le test Nmap).

Règles actives :
- SID 9000001 : accès HTTP à `/admin` (aligné avec TD3)
- SID 9000002 : scan port MySQL 3306
- SID 9000003 : tentative brute-force SSH

## Commandes de vérification

```bash
# Vérifier que Suricata tourne
sudo systemctl status suricata

# Recharger les règles sans redémarrage
sudo suricatasc -c reload-rules

# Vérifier les alertes en temps réel
sudo tail -f /var/log/suricata/eve.json | jq 'select(.event_type=="alert")'

# Compter les alertes par SID
sudo jq -r 'select(.event_type=="alert") | .alert.signature_id' \
    /var/log/suricata/eve.json | sort | uniq -c | sort -rn
```

## Passage en mode IPS (non déployé — documenté pour info)

Pour passer en inline IPS avec NFQUEUE :
```bash
# suricata.yaml
nfqueue:
  - queue-num: 0

# iptables pour rediriger le trafic
iptables -I FORWARD -j NFQUEUE --queue-num 0
```

Ce mode n'est pas activé dans ce TP pour éviter de bloquer le trafic de test.
