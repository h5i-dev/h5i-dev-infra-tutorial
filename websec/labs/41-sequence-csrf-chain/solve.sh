#!/usr/bin/env bash
# Lab 41 — four steps, one file. Each step resends the page request; the login
# cookie is carried forward by hand, from its Set-Cookie into a Cookie header.
set -uo pipefail
URL="${1:?usage: $0 http://127.0.0.1:9410}"
. "$(dirname "$0")/../lib/h5i.sh"
new_session lab41

open_lab "$SESSION" "$URL/"

# `resend` names a stored request by its sequence number, and the page load is
# not request 0 (the browser's own traffic takes lower numbers). Point every
# step at the page request this run actually captured.
FLOW="$(mktemp)"
trap 'rm -f "$FLOW"' EXIT
sed "s/\"resend\": 0/\"resend\": ${REQ0#req_}/g" "$(dirname "$0")/flow.json" > "$FLOW"

"$H5I" websec sequence "$FLOW" --session "$SESSION" --json \
    --var user=guest --var password=guest |
    python3 -c 'import json,sys
ran = json.load(sys.stdin)
print(next((s["bound"]["flag"] for s in ran.get("steps", [])
            if s.get("bound") and s["bound"].get("flag")), "no flag found"))'
