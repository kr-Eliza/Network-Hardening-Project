#!/bin/bash
set -u

TARGET_IP="10.10.20.10"
HTTPS_PORT="8443"
BLOCKED_PORT="3306"

echo "=== R1 Firewall Regression ==="
echo "Claim: authorized HTTPS flow works and forbidden ports are blocked"
echo "Target: ${TARGET_IP}"
echo ""

echo "[TEST 1] Allowed HTTPS flow to ${TARGET_IP}:${HTTPS_PORT}"
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "https://${TARGET_IP}:${HTTPS_PORT}")
echo "Observed HTTP code: ${HTTP_CODE}"

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "301" ] && [ "$HTTP_CODE" != "302" ]; then
    echo "FAIL: HTTPS flow did not succeed as expected"
    exit 1
fi
echo "PASS: HTTPS flow succeeded"
echo ""

echo "[TEST 2] Forbidden port ${BLOCKED_PORT} must be blocked"
NC_OUTPUT=$(nc -vz -w 3 "${TARGET_IP}" "${BLOCKED_PORT}" 2>&1)
NC_STATUS=$?
echo "$NC_OUTPUT"

if [ "$NC_STATUS" -eq 0 ]; then
    echo "FAIL: forbidden port ${BLOCKED_PORT} is reachable"
    exit 1
fi
echo "PASS: forbidden port ${BLOCKED_PORT} is blocked"
echo ""

echo "R1 completed successfully"
exit 0
