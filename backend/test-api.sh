#!/bin/bash

BASE_URL="http://localhost:3000"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "1. Testing GET /health"
response=$(curl -s -w "\n%{http_code}" "$BASE_URL/health")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}PASS${NC} - Status: $http_code"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
else
    echo -e "${RED}FAIL${NC} - Status: $http_code"
    echo "$body"
fi
echo ""

echo "2. Testing GET /campaigns (Initial)"
response=$(curl -s -w "\n%{http_code}" "$BASE_URL/campaigns")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}PASS${NC} - Status: $http_code"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
else
    echo -e "${RED}FAIL${NC} - Status: $http_code"
    echo "$body"
fi
echo ""

echo "3. Testing POST /campaigns"
if command -v node &> /dev/null; then
    FUTURE_DEADLINE=$(node -e "console.log(Math.floor(Date.now() / 1000) + 86400)")
else
    FUTURE_DEADLINE=$(($(date +%s) + 86400))
fi

response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/campaigns" \
    -H "Content-Type: application/json" \
    -d "{\"goalAmount\":\"1000000000000000000\",\"deadline\":\"$FUTURE_DEADLINE\",\"title\":\"API Test Campaign\",\"description\":\"Created via test script\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}PASS${NC} - Status: $http_code"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
    CAMPAIGN_ID=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('campaignId', '0'))" 2>/dev/null || echo "0")
else
    echo -e "${RED}FAIL${NC} - Status: $http_code"
    echo "$body"
    CAMPAIGN_ID="0"
fi
echo ""
sleep 2

echo "4. Testing GET /campaigns (After Creation)"
response=$(curl -s -w "\n%{http_code}" "$BASE_URL/campaigns")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}PASS${NC} - Status: $http_code"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
else
    echo -e "${RED}FAIL${NC} - Status: $http_code"
    echo "$body"
fi
echo ""

echo "5. Testing POST /contribute"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/contribute" \
    -H "Content-Type: application/json" \
    -d "{\"campaignId\":$CAMPAIGN_ID,\"amount\":\"500000000000000000\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}PASS${NC} - Status: $http_code"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
else
    echo -e "${RED}FAIL${NC} - Status: $http_code"
    echo "$body"
fi
echo ""
sleep 2

echo "6. Testing GET /campaigns (After Contribution)"
response=$(curl -s -w "\n%{http_code}" "$BASE_URL/campaigns")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}PASS${NC} - Status: $http_code"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
else
    echo -e "${RED}FAIL${NC} - Status: $http_code"
    echo "$body"
fi
