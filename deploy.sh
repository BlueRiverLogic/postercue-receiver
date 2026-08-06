#!/usr/bin/env bash
#
# Deploy the PosterCue Cast Web Receiver.
#
# ALWAYS deploy through this script (not a bare `git push`). It auto-stamps the
# RECEIVER_BUILD constant in index.html with a fresh UTC timestamp + your change
# tag, commits, pushes, and then POLLS THE LIVE ORIGIN until it serves the new
# stamp — so "deployed" means "actually published," not just "pushed."
#
# RECEIVER_BUILD is also surfaced in the receiver's `info` message (which the iOS
# app logs on every connect) and in the READY log line — so a test log can PROVE
# which build is live versus a cached/stale index.html on the device.
#
# Publishing is via GitHub Actions (.github/workflows/pages.yml → deploy-pages),
# NOT the legacy Jekyll branch builder — the legacy builder hard-failed on every
# push (2026-08-06) and silently served stale code for hours, which is exactly
# what the origin-verify step below now catches. Do NOT switch Pages back to the
# legacy/branch source (`gh api ... pages -f build_type=workflow` keeps it on
# Actions).
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
echo "🚀 Pushed ${STAMP} — GitHub Actions is publishing; verifying the live origin…"

# Verify the ORIGIN actually serves the new stamp (GitHub Actions build +
# CDN can take ~30-120s). This is the safeguard against the silent-stale-deploy
# failure: if this loop times out, the deploy did NOT publish — check the
# Actions run (`gh run list --workflow=pages.yml`) and Pages status.
URL="https://blueriverlogic.github.io/postercue-receiver/index.html"
for i in $(seq 1 30); do
  sleep 6
  if curl -fsS "${URL}?cb=$(date +%s%N)" -m 20 2>/dev/null | grep -q "var RECEIVER_BUILD = '${STAMP}';"; then
    echo "✅ Origin confirmed live: ${STAMP} (after ~$((i*6))s)"
    echo "   Now reboot/reconnect the Cast device and check the app log shows build=${STAMP}."
    exit 0
  fi
done
echo "❌ Origin did NOT serve ${STAMP} within ~180s — publish likely failed." >&2
echo "   Check: gh run list --workflow=pages.yml   and   gh api repos/BlueRiverLogic/postercue-receiver/pages" >&2
exit 1
