#!/bin/bash
# Dynamic DNS updater for Cloudflare
# Updates {hostname}.{domain} A record when public IP changes

# --- Configuration ---
CF_API_TOKEN="${CF_API_TOKEN}"
CF_ZONE_ID="${CF_ZONE_ID}"
DDNS_HOST="${CF_DDNS_HOSTNAME:-$(hostname)}"

# --- Validate config ---
if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ]; then
    echo "Error: CF_API_TOKEN and CF_ZONE_ID must be set"
    exit 1
fi

# --- Get domain from zone ---
DOMAIN=$(curl -s --max-time 10 \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}" \
    | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$DOMAIN" ]; then
    echo "Error: Could not get domain from zone ${CF_ZONE_ID}"
    exit 1
fi

FQDN="${DDNS_HOST}.${DOMAIN}"
IP_FILE="/tmp/cloudflare-ddns-${DDNS_HOST}.ip"

# --- Get current public IP ---
CURRENT_IP=$(curl -s -4 --max-time 10 https://ifconfig.me)
if [ -z "$CURRENT_IP" ]; then
    echo "Error: Could not determine public IP"
    exit 1
fi

# --- Check if IP changed ---
OLD_IP=""
[ -f "$IP_FILE" ] && OLD_IP=$(cat "$IP_FILE")

if [ "$CURRENT_IP" = "$OLD_IP" ]; then
    exit 0
fi

echo "$(date): IP changed from ${OLD_IP:-unknown} to ${CURRENT_IP} for ${FQDN}"

# --- Get DNS record ID ---
API_RESPONSE=$(curl -s --max-time 10 \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${FQDN}")

RECORD_ID=$(echo "$API_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$RECORD_ID" ]; then
    echo "Error: Could not find DNS record for ${FQDN}"
    echo "API response: ${API_RESPONSE}"
    exit 1
fi

# --- Update DNS record ---
RESPONSE=$(curl -s --max-time 10 -X PUT \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"A\",\"name\":\"${FQDN}\",\"content\":\"${CURRENT_IP}\",\"ttl\":300}" \
    "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${RECORD_ID}")

if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "$CURRENT_IP" > "$IP_FILE"
    echo "$(date): Updated ${FQDN} to ${CURRENT_IP}"
else
    echo "Error: Failed to update DNS record"
    echo "$RESPONSE"
    exit 1
fi
