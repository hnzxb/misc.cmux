#!/bin/bash
set -uo pipefail
APP_SRC="/tmp/cmux-artifact/unz/cmux DEV ci-fix.app"
ARCHIVE="$HOME/hnzxb/misc.cmux/archive/$(date +%Y-%m-%d)"
LOG=/tmp/replace-cmux.log
exec >>"$LOG" 2>&1
echo "=== replace start $(date) ==="
mkdir -p "$ARCHIVE"
osascript -e 'tell application "cmux" to quit' || true
for i in $(seq 1 20); do pgrep -x cmux >/dev/null || break; sleep 1; done
pgrep -x cmux >/dev/null && { pkill -x cmux; sleep 2; pkill -9 -x cmux 2>/dev/null || true; sleep 1; }
mv /Applications/cmux.app "$ARCHIVE/cmux.app" || { echo "archive failed"; exit 1; }
cp -R "$APP_SRC" /Applications/cmux.app || { echo "install failed, rolling back"; mv "$ARCHIVE/cmux.app" /Applications/cmux.app; exit 1; }
xattr -cr /Applications/cmux.app
codesign --force --sign - --timestamp=none --generate-entitlement-der /Applications/cmux.app >/dev/null 2>&1 || true
spctl --add /Applications/cmux.app 2>/dev/null || true
echo "installed:"; /usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' -c 'Print CFBundleShortVersionString' /Applications/cmux.app/Contents/Info.plist
open -a /Applications/cmux.app
echo "=== replace done $(date) ==="
