# Test Cards — Final Hardening Pack

**Auteur :** Kara Eliza | **Date :** 22 mars 2026

---

## R1 — Firewall (nftables)

**Claim :** Le pare-feu autorise le flux HTTPS vers srv-web:8443 et bloque les ports non autorisés (ex. MySQL 3306).

| # | Action | Commande | Attendu | Résultat |
|---|---|---|---|---|
| 1 | Flux HTTPS autorisé | `curl -sk -o /dev/null -w "%{http_code}" https://10.10.20.10:8443` | HTTP 200 | PASS |
| 2 | Port 3306 bloqué | `nc -vz -w 3 10.10.20.10 3306` | Connection refused (exit 1) | PASS |

**Script :** `tests/regression/R1_firewall.sh`  
**Preuves :** `evidence/after/R1_firewall_after.txt`, `evidence/after/gwfw_ruleset_after_final.txt`

---

## R2 — TLS Edge (nginx)

**Claim :** L'endpoint HTTPS sur 8443 n'accepte que TLS 1.2+ et retourne un header HSTS.

| # | Action | Commande | Attendu | Résultat |
|---|---|---|---|---|
| 1 | TLS 1.2 accepté | `openssl s_client -connect 10.10.20.10:8443 -tls1_2` | `Protocol : TLSv1.2` | PASS |
| 2 | TLS 1.0 rejeté | `openssl s_client -connect 10.10.20.10:8443 -tls1` | `alert protocol version` | PASS |
| 3 | HSTS présent | `curl -skI https://10.10.20.10:8443` | `Strict-Transport-Security` | PASS |

**Script :** `tests/regression/R2_tls.sh`  
**Preuves :** `evidence/after/R2_tls_after.txt`, `evidence/after/tls12_after.txt`, `evidence/after/tls1_after.txt`, `evidence/after/tls10_after.txt`

---

## R3 — Accès distant (SSH + IPsec)

**Claim :** L'accès SSH est restreint aux clés publiques. Le tunnel IPsec site-to-site est établi.

| # | Action | Commande | Attendu | Résultat |
|---|---|---|---|---|
| 1 | SSH par clé réussit | `ssh -i /home/student/.ssh/id_td5 admin1@10.10.20.10 whoami` | `admin1` | PASS |
| 2 | SSH par mot de passe refusé | `ssh -o PubkeyAuthentication=no admin1@10.10.20.10` | `Permission denied` | PASS |
| 3 | Tunnel IPsec ESTABLISHED | `sudo ipsec statusall` sur gw-fw | `ESTABLISHED` | PASS |

**Script :** `tests/regression/R3_remote_access.sh`  
**Preuves :** `evidence/after/R3_remote_access_after.txt`, `evidence/after/ipsec_status_after.txt`

---

## R4 — Détection IDS (Suricata)

**Claim :** Suricata détecte les accès HTTP à `/admin` (SID 9000001, aligné avec la règle TD3).

| # | Action | Commande | Attendu | Résultat |
|---|---|---|---|---|
| 1 | Comptage alertes avant | SSH → `grep -c '"signature_id":9000001' eve.json` | N=3 | PASS |
| 2 | Déclenchement alerte | `curl -s http://10.10.20.10/admin` | Requête envoyée | PASS |
| 3 | Comptage alertes après | SSH → `grep -c '"signature_id":9000001' eve.json` | N+1=4 | PASS |
| 4 | Affichage dernière alerte | `grep '"signature_id":9000001' eve.json \| tail -5` | Ligne JSON alerte | PASS |

**Script :** `tests/regression/R4_detection.sh`  
**Preuves :** `evidence/after/R4_detection_after.txt`, `evidence/after/ids_eve_tail_after.txt`, `evidence/after/ids_alert_excerpt_after.txt`

**Note :** La règle SID 9000001 est la règle custom introduite en TD3 (`TD3 CUSTOM - HTTP request to /admin detected`) et maintenue en TD5.

---

## Récapitulatif

| Contrôle | Script | Résultat |
|---|---|---|
| R1 Firewall | R1_firewall.sh | **PASS** |
| R2 TLS | R2_tls.sh | **PASS** |
| R3 Remote Access | R3_remote_access.sh | **PASS** |
| R4 Detection | R4_detection.sh | **PASS** |
