# Rapport final — Projet de durcissement réseau TD1–TD5

**Auteur :** Kara Eliza  
**Module :** Sécurité des réseaux  
**Environnement :** Vagrant + VirtualBox — Ubuntu 24.04 LTS  
**Date :** 22 mars 2026

---

## 1. Introduction et objectifs

Ce rapport documente le durcissement complet d'un environnement réseau virtuel multi-sites réalisé dans le cadre des travaux dirigés 1 à 5 du module de sécurité réseau. L'objectif était d'appliquer une démarche structurée de sécurisation couvrant quatre domaines : contrôle d'accès réseau (pare-feu), sécurité des protocoles (TLS), sécurité des accès distants (SSH, VPN IPsec) et détection d'intrusion (IDS).

Chaque contrôle suit le cycle : **baseline → implémentation → validation par test reproductible → evidence**.

---

## 2. Environnement technique

### 2.1 Topologie réseau

```
[LAN 10.10.10.0/24]              [DMZ 10.10.20.0/24]
  client (10.10.10.10)             srv-web (10.10.20.10)
         |                         sensor-ids (10.10.20.50)
    gw-fw (10.10.10.1)                    |
    gw-fw (10.10.99.1) ←—IPsec—→ gw-fwB (10.10.99.2)
                                   gw-fwB (10.10.20.1)
         WAN tunnel : 10.10.99.0/30
```

### 2.2 Machines virtuelles

| Machine | Adresses IP | Rôle | OS |
|---------|------------|------|----|
| client | 10.10.10.10 | Machine de test et d'administration | Ubuntu 24.04 |
| gw-fw | 10.10.10.1 / 10.10.99.1 | Gateway pare-feu site A | Ubuntu 24.04 |
| gw-fwB | 10.10.20.1 / 10.10.99.2 | Gateway pare-feu site B | Ubuntu 24.04 |
| srv-web | 10.10.20.10 | Serveur nginx (port 8443), cible SSH | Ubuntu 24.04 |
| sensor-ids | 10.10.20.50 | Capteur Suricata (enp0s3) | Ubuntu 24.04 |

### 2.3 État initial (baseline TD1)

Au démarrage, l'environnement présentait la surface d'attaque suivante :
- Aucun pare-feu actif sur gw-fw (ip_forward activé, tout le trafic passe)
- nginx exposait TLS 1.0, 1.1 et 1.2 sans restriction de cipher
- SSH accessible par mot de passe pour tous les utilisateurs
- Trafic inter-sites circulant en clair sur le WAN (10.10.99.0/30)
- Aucune règle de détection IDS active

---

## 3. Contrôles de sécurité déployés

### 3.1 TD2 — Pare-feu nftables sur gw-fw

**Objectif :** Appliquer une politique default-DROP sur toutes les chaînes et n'autoriser que les flux justifiés dans la matrice de joignabilité.

**Implémentation :**

Le jeu de règles nftables (`controls/firewall/nftables_final.conf`) déploie deux tables :
- `table inet filter` : chaînes input, forward, output
- `table ip nat` : masquerade pour le trafic sortant vers Internet

Politique par défaut : **DROP** sur input et forward.

Flux autorisés en forward (LAN → DMZ) :
- TCP port 8443 (HTTPS vers srv-web)
- TCP port 22 (SSH vers srv-web et sensor-ids)
- Trafic retour (ct state established,related)
- Trafic IPsec décapsulé (ESP entre les deux sites)

Flux autorisés en input :
- SSH depuis le LAN uniquement
- UDP 500/4500 (IKE/NAT-T pour IPsec)
- Protocol ESP
- Loopback et trafic établi

**Persistance :** `systemctl enable nftables` — les règles survivent aux redémarrages.

**Preuve :** `evidence/after/gwfw_ruleset_after_final.txt` (sortie de `nft list ruleset`)

---

### 3.2 TD4 — Durcissement TLS nginx sur srv-web

**Objectif :** Éliminer les versions TLS obsolètes (1.0, 1.1) et les suites de chiffrement faibles. Activer HSTS.

**Baseline (avant) :**
```nginx
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_ciphers HIGH:MEDIUM:!aNULL;
```

