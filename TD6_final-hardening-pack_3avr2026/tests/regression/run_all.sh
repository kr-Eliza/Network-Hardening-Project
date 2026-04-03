#!/bin/bash
# run_all.sh — TD6 Regression Suite
# Exécuter depuis la racine du dossier final-hardening-pack/
# Prérequis : accès réseau aux VMs (10.10.20.10, 10.10.10.1, 10.10.20.50)
#             clé SSH /home/student/.ssh/id_td5 présente
set -u

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="tests/regression/results/${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"

PASS=0
FAIL=0

echo "=== TD6 Regression Suite ==="
echo "Timestamp: $TIMESTAMP"
echo "Results directory: $RESULTS_DIR"
echo ""

run_test() {
    local script="$1"
    local name="$2"

    echo "Running $name ..."
    if bash "$script" > "$RESULTS_DIR/${name}.txt" 2>&1; then
        echo "[PASS] $name"
        PASS=$((PASS+1))
    else
        echo "[FAIL] $name"
        FAIL=$((FAIL+1))
    fi
    echo ""
}

run_test tests/regression/R1_firewall.sh      "R1_firewall"
run_test tests/regression/R2_tls.sh           "R2_tls"
run_test tests/regression/R3_remote_access.sh "R3_remote_access"
run_test tests/regression/R4_detection.sh     "R4_detection"

echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Results saved in: $RESULTS_DIR"

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi

exit 0
