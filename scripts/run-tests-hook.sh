#!/usr/bin/env bash
# Stop-hook helper: run the web app unit tests when Claude finishes a turn
# and report the result back as a Claude system message (non-blocking).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || exit 0

out="$(make test 2>&1)"
code=$?

if [ "$code" -eq 0 ]; then
  count="$(printf '%s' "$out" | grep -Eo 'pass [0-9]+' | awk '{print $2}')"
  printf '{"suppressOutput":true,"systemMessage":%s}' \
    "$(printf '✅ make test — %s web tests passed' "${count:-all}" | jq -Rs .)"
else
  printf '{"systemMessage":%s}' \
    "$(printf '❌ make test FAILED:\n%s' "$(printf '%s' "$out" | tail -15)" | jq -Rs .)"
fi
