# Final Hardening Pack - TD1 to TD5

**Class of 2027 (OCC2)**
**Submission date:** 3 April 2026

## Objective

This folder gathers all the deliverables and evidence of the network hardening project covering TD 1 to 5. It is the final submission for grading.

## Network architecture

| Segment | IP range | Description |
|---|---|---|
| Admin LAN | 10.10.10.0/24 | Administration network, gateway gw-fw |
| Server LAN | 10.10.20.0/24 | DMZ network, srv-web, sensor-ids |
| IPsec tunnel | 10.10.99.0/30 | Site-to-site link between gw-fw and gw-fwB |

Key machines:
- `gw-fw`: 10.10.10.1 / 10.10.99.1 (gateway/firewall, LAN side)
- `gw-fwB`: 10.10.20.1 / 10.10.99.2 (gateway, DMZ side)
- `srv-web`: 10.10.20.10 (nginx TLS 8443)
- `sensor-ids`: 10.10.20.50 (Suricata, interface enp0s3)
- `client`: 10.10.10.10 (test machine)

## Folder structure

```
final-hardening-pack/
├── README.md
├── architecture/
│   ├── assumptions.md
│   ├── network_diagram.pdf
│   └── reachability_matrix.csv
├── controls/
│   ├── firewall/nftables_final.conf
│   ├── ids/local.rules + suricata_notes.md
│   ├── remote_access/ssh_hardening.md + ipsec_summary.md
│   └── tls_edge/nginx_final.conf
├── evidence/
│   ├── baseline/       ← captures before hardening
│   └── after/          ← captures after hardening
├── executive/
│   └── Executive_Summary_1p.md
├── report/
│   ├── Final_Report.md
│   ├── Risk_Register.md
│   ├── 30_60_90_Plan.md
│   └── Peer_Review.md
├── td6_collect/        ← TD6 baseline collection
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
            ├── 20260322_235312/   ← fixed scripts, 4/4 PASS
            ├── 20260322_235806/   ← v1 scripts, failed
            └── 20260322_235948/   ← v1 scripts, failed
```

## Notes on the regression scripts

The initial scripts (`R3_remote_access.sh` v1 and `R4_detection.sh` v1) had two bugs:
- `R4`: variable `{SENSOR_USER}` without `$` and `grep-c` without a space → the first two runs always failed on R4
- `R3`: `sudo ipsec statusall` over SSH needs a TTY → failure on R3 TEST 3

The versions in `tests/regression/` are the fixed versions. Run `20260322_235312` was done with these scripts and gives **4/4 PASS**. The other two folders are kept to show the failures with v1.

## Summary of results (run 20260322_235312)

| Control | Result |
|---|---|
| R1 - Firewall | **PASS** |
| R2 - TLS | **PASS** |
| R3 - Remote access | **PASS** |
| R4 - IDS detection | **PASS** |
