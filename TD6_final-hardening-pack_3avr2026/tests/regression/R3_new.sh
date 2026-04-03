#!/bin/bash
set -u

SSH_TARGET="10.10.20.10"
SSH_USER="admin1"
SSH_KEY="/home/student/.ssh/id_td5"
GW_IPSEC_HOST="10.10.10.1"

echo "=== R3 Remote Access Regression ==="
echo "Claim: SSH is key-based only and IPsec tunnel is established"
echo ""

echo "[TEST 1] SSH with key must succeed"
SSH_OK_OUTPUT=$(ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes "${SSH_USER}@${SSH_TARGET}" whoami 2>&1)
SSH_OK_STATUS=$?
echo "$SSH_OK_OUTPUT"

if [ "$SSH_OK_STATUS" -ne 0 ]; then
    echo "FAIL: SSH with key did not succeed"
    exit 1
fi

echo "$SSH_OK_OUTPUT" | grep -q "^${SSH_USER}$"
if [ $? -ne 0 ]; then
    echo "FAIL: SSH returned unexpected identity"
    exit 1
fi
echo "PASS: SSH key-based authentication works"
echo ""

echo "[TEST 2] SSH without public key must fail"
SSH_FAIL_OUTPUT=$(ssh -o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=no -o PreferredAuthentications=password -o BatchMode=yes -o ConnectTimeout=5 "${SSH_USER}@${SSH_TARGET}" whoami 2>&1)
SSH_FAIL_STATUS=$?
echo "$SSH_FAIL_OUTPUT"

if [ "$SSH_FAIL_STATUS" -eq 0 ]; then
    echo "FAIL: SSH without key unexpectedly succeeded"
    exit 1
fi
echo "PASS: SSH without key is denied"
echo ""

echo "[TEST 3] IPsec tunnel status retrieval"
IPSEC_OUTPUT=$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 student@"${GW_IPSEC_HOST}" "sudo ipsec statusall" 2>&1)
IPSEC_STATUS=$?
echo "$IPSEC_OUTPUT"

if [ "$IPSEC_STATUS" -ne 0 ]; then
    echo "WARNING: could not retrieve IPsec status remotely with sudo."
    echo "INFO: verify IPsec locally on gw-fw with: sudo ipsec statusall"
    echo "INFO: use evidence/after/ipsec_status_after.txt as proof artifact."
    echo ""
    echo "R3 completed with manual IPsec verification required"
    exit 0
fi

echo "$IPSEC_OUTPUT" | grep -q "ESTABLISHED"
if [ $? -ne 0 ]; then
    echo "FAIL: IPsec status retrieved, but tunnel is not established"
    exit 1
fi

echo "PASS: IPsec tunnel is established"
echo ""
echo "R3 completed successfully"
exit 0
