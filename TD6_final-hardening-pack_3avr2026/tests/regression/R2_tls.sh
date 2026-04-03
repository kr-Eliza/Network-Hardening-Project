#!/bin/bash
set -u

TARGET="10.10.20.10:8443"

echo "=== R2 TLS Regression ==="
echo "Claim: HTTPS endpoint on 8443 enforces modern TLS and returns HSTS"
echo "Target: ${TARGET}"
echo ""

echo "[TEST 1] TLS 1.2 must be accepted"
TLS12_OUTPUT=$(openssl s_client -connect "${TARGET}" -tls1_2 </dev/null 2>&1)
echo "$TLS12_OUTPUT" | grep -E "Protocol|Cipher|Verify return code" || true

echo "$TLS12_OUTPUT" | grep -q "Protocol *: TLSv1.2"
TLS12_STATUS=$?

if [ "$TLS12_STATUS" -ne 0 ]; then
    echo "FAIL: TLS 1.2 was not negotiated successfully"
    exit 1
fi
echo "PASS: TLS 1.2 accepted"
echo ""

echo "[TEST 2] TLS 1.0 must be rejected"
TLS10_OUTPUT=$(openssl s_client -connect "${TARGET}" -tls1 </dev/null 2>&1)
echo "$TLS10_OUTPUT" | grep -E "Protocol|Cipher|Verify return code|alert|handshake failure|wrong version|unsupported" || true

echo "$TLS10_OUTPUT" | grep -Eqi "alert|handshake failure|wrong version|unsupported protocol|no protocols available"
TLS10_STATUS=$?

if [ "$TLS10_STATUS" -ne 0 ]; then
    echo "FAIL: TLS 1.0 does not appear to be rejected"
    exit 1
fi
echo "PASS: TLS 1.0 rejected"
echo ""

echo "[TEST 3] HSTS header must be present"
HEADERS=$(curl -skI --max-time 5 "https://${TARGET}")
echo "$HEADERS"

echo "$HEADERS" | grep -qi "strict-transport-security"
HSTS_STATUS=$?

if [ "$HSTS_STATUS" -ne 0 ]; then
    echo "FAIL: HSTS header not found"
    exit 1
fi
echo "PASS: HSTS header present"
echo ""

echo "R2 completed successfully"
exit 0
