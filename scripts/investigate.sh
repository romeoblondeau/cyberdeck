#!/bin/bash
source ~/.env_scripts
if [ -z "$1" ]; then
    echo "Usage: ./investigate.sh <IP>"
    exit 1
fi
IP=$1
echo "=== AbuseIPDB ==="
curl -s -G https://api.abuseipdb.com/api/v2/check \
  --data-urlencode "ipAddress=$IP" \
  -d maxAgeInDays=90 \
  -H "Key: $ABUSEIPDB_API_KEY" \
  -H "Accept: application/json" | jq '{
    ip: .data.ipAddress,
    pays: .data.countryCode,
    isp: .data.isp,
    domaine: .data.domain,
    score: .data.abuseConfidenceScore,
    signalements: .data.totalReports,
    utilisateurs: .data.numDistinctUsers,
    derniere_activite: .data.lastReportedAt
  }'
echo ""
echo "=== WHOIS ==="
whois $IP | grep -iE "descr|country|netname|cidr|org|address|route" | head -15
echo ""
echo "=== SHODAN ==="
echo "https://www.shodan.io/host/$IP"
