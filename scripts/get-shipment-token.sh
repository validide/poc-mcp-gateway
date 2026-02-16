#!/usr/bin/env bash
# Manually fetch a bearer token for the Shipment Data API via OAuth2
# client_credentials and print it.
#
# In normal operation, the shipment-token-refresh sidecar handles this
# automatically. This script is useful for testing outside Docker.
#
# Usage: ./scripts/get-shipment-token.sh
#
# Required env vars (or set them in .env first):
#   SHIPMENT_TOKEN_URL    (e.g. https://auth.qa.nshiftportal.dev/connect/token)
#   SHIPMENT_CLIENT_ID
#   SHIPMENT_CLIENT_SECRET
#   SHIPMENT_SCOPE        (optional)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$ROOT_DIR/.env"

# Load existing .env if present
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

: "${SHIPMENT_TOKEN_URL:?Set SHIPMENT_TOKEN_URL}"
: "${SHIPMENT_CLIENT_ID:?Set SHIPMENT_CLIENT_ID}"
: "${SHIPMENT_CLIENT_SECRET:?Set SHIPMENT_CLIENT_SECRET}"
: "${SHIPMENT_SCOPE:=}"

echo "Requesting token from $SHIPMENT_TOKEN_URL ..."

BODY="grant_type=client_credentials&client_id=$SHIPMENT_CLIENT_ID&client_secret=$SHIPMENT_CLIENT_SECRET"
if [[ -n "$SHIPMENT_SCOPE" ]]; then
  BODY="$BODY&scope=$SHIPMENT_SCOPE"
fi

RESPONSE=$(curl -s -X POST "$SHIPMENT_TOKEN_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "$BODY")

ACCESS_TOKEN=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "ERROR: Failed to extract access_token from response:"
  echo "$RESPONSE"
  exit 1
fi

echo ""
echo "Bearer $ACCESS_TOKEN"
