# Final Hardening Pack — TD1 à TD5

**Auteurs :** Kara Eliza, Herbron Nathan, Dos Santos Carlos
**Promotion :** 2027 (OCC2)
**Date de rendu :** 3 avril 2026

## Objectif
mars
Ce dossier centralise l'ensemble des livrables et preuves du projet de durcissement réseau couvrant les TD 1 à 5. Il constitue le rendu final pour évaluation.

## Architecture du réseau

| Segment | Plage IP | Description |
|---|---|---|mars
| LAN admin | 10.10.10.0/24 | Réseau d'administration, gateway gw-fw |
| LAN serveurs | 10.10.20.0/24 | Réseau DMZ, srv-web, sensor-ids |
| Tunnel IPsec | 10.10.99.0/30 | Lien site-to-site entre gw-fw et gw-fwB |

Machines clés :
- `gw-fw` : 10.10.10.1 / 10.10.99.1 (gateway/pare-feu côté LAN)
- `gw-fwB` : 10.10.20.1 / 10.10.99.2 (gateway côté DMZ)
- `srv-web` : 10.10.20.10 (nginx TLS 8443)
- `sensor-ids` : 10.10.20.50 (Suricata, interface enp0s3)
- `client` : 10.10.10.10 (machine de test)

## Structure du dossier

```
final-hardening-pack/
├── README.md
├── architecture/
│   ├── assumptions.md
│   ├── network_diagram.png
│   └── reachability_matrix.csv
├── controls/
│   ├── firewall/nftables_final.conf
│   ├── ids/local.rules + suricata_notes.md
│   ├── remote_access/ssh_hardening.md + ipsec_summary.md
│   └── tls_edge/nginx_final.conf
├── evidence/
│   ├── baseline/       ← captures avant durcissement
│   └── after/          ← captures après durcissement
├── executive/
│   └── Executive_Summary_1p.md
├── report/
│   ├── Final_Report.md
│   ├── Risk_Register.md
│   ├── 30_60_90_Plan.md
│   └── Peer_Review.md
├── td6_collect/        ← collectes baseline TD6
│   ├── gw-fw/
│   ├── gw-fwB/
│   ├── sensor-ids/
│   └── srv-web/
└── tests/
    ├── TEST_CARDS.md
    └── regression/
        ├── R1_firewall.sh
        ├── R2_tls.sh
        ├── R3_remote_access.sh
        ├── R4_detection.sh
        ├── run_all.sh
        └── results/
            ├── 20260322_235806/   ← run initiale (scripts v1 buggés)
            ├── 20260322_235948/   ← run intermédiaire (scripts v1 buggés)
            └── 20260322_235312/   ← run finale (scripts corrigés) ✓ 4/4 PASS
```

## Notes sur les scripts de régression

Les scripts initiaux (`R3_remote_access.sh` v1 et `R4_detection.sh` v1) contenaient deux bugs :
- `R4` : variable `{SENSOR_USER}` sans `$` et `grep-c` sans espace → les deux premières runs échouaient systématiquement sur R4
- `R3` : le `sudo ipsec statusall` via SSH nécessite un TTY → échec sur R3 TEST 3

Les scripts ont été corrigés (correspondant aux versions `R3_new.sh` / `R4_new.sh`) et une troisième run (`20260322_235312`) a été exécutée avec succès : **4/4 PASS**.

## Résultats de synthèse (run finale 20260322_235312)

| Contrôle | Résultat |
|---|---|
| R1 – Firewall | **PASS** |
| R2 – TLS | **PASS** |
| R3 – Accès distant | **PASS** |
| R4 – Détection IDS | **PASS** |
