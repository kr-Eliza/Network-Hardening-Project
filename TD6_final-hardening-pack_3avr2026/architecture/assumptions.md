# Hypothèses d'architecture — Final Hardening Pack

**Auteur :** Kara Eliza | **Date :** 22 mars 2026

---

## 1. Portée du projet

Le projet de durcissement couvre exclusivement les composants déployés dans l'environnement de TP Vagrant/VirtualBox. Les services d'infrastructure (DNS, DHCP, NTP, Active Directory, supervision externe) sont hors périmètre.

Les quatre axes de durcissement couverts sont :
- **TD2** : pare-feu nftables sur gw-fw (politique default-DROP)
- **TD3/TD5** : déploiement IDS Suricata sur sensor-ids
- **TD4** : durcissement TLS sur nginx (srv-web)
- **TD5** : SSH par clé uniquement + tunnel IPsec IKEv2 site-to-site

---

## 2. Modèle de menace

**Attaquant considéré :** attaquant externe ayant obtenu un accès réseau au segment DMZ (10.10.20.0/24), par exemple via compromission d'un équipement exposé. Les menaces internes (insider) ne sont pas modélisées dans ce TP.

**Objectifs de l'attaquant :**
- Atteindre des services non exposés (MySQL, services internes)
- Intercepter le trafic inter-sites en clair sur le WAN (10.10.99.0/30)
- Accéder à l'administration SSH par force brute ou vol de credentials
- Opérer sans être détecté par l'IDS

**Contrôles mis en place pour y répondre :**

| Menace | Contrôle | Mécanisme |
|--------|----------|-----------|
| Accès à services non exposés | Pare-feu nftables | Default-DROP + whitelist minimale |
| Interception WAN | Tunnel IPsec IKEv2 | AES-256/SHA-256, ESP chiffré |
| Brute-force SSH | Authentification par clé uniquement | PasswordAuthentication no |
| Downgrade TLS | nginx ssl_protocols TLSv1.2 TLSv1.3 | TLS 1.0/1.1 désactivés |
| Trafic malveillant non détecté | Suricata IDS | Règles locales SID 9000001–9000003 |

---

## 3. Hypothèses techniques retenues

**H1 — Certificat TLS auto-signé acceptable en TP**
Le certificat utilisé sur srv-web (CN=td4.local, RSA 2048 bits, signé SHA-256) est auto-signé et avait une durée de validité courte (15–22 mars 2026). Ce choix est délibéré pour le TP. En production, un certificat émis par une CA reconnue (Let's Encrypt, PKI interne) serait obligatoire. Les clients doivent utiliser `-k` (curl) ou ignorer l'erreur de vérification.

**H2 — Clé pré-partagée IPsec acceptable en TP**
Le PSK strongSwan est défini statiquement dans `/etc/ipsec.secrets`. En production, une authentification par certificats X.509 (PKI strongSwan) serait utilisée pour éviter la compromission par divulgation du secret partagé.

**H3 — Clé SSH générée et distribuée manuellement**
La paire ED25519 (`id_td5` / `id_td5.pub`) a été générée sur la machine `client` et copiée manuellement sur srv-web via `ssh-copy-id`. La rotation des clés n'est pas automatisée dans ce TP.

**H4 — Suricata en mode IDS passif uniquement**
Le capteur sensor-ids fonctionne en AF_PACKET mode single-copy sur l'interface `enp0s3`. Il observe et alerte, mais ne bloque pas le trafic. Le passage en mode IPS (NFQUEUE inline) n'est pas déployé afin de ne pas perturber les tests.

**H5 — Persistance nftables via systemd**
Les règles nftables sur gw-fw sont rendues persistantes par `systemctl enable nftables` et le fichier `/etc/nftables.conf`. Un redémarrage de la VM conserve les règles sans intervention manuelle.

**H6 — Routage IP forwarding activé sur les gateways**
`net.ipv4.ip_forward = 1` est configuré de façon permanente dans `/etc/sysctl.d/99-ipforward.conf` sur gw-fw et gw-fwB. Sans ce paramètre, le trafic inter-zones et le tunnel IPsec ne fonctionnent pas.

**H7 — Seul l'utilisateur admin1 accède en SSH à srv-web**
La directive `AllowUsers admin1` dans sshd_config restreint les connexions SSH à ce compte. Le compte `student` utilisé par Vagrant pour le provisioning est distinct et conservé pour la gestion de la VM.

---

## 4. Limites connues et risques acceptés

| Limite | Impact | Justification |
|--------|--------|---------------|
| Certificat TLS expiré | Alertes navigateur, curl -k requis | Acceptable en TP, documenté |
| PSK IPsec en clair dans ipsec.secrets | Compromission si fichier exfiltré | Acceptable en TP, rotation en production |
| HSTS max-age=300 (5 min) | Protection HSTS faible | Valeur TP, production = 31536000 |
| Suricata IDS non bloquant | Trafic malveillant non interrompu | Choix délibéré pour ne pas bloquer les tests |
| sudo non configuré NOPASSWD pour ipsec | Test R3 automatisé partiel | Corrigé dans R3_remote_access.sh v2 |
| Pas de fail2ban | SSH exposé aux tentatives répétées | Hors périmètre TP, documenté dans Risk_Register |

---

## 5. Conventions de nommage et adressage

| Élément | Valeur | Notes |
|---------|--------|-------|
| Réseau LAN | 10.10.10.0/24 | Site A |
| Réseau DMZ | 10.10.20.0/24 | Site B |
| Réseau WAN/tunnel | 10.10.99.0/30 | Lien inter-gateway |
| client | 10.10.10.10 | Machine de test et d'administration |
| gw-fw | 10.10.10.1 / 10.10.99.1 | Gateway site A |
| gw-fwB | 10.10.20.1 / 10.10.99.2 | Gateway site B |
| srv-web | 10.10.20.10 | Serveur nginx, port 8443 |
| sensor-ids | 10.10.20.50 | Capteur Suricata, interface enp0s3 |
| Port HTTPS | 8443 | Non-standard, choix TP |
| Algorithmes IPsec | AES-256 / SHA-256 / MODP-2048 | IKEv2 |
| Type clé SSH | ED25519 | Fichier id_td5 |
| SID règle admin | 9000001 | Défini en TD3, maintenu en TD5 |
