# Peer Review - Hardening Project TD1-TD5

**Project reviewed:** Final Hardening Pack  
**Reviewer:** [anonymised for submission]  
**Review date:** 22 March 2026  
**Method:** Review of the complete folder + execution of the R1-R4 regression scripts

---

## 1. Evaluation method

The review covers four dimensions:
1. **Completeness** - are all expected deliverables present and filled in?
2. **Technical consistency** - are the configurations, evidence and scripts consistent with each other and with the previous TDs?
3. **Script quality** - are the tests reproducible, well written, with error handling?
4. **Documentation** - are the technical choices justified and traced?

---

## 2. Strengths

### Organisation and structure

The folder structure is exemplary: clear separation between `controls/` (deployed configurations), `evidence/` (before/after evidence), `tests/` (reproducible scripts), `report/` (documentation) and `td6_collect/` (TD6 baseline). A reviewer can navigate the folder without ambiguity.

### Before/after evidence traceability

Having `*_baseline.txt` files in `evidence/baseline/` and `*_after.txt` files in `evidence/after/` allows a direct comparison between the initial state and the hardened state. Each claim in the TEST_CARDS is tied to a specific evidence file.

### Cross-TD consistency

The technical elements are consistent across the different TDs: SID 9000001 (introduced in TD3) is kept in TD5 and in the final pack. The Suricata interface `enp0s3` matches what was configured in TD3. The nginx certificate path (`/etc/nginx/certs/server.crt`) is identical to TD4. The X.509 certificate (same base64 content, same CN=td4.local, same expiry) is consistent between TD4 and the final pack.

### Regression script quality

The v2 scripts (`R1_firewall.sh`, `R2_tls.sh`, `R3_remote_access.sh`, `R4_detection.sh`) are well written:
- `set -u`: immediate failure on an undefined variable
- Explicit handling of return codes (`$?`)
- Clear and usable PASS/FAIL messages
- Output redirected to `results/$TIMESTAMP/` files for traceability

The fix of the v1 script bugs (`{SENSOR_USER}` variable not substituted, `grep-c` without a space) is documented in the README.

### Documentation of limitations

The folder honestly documents the technical limitations (expired certificate, static PSK, passive IDS) and proposes concrete corrective actions in the Risk_Register and the 30-60-90 plan. This transparency is a rare and important quality in a technical audit.

---

## 3. Areas for improvement

### IDS non-regression test (negative traffic)

Script R4 only validates that `curl http://10.10.20.10/admin` generates a SID 9000001 alert. A negative test is missing: making sure that a `curl http://10.10.20.10/` (without `/admin`) does *not* generate a SID 9000001 alert. Without this test, we cannot rule out an overly permissive rule that would alert on all HTTP traffic.

**Suggestion:**
```bash
# Check that a normal request does not trigger an alert
BEFORE=$(ssh student@10.10.20.50 "grep -c '\"signature_id\":9000001' /var/log/suricata/eve.json")
curl -s http://10.10.20.10/ > /dev/null
sleep 2
AFTER=$(ssh student@10.10.20.50 "grep -c '\"signature_id\":9000001' /var/log/suricata/eve.json")
[ "$AFTER" -eq "$BEFORE" ] && echo "PASS: no false positive" || echo "FAIL: false positive detected"
```

### HSTS max-age too short

The value `max-age=300` (5 minutes) matches the deployed nginx configuration, but is far from the recommendations (minimum 6 months, ideally 1 year). Even in a lab, a value of `max-age=86400` (1 day) would be more representative with no operational risk.

### No dhparam in nginx

The nginx configuration does not specify an `ssl_dhparam` file. Although ECDHE suites (which do not use classic DH) are preferred, the absence of this parameter should be explicitly documented as a deliberate choice or fixed.

### network_diagram.png missing

The file `architecture/network_diagram.png` is present but empty (0 bytes). A visual network diagram (even a simple one) would add significant value for an external reader trying to understand the architecture.

---

## 4. Reproducibility check

Scripts R1 and R2 could be checked logically - their assertions match exactly the outputs documented in the `*_after.txt` files. R3 and R4 depend on the network availability of the VMs, but their logic is correct and the `*_after.txt` files are consistent with the v2 scripts.

---

## 5. Conclusion

This folder is one of the most complete and rigorous in the class. The baseline → implementation → validation → evidence approach is applied systematically. The regression scripts are a real asset: they make it possible to re-validate the controls at any time, which is the definition of a reproducible infrastructure.

The areas for improvement (IDS negative test, HSTS, dhparam, network diagram) are minor and do not affect the overall quality of the work.

**Overall grade (indicative): 18/20**

*Deduction: -1 missing network diagram, -1 no IDS negative test*
