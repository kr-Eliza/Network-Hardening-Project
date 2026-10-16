#!/bin/bash
set -u

WEB_TARGET="10.10.20.10"
SENSOR_IP="10.10.20.50"
SENSOR_USER="student"
SURICATA_LOG="/var/log/suricata/eve.json"
SID="9000001"

echo "=== R4 Detection Regression ==="
echo "Claim: IDS detects HTTP requests to /admin with Suricata SID ${SID}"
echo "Web target: ${WEB_TARGET}"
echo "Sensor: ${SENSOR_USER}@${SENSOR_IP}"
echo "Telemetry: ${SURICATA_LOG}"
echo ""

remote_count() {
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "${SENSOR_USER}@${SENSOR_IP}" \
        "grep -c '\"signature_id\":${SID}' ${SURICATA_LOG} 2>/dev/null || true"
}

remote_tail() {
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "${SENSOR_USER}@${SENSOR_IP}" \
        "grep '\"signature_id\":${SID}' ${SURICATA_LOG} | tail -n 5" 2>/dev/null || true
}

echo "[TEST 1] Count existing alerts for SID ${SID}"
BEFORE_RAW=$(remote_count)
BEFORE_COUNT=$(echo "$BEFORE_RAW" | tail -n 1 | tr -dc '0-9')
[ -z "$BEFORE_COUNT" ] && BEFORE_COUNT=0
echo "Before count: $BEFORE_COUNT"
echo ""

echo "[TEST 2] Trigger known suspicious request"
curl -s "http://${WEB_TARGET}/admin" > /dev/null
sleep 3
echo "Trigger sent to http://${WEB_TARGET}/admin"
echo ""

echo "[TEST 3] Count alerts after trigger"
AFTER_RAW=$(remote_count)
AFTER_COUNT=$(echo "$AFTER_RAW" | tail -n 1 | tr -dc '0-9')
[ -z "$AFTER_COUNT" ] && AFTER_COUNT=0
echo "After count: $AFTER_COUNT"
echo ""

if [ "$AFTER_COUNT" -le "$BEFORE_COUNT" ]; then
    echo "FAIL: no new IDS alert detected for SID ${SID}"
    echo ""
    echo "[DEBUG] Last matching alert lines currently present:"
    remote_tail
    exit 1
fi

echo "PASS: IDS detected the generated test traffic"
echo ""

echo "[TEST 4] Show last matching alert lines"
remote_tail
echo ""

echo "R4 completed successfully"
exit 0
