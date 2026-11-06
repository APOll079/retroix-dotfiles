#!/bin/sh
# Security audit for SecurityAudit.qml: runs arch-audit (read only) and prints its text in two marked sections.
#   secaudit.sh
# Output (stdout, always exit 0):
#   ##not-installed                  arch-audit is not installed (the caller stays silent)
#   ##plain                          then the output of `arch-audit`
#   ##upgradable                     then the output of `arch-audit --upgradable` (the lines that also say "Update to <version>!")
#   ##error <one line>               arch-audit failed (no network for the security tracker, ...)
# arch-audit lines look like:  Package gnutls is affected by CVE-2024-0553, CVE-2024-0567. High risk!
#                         and:  Package openssl is affected by CVE-2023-5678. Medium risk! Update to 3.1.4-1!
# SecurityAudit.qml parses them; nothing else is read or written here.
command -v arch-audit >/dev/null 2>&1 || { echo "##not-installed"; exit 0; }
plain=$(timeout 60 arch-audit 2>&1 </dev/null)
rc=$?
# arch-audit exits non-zero when it finds vulnerable packages, so judge by the text: a failure prints no "Package ..." line and no 'nothing' output
if [ "$rc" -ne 0 ] && ! printf '%s\n' "$plain" | grep -q '^Package '; then
    if [ -n "$plain" ]; then
        printf '##error %s\n' "$(printf '%s\n' "$plain" | head -n 1)"
        exit 0
    fi
fi
upg=$(timeout 60 arch-audit --upgradable 2>/dev/null </dev/null)
echo "##plain"
printf '%s\n' "$plain"
echo "##upgradable"
printf '%s\n' "$upg"
exit 0