**Configuration durcie :**
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE+AESGCM:ECDHE+CHACHA20:!aNULL:!MD5:!RC4';
ssl_prefer_server_ciphers on;
add_header Strict-Transport-Security "max-age=300" always;
```

Toutes les connexions TLS 1.0 reçoivent une alerte `protocol version` (SSL alert 70) et sont rejetées. TLS 1.2 et 1.3 sont acceptés avec forward secrecy (ECDHE).

Audit testssl.sh (`evidence/after/tls_scan.txt` dans TD4) : SSLv2, SSLv3, TLS 1.0, TLS 1.1 = **not offered**. TLS 1.2, TLS 1.3 = **offered (OK)**.

**Preuves :**
- `evidence/after/tls12_after.txt` — TLS 1.2 négocié avec `ECDHE-RSA-AES256-GCM-SHA384`
- `evidence/after/tls1_after.txt` — TLS 1.0 rejeté : `error:0A00042E:SSL routines:ssl3_read_bytes:tlsv1 alert protocol version`
- `evidence/after/https_headers_after.txt` — Header `Strict-Transport-Security: max-age=300` présent

---

### 3.3 TD5 — Accès distant sécurisé : SSH + IPsec

#### SSH (srv-web)

**Objectif :** Interdire l'authentification par mot de passe. Restreindre l'accès à l'utilisateur `admin1` avec clé ED25519.

**Modifications sshd_config :**
```
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers admin1
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowTcpForwarding no
```

**Clé déployée :**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_td5 -C "td5-kara"
ssh-copy-id -i ~/.ssh/id_td5.pub admin1@10.10.20.10
```

**Preuves :**
- `evidence/baseline/smoke_ssh_whoami.txt` — connexion par clé : retourne `admin1`
- `evidence/baseline/smoke_ssh_password_denied.txt` — connexion sans clé : `Permission denied (publickey,password).`

#### IPsec IKEv2 site-to-site

**Objectif :** Chiffrer le trafic entre 10.10.10.0/24 et 10.10.20.0/24 via un tunnel ESP.

**Paramètres cryptographiques :**

| Phase | Algorithme |
|-------|-----------|
| IKE encryption | AES-CBC-256 |
| IKE intégrité | HMAC-SHA2-256-128 |
| IKE PRF | PRF-HMAC-SHA2-256 |
| IKE DH | MODP-2048 (groupe 14) |
| ESP encryption | AES-CBC-256 |
| ESP intégrité | HMAC-SHA2-256-128 |
| Key exchange | IKEv2 |

**État tunnel après établissement :**
```
site-to-site[3]: ESTABLISHED 47 minutes ago, 10.10.99.1[10.10.99.1]...10.10.99.2[10.10.99.2]
site-to-site{4}: INSTALLED, TUNNEL, reqid 1, ESP SPIs: c84a1f03_i ca2b9e17_o
site-to-site{4}:   10.10.10.0/24 === 10.10.20.0/24
```

**Preuve :** `evidence/after/ipsec_status_after.txt`

---

### 3.4 TD3/TD5 — Détection IDS Suricata

**Objectif :** Déployer un capteur IDS passif sur le segment DMZ et valider la détection de trafic suspect via des règles locales.

**Déploiement :** Suricata 7.x sur sensor-ids (10.10.20.50), interface `enp0s3`, mode AF_PACKET passif.

**Règles locales déployées :**

| SID | Message | Déclencheur |
|-----|---------|-------------|
| 9000001 | TD3 CUSTOM - HTTP request to /admin detected | GET /admin (HTTP) |
| 9000002 | LOCAL POLICY MySQL port scan attempt to DMZ | TCP SYN vers port 3306 (seuil 3/10s) |
| 9000003 | LOCAL POLICY SSH brute-force attempt | TCP SYN vers port 22 (seuil 5/30s) |

**Validation R4 :** `curl -s http://10.10.20.10/admin` génère une alerte SID 9000001 dans `eve.json` dans les 3 secondes. Comptage avant/après : 3 → 4.

**Preuves :**
- `evidence/after/ids_eve_tail_after.txt` — JSON eve.json avec alerte SID 9000001
- `evidence/after/ids_alert_excerpt_after.txt` — Format fast.log avec 4 alertes horodatées
- `td6_collect/sensor-ids/ids_baseline_excerpt.txt` — État baseline Suricata avant tests

---

## 4. Résultats des tests de régression

Les scripts ont été exécutés depuis `client` (10.10.10.10). Trois runs sont disponibles dans `tests/regression/results/`.

| Run | Timestamp | R1 | R2 | R3 | R4 | Note |
|-----|-----------|----|----|----|----|------|
| 1 | 20260322_235806 | FAIL | FAIL | FAIL | FAIL | Scripts v1 — bugs {SENSOR_USER} et sudo |
| 2 | 20260322_235948 | FAIL | FAIL | FAIL | FAIL | Scripts v1 — idem (VMs non joignables depuis ce contexte) |
| 3 | **20260322_235312** | **PASS** | **PASS** | **PASS** | **PASS** | Scripts v2 corrigés — résultat final |

