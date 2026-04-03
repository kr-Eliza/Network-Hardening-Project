# Résumé exécutif — Projet de durcissement réseau TD1–TD5

**Projet :** Sécurité des réseaux — TD1 à TD5  
**Auteur :** Kara Eliza | **Date :** 22 mars 2026  
**Environnement :** 5 VMs Vagrant/VirtualBox — Ubuntu 24.04 LTS

---

## Contexte

Un environnement réseau virtuel multi-sites (LAN 10.10.10.0/24 ↔ DMZ 10.10.20.0/24) présentait en baseline une surface d'attaque maximale : aucun filtrage réseau, TLS faible, accès SSH par mot de passe, trafic inter-sites en clair, aucune détection d'intrusion. Ce projet a consisté à appliquer quatre contrôles de sécurité complémentaires et à les valider par des tests reproductibles.

---

## Contrôles déployés

**Pare-feu nftables (TD2)** — Politique default-DROP sur gw-fw. Seuls deux flux sont autorisés du LAN vers la DMZ : HTTPS (port 8443) et SSH (port 22). Les ports sensibles (MySQL 3306, HTTP 80) sont bloqués. Configuration persistante via systemd.

**Durcissement TLS (TD4)** — nginx sur srv-web n'accepte plus que TLS 1.2 et 1.3 avec suites ECDHE-AES256-GCM uniquement. TLS 1.0 et 1.1 sont rejetés (alert protocol version). L'en-tête `Strict-Transport-Security` est activé. Audit testssl.sh : aucune suite faible offerte.

**Accès distant sécurisé (TD5)** — SSH restreint à l'authentification par clé ED25519 pour l'utilisateur `admin1` uniquement. Tunnel IPsec IKEv2 site-to-site établi entre les deux gateways (AES-256/SHA-256/MODP-2048), chiffrant l'intégralité du trafic inter-sites.

**Détection IDS (TD3/TD5)** — Suricata 7 déployé en mode passif sur sensor-ids (interface enp0s3). Trois règles locales actives (SID 9000001–9000003) ciblant les accès à `/admin`, les scans MySQL et les tentatives brute-force SSH. Alertes journalisées en JSON (eve.json) et en texte (fast.log).

---

## Résultats de validation

Quatre scripts de régression bash (`R1` à `R4`) valident chaque contrôle de façon automatisée et reproductible. La run finale (`20260322_235312`) donne **4/4 PASS** après correction de deux bugs typographiques dans les scripts initiaux.

| Contrôle | Script | Résultat |
|----------|--------|----------|
| R1 — Pare-feu | R1_firewall.sh | ✅ PASS |
| R2 — TLS | R2_tls.sh | ✅ PASS |
| R3 — SSH + IPsec | R3_remote_access.sh | ✅ PASS |
| R4 — IDS Suricata | R4_detection.sh | ✅ PASS |

---

## Risques résiduels principaux

Trois risques sont acceptés dans le cadre du TP et documentés dans le registre des risques :
- Certificat TLS auto-signé et expiré → remplacer par Let's Encrypt en production
- PSK IPsec statique → migrer vers PKI X.509 strongSwan
- Suricata IDS passif → activer mode IPS (NFQUEUE) après validation en staging

Le plan 30-60-90 jours (`report/30_60_90_Plan.md`) détaille les actions correctives.
