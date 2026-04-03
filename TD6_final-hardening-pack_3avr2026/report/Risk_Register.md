# Registre des risques — Projet de durcissement TD1–TD5

**Auteur :** Kara Eliza | **Date :** 22 mars 2026  
**Méthode de scoring :** Probabilité (1-3) × Impact (1-3) = Score brut (1-9)

---

## Matrice de risques

| ID | Risque | Composant | Prob. | Impact | Score | Criticité | Statut |
|----|--------|-----------|-------|--------|-------|-----------|--------|
| R-01 | Certificat TLS auto-signé et expiré | srv-web / nginx | 3 | 2 | 6 | **Élevé** | Accepté (TP) |
| R-02 | Clé pré-partagée IPsec statique en clair | gw-fw, gw-fwB | 2 | 3 | 6 | **Élevé** | Accepté (TP) |
| R-03 | Suricata en mode IDS passif uniquement | sensor-ids | 3 | 2 | 6 | **Élevé** | Accepté (TP) |
| R-04 | Logs non centralisés (Suricata, nginx, sshd) | Tous | 2 | 2 | 4 | **Moyen** | Ouvert |
| R-05 | Interface SSH exposée sans protection anti-brute-force | srv-web | 2 | 2 | 4 | **Moyen** | Ouvert |
| R-06 | HSTS max-age trop court (300 secondes) | srv-web / nginx | 3 | 1 | 3 | **Moyen** | Accepté (TP) |
| R-07 | Pas de rotation automatique des clés SSH | srv-web | 1 | 2 | 2 | **Faible** | Ouvert |
| R-08 | Pas de DH params personnalisés dans nginx | srv-web / nginx | 1 | 2 | 2 | **Faible** | Ouvert |
| R-09 | Pas de OCSP Stapling (certificat auto-signé) | srv-web / nginx | 1 | 1 | 1 | **Faible** | Accepté (TP) |
| R-10 | Règles IDS limitées (3 SIDs locaux, pas ET-Open) | sensor-ids | 2 | 2 | 4 | **Moyen** | Ouvert |

---

## Détail des risques

### R-01 — Certificat TLS auto-signé et expiré

**Description :** Le certificat X.509 déployé sur srv-web (CN=td4.local) est auto-signé et avait une durée de validité de 7 jours (15–22 mars 2026). Il est expiré au moment du rendu.

**Impact technique :** Les navigateurs et outils (curl sans `-k`) rejettent la connexion. Un attaquant MITM pourrait substituer son propre certificat sans que le client ne détecte la différence (pas de chaîne de confiance).

**Contrôle existant :** Aucun (certificat auto-signé délibéré pour le TP).

**Action recommandée :** En production — déployer certbot avec renouvellement automatique (`certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"`) ou utiliser une PKI interne. HSTS max-age à porter à 31536000 simultanément.

---

### R-02 — Clé pré-partagée IPsec statique

**Description :** Le PSK strongSwan est défini en clair dans `/etc/ipsec.secrets`. Si ce fichier est exfiltré (ex. via une faille sudo ou une compromission du compte root), le tunnel peut être déchiffré rétrospectivement sur des captures réseau.

**Impact technique :** Déchiffrement du trafic inter-sites a posteriori. Usurpation d'identité d'une gateway.

**Contrôle existant :** Fichier `/etc/ipsec.secrets` avec permissions 600, propriétaire root.

**Action recommandée :** Migrer vers une authentification par certificats X.509 strongSwan. Générer une CA dédiée, émettre un certificat par gateway, configurer `leftcert=` / `rightcert=` dans ipsec.conf.

---

### R-03 — Suricata en mode IDS passif

**Description :** Suricata observe le trafic en AF_PACKET mais ne peut pas bloquer les paquets. Un attaquant dont le trafic déclenche une alerte peut tout de même aboutir sa connexion.

**Impact technique :** Détection sans prévention. Fenêtre d'exploitation entre la génération de l'alerte et la réaction d'un opérateur.

**Contrôle existant :** Alertes dans `eve.json` et `fast.log`. Revue manuelle possible.

**Action recommandée :** Passer en mode IPS NFQUEUE inline : `suricata -c /etc/suricata/suricata.yaml -q 0` avec règle iptables `NFQUEUE --queue-num 0`. Tester en staging avant production.

---

### R-04 — Logs non centralisés

**Description :** Les logs sont stockés localement sur chaque machine (Suricata sur sensor-ids, nginx sur srv-web, sshd sur srv-web, nftables sur gw-fw). En cas de compromission d'une machine, les logs peuvent être effacés.

**Contrôle existant :** Logs locaux, rotation logrotate.

**Action recommandée :** Déployer Filebeat sur chaque hôte vers un stack ELK centralisé. Configurer des alertes Kibana sur les SIDs critiques et les erreurs 4xx/5xx répétées.

---

### R-05 — SSH sans protection anti-brute-force

**Description :** Bien que `PasswordAuthentication no` empêche les attaques par dictionnaire classiques, un attaquant peut quand même scanner et tenter des connexions répétées, générèrant du bruit et consommant des ressources.

**Contrôle existant :** `MaxAuthTries 3`, `LoginGraceTime 30`. Règle Suricata SID 9000003 (alerte SSH brute-force).

**Action recommandée :** Installer fail2ban avec jail `sshd` : bannissement après 5 échecs en 10 minutes, durée 1 heure. Configurer une alerte par email sur les bannissements.

---

### R-06 — HSTS max-age trop court

**Description :** La valeur `max-age=300` (5 minutes) ne protège pas efficacement contre les attaques de downgrade HTTPS. Après 5 minutes, le navigateur ne se souvient plus de la directive HSTS.

**Contrôle existant :** HSTS activé (header présent).

**Action recommandée :** Porter à `max-age=31536000` (1 an) avec `includeSubDomains` en production. Tester d'abord avec une valeur courte pour valider l'absence d'effets de bord.

---

### R-07 — Pas de rotation des clés SSH

**Description :** La clé ED25519 `id_td5` est statique depuis sa génération. Une clé compromise reste valide indéfiniment.

**Action recommandée :** Implémenter une rotation trimestrielle via Ansible : génération d'une nouvelle paire, déploiement de la clé publique, suppression de l'ancienne après validation.

---

### R-08 — Pas de DH params personnalisés dans nginx

**Description :** Sans `ssl_dhparam`, nginx utilise les paramètres DH par défaut d'OpenSSL (généralement 1024 ou 2048 bits selon la version). Pour les suites DHE (non ECDHE), cela peut être insuffisant.

**Action recommandée :** Générer des paramètres DH dédiés : `openssl dhparam -out /etc/nginx/certs/dhparam.pem 2048` et ajouter `ssl_dhparam /etc/nginx/certs/dhparam.pem;` dans nginx.conf. Dans la configuration actuelle (ECDHE uniquement), ce risque est mitigé.

---

### R-10 — Couverture IDS limitée

**Description :** Seules 3 règles locales sont actives. Les signatures ET-Open (Emerging Threats) couvrant des milliers de menaces connues ne sont pas activées.

**Action recommandée :** Activer les règles ET-Open en mode IDS d'abord pour mesurer le volume d'alertes. Filtrer par catégories pertinentes (exploit, malware, policy). Utiliser `suricata-update` pour maintenir les règles à jour automatiquement.
