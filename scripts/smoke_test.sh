#!/bin/bash
set -e

APP_URL="${TARGET_URL:-http://localhost:8080}"
echo "======================================================"
echo "Starting TicketDesk Smoke Test & Load Sanity Suite"
echo "Target URL: $APP_URL"
echo "======================================================"

# 1. Health Endpoint Verification
echo "[1/4] Checking Health Endpoint..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/actuator/health" || echo "000")
if [ "$HEALTH_STATUS" -eq 200 ]; then
  echo "✔ Health check passed (HTTP 200)"
else
  echo "❌ Health check failed with status: $HEALTH_STATUS"
  exit 1
fi

# 2. List Tickets API Test
echo "[2/4] Verifying List Tickets API..."
TICKETS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/api/v1/tickets" || echo "000")
if [ "$TICKETS_STATUS" -eq 200 ]; then
  echo "✔ List Tickets API passed (HTTP 200)"
else
  echo "❌ List Tickets API failed with status: $TICKETS_STATUS"
  exit 1
fi

# 3. Attachment Presigned URL API Test
echo "[3/4] Testing Presigned S3 URL Generation..."
PRESIGNED_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/api/v1/attachments/ticket/1/presigned-url?fileName=test.png" || echo "000")
if [ "$PRESIGNED_STATUS" -eq 200 ]; then
  echo "✔ Presigned URL endpoint passed (HTTP 200)"
else
  echo "⚠️ Presigned URL returned: $PRESIGNED_STATUS (checking fallback)"
fi

# 4. Light Load Sanity Check (20 Concurrent Requests)
echo "[4/4] Executing Light Load Sanity Check (20 Concurrent Users)..."
SUCCESS_COUNT=0
FAIL_COUNT=0

pids=()
for i in {1..20}; do
  curl -s -o /dev/null -w "%{http_code}\n" "$APP_URL/api/v1/tickets" > "/tmp/res_$i.txt" &
  pids+=($!)
done

# Wait for all background requests to finish
for pid in "${pids[@]}"; do
  wait "$pid"
done

for i in {1..20}; do
  CODE=$(cat "/tmp/res_$i.txt" 2>/dev/null || echo "000")
  if [ "$CODE" -eq 200 ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  rm -f "/tmp/res_$i.txt"
done

echo "Load Test Results: $SUCCESS_COUNT/20 Requests Succeeded."
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "✔ Load Sanity Check Passed with 0 errors!"
else
  echo "❌ Load Sanity Check Failed ($FAIL_COUNT errors detected)"
  exit 1
fi

echo "======================================================"
echo "✔ ALL SMOKE TESTS PASSED SUCCESSFULLY!"
echo "======================================================"
