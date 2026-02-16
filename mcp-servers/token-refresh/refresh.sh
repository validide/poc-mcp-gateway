#!/bin/sh
# Token refresh sidecar - fetches OAuth2 client_credentials token on a loop
# and writes the raw token to a shared file for AgentGateway to read.
# AgentGateway adds the "Bearer " prefix automatically via backendAuth: key.
# If credentials are not configured, seeds an empty placeholder and sleeps.
set -u

TOKEN_URL="${TOKEN_URL:-}"
CLIENT_ID="${CLIENT_ID:-}"
CLIENT_SECRET="${CLIENT_SECRET:-}"
SCOPE="${SCOPE:-}"
TOKEN_FILE="${TOKEN_FILE:-/shared/shipment-token}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-300}"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*"; }

# Always seed the token file so the gateway can start
if [ ! -f "$TOKEN_FILE" ]; then
  printf "none" > "$TOKEN_FILE"
  log "Seeded empty token file at $TOKEN_FILE"
fi

# If credentials are not configured, just keep the container alive
if [ -z "$TOKEN_URL" ] || [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  log "WARNING: SHIPMENT_TOKEN_URL, SHIPMENT_CLIENT_ID, or SHIPMENT_CLIENT_SECRET not set."
  log "Token refresh disabled. Set credentials in .env and restart this service."
  # Sleep forever to keep container running (and the seeded file available)
  while true; do sleep 3600; done
fi

fetch_token() {
  if [ -n "$SCOPE" ]; then
    RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
      --data-urlencode "grant_type=client_credentials" \
      --data-urlencode "client_id=${CLIENT_ID}" \
      --data-urlencode "client_secret=${CLIENT_SECRET}" \
      --data-urlencode "scope=${SCOPE}" 2>&1)
  else
    RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
      --data-urlencode "grant_type=client_credentials" \
      --data-urlencode "client_id=${CLIENT_ID}" \
      --data-urlencode "client_secret=${CLIENT_SECRET}" 2>&1)
  fi

  if [ $? -ne 0 ]; then
    log "ERROR: Token request failed (curl error): $RESPONSE"
    return 1
  fi

  # Extract access_token using lightweight JSON parsing
  ACCESS_TOKEN=$(echo "$RESPONSE" | sed -n 's/.*"access_token"\s*:\s*"\([^"]*\)".*/\1/p')

  if [ -z "$ACCESS_TOKEN" ]; then
    log "ERROR: No access_token in response: $RESPONSE"
    return 1
  fi

  # Extract expires_in if present
  EXPIRES_IN=$(echo "$RESPONSE" | sed -n 's/.*"expires_in"\s*:\s*\([0-9]*\).*/\1/p')

  # Write token atomically (write to temp, then rename)
  TEMP_FILE="${TOKEN_FILE}.tmp"
  printf "%s" "$ACCESS_TOKEN" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$TOKEN_FILE"

  if [ -n "$EXPIRES_IN" ]; then
    log "Token refreshed (expires in ${EXPIRES_IN}s), written to $TOKEN_FILE"
    # Refresh at 75% of expiry, but at least every 30s and at most every REFRESH_INTERVAL
    NEXT=$(( EXPIRES_IN * 3 / 4 ))
    [ "$NEXT" -lt 30 ] && NEXT=30
    [ "$NEXT" -gt "$REFRESH_INTERVAL" ] && NEXT="$REFRESH_INTERVAL"
    REFRESH_INTERVAL="$NEXT"
  else
    log "Token refreshed, written to $TOKEN_FILE"
  fi
}

log "Starting token refresh loop (interval: ${REFRESH_INTERVAL}s)"
log "Token URL: $TOKEN_URL"
log "Client ID: $CLIENT_ID"
log "Token file: $TOKEN_FILE"

while true; do
  fetch_token || log "Will retry in ${REFRESH_INTERVAL}s"
  sleep "$REFRESH_INTERVAL"
done