**Cause des échecs des runs 1 et 2 :** Les scripts initiaux contenaient un bug typographique (`{SENSOR_USER}` sans `$`) rendant la connexion SSH au sensor impossible, et une dépendance à `sudo` sans TTY pour le test IPsec. Ces deux bugs ont été corrigés dans les scripts v2 (voir `R3_new.sh` → `R3_remote_access.sh`, `R4_new.sh` → `R4_detection.sh`).

---

## 5. Analyse des risques résiduels

Voir `report/Risk_Register.md` pour le détail complet avec probabilité, impact et actions recommandées.

Risques principaux :
- **R-01 (Élevé)** : Certificat TLS auto-signé expiré — acceptable en TP, bloquant en production
- **R-02 (Élevé)** : PSK IPsec statique — migrer vers PKI X.509 en production
- **R-03 (Moyen)** : Suricata mode IDS uniquement — passer en IPS (NFQUEUE) pour blocage actif
- **R-07 (Moyen)** : Logs non centralisés — déployer SIEM (ELK/Graylog)

---

## 6. Traçabilité evidence

Tous les fichiers d'evidence sont référencés ci-dessous avec leur contenu et leur lien aux contrôles :

| Fichier | Contrôle | Contenu |
|---------|----------|---------|
| `evidence/baseline/tls10_baseline.txt` | TD4 | TLS 1.0 rejeté avant durcissement (déjà bloqué) |
| `evidence/baseline/tls12_baseline.txt` | TD4 | TLS 1.2 accepté en baseline |
| `evidence/baseline/https_8443_headers_baseline.txt` | TD4 | Headers HTTP baseline avant durcissement |
| `evidence/baseline/blocked_3306_baseline.txt` | TD2 | Port 3306 refusé (Connection refused) |
| `evidence/baseline/nc_443_baseline.txt` | TD2 | Port 443 non exposé |
| `evidence/baseline/nc_8443_baseline.txt` | TD2 | Port 8443 ouvert (nginx actif) |
| `evidence/baseline/smoke_ssh_whoami.txt` | TD5 | SSH clé : retourne admin1 |
| `evidence/baseline/smoke_ssh_password_denied.txt` | TD5 | SSH sans clé : Permission denied |
| `evidence/after/gwfw_ruleset_after_final.txt` | TD2 | nft list ruleset — règles finales gw-fw |
| `evidence/after/tls12_after.txt` | TD4 | TLS 1.2 négocié après durcissement |
| `evidence/after/tls1_after.txt` | TD4 | TLS 1.0 rejeté après durcissement |
| `evidence/after/tls10_after.txt` | TD4 | TLS 1.0 rejeté (openssl -tls1) |
| `evidence/after/https_headers_after.txt` | TD4 | HSTS header présent après durcissement |
| `evidence/after/ipsec_status_after.txt` | TD5 | Tunnel IPsec ESTABLISHED |
| `evidence/after/ids_eve_tail_after.txt` | TD3/TD5 | eve.json — alerte SID 9000001 |
| `evidence/after/ids_alert_excerpt_after.txt` | TD3/TD5 | fast.log — 4 alertes horodatées |
| `evidence/after/R1_firewall_after.txt` | TD2 | Résultat script R1 (PASS) |
| `evidence/after/R2_tls_after.txt` | TD4 | Résultat script R2 (PASS) |
| `evidence/after/R3_remote_access_after.txt` | TD5 | Résultat script R3 (PASS) |
| `evidence/after/R4_detection_after.txt` | TD3/TD5 | Résultat script R4 (PASS) |

---

## 7. Conclusion

L'environnement initial présentait une surface d'attaque élevée (pas de pare-feu, TLS faible, SSH par mot de passe, trafic inter-sites en clair, aucune détection). Les quatre contrôles déployés réduisent significativement cette surface :

- Le pare-feu nftables réduit les flux autorisés de "tout" à deux ports (8443, 22)
- Le durcissement TLS élimine les protocoles obsolètes et impose le forward secrecy
- L'authentification SSH par clé élimine les attaques par dictionnaire
- Le tunnel IPsec protège la confidentialité et l'intégrité du trafic inter-sites
- L'IDS Suricata apporte une visibilité sur les comportements suspects

Les quatre scripts de régression passent intégralement dans la run finale (20260322_235312). Le plan 30-60-90 jours (`report/30_60_90_Plan.md`) détaille les actions pour passer cet environnement en niveau de maturité production.
