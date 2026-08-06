#!/usr/bin/env bash
#
# Deploy the PosterCue Cast Web Receiver.
#
# ALWAYS deploy through this script (not a bare `git push`). It auto-stamps the
# RECEIVER_BUILD constant in index.html with a fresh UTC timestamp + your change
# tag, then commits and pushes to GitHub Pages. RECEIVER_BUILD is surfaced in the
# receiver's `info` message (which the iOS app logs on every connect) and in the
# READY log line — so a test log can PROVE which build is live versus a cached /
# stale index.html served by the CDN or the Cast device. Without a fresh stamp
# every deploy, you can't tell a landed change from a cached one (this bit us
# repeatedly: several "it still fails" tests were actually running old receiver
# code due to Pages/CDN/device caching).
#
# Usage:
#   ./deploy.sh "<short-change-tag>" "<commit message>"
# Example:
#   ./deploy.sh "gapless-swap" "Video: hold poster cover until first painted frame"
#
set -euo pipefail
cd "$(dirname "$0")"

TAG="${1:-update}"
MSG="${2:-Receiver: $TAG}"
STAMP="$(date -u +%Y-%m-%dT%H:%M)Z-${TAG}"

# Rewrite the single RECEIVER_BUILD line (any prior value → the new stamp).
sed -i '' -E "s|var RECEIVER_BUILD = '.*';|var RECEIVER_BUILD = '${STAMP}';|" index.html

if ! grep -q "var RECEIVER_BUILD = '${STAMP}';" index.html; then
  echo "❌ Failed to stamp RECEIVER_BUILD — is the constant still in index.html?" >&2
  exit 1
fi
echo "🔖 Stamped RECEIVER_BUILD = ${STAMP}"

git add -A
git commit -q -m "${MSG}

Receiver build: ${STAMP}

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin HEAD
echo "🚀 Deployed ${STAMP} — allow ~1 min for GitHub Pages, then confirm the build string in the app's info log."
