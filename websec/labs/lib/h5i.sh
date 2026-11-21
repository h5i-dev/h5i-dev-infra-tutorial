# Shared helpers for every `solve.sh`. Source it; do not run it.
#
# Each function exists because of a seam in the workbench, not because the labs
# have anything in common.
#
#   open_lab  open the lab in a new session and set $REQ0/$RES0 to the request
#          the page load made. Ids are not numbered from 0: Chromium's own
#          background traffic and /favicon.ico take ids too.
#   first  that id for any session, as `req_N`.
#   send   `websec replay` and then `websec show --raw` of the response it
#          created, so the output is exactly one HTTP message.
#   last   the newest request in the session, as `req_N`. Needed after a
#          `browser navigate`, which is the one thing `requests` does not name.
#   body   everything after the blank line of an HTTP message.
#   flag   the first FLAG{...} on standard input.
#   ready  wait for a lab to answer, so a run that started too early does not
#          read as a lab that resists.

H5I="${H5I:-h5i}"

# Fail loudly and early rather than at the first confusing empty result.
if ! "$H5I" websec --help >/dev/null 2>&1; then
    echo "This tutorial needs h5i with the websec plugin." >&2
    echo "  h5i plugin install websec --from ./h5i-websec   (see SETUP.md)" >&2
    echo "  or point H5I= at a build that has it: H5I=../h5i/target/release/h5i" >&2
    exit 2
fi

# send SESSION ID [replay flags...] -> the response as an HTTP message
send() {
    local session="$1" id="$2"
    shift 2
    local reply seq
    reply="$("$H5I" websec replay "$id" --session "$session" --json "$@")" || return 1
    seq="$(printf '%s' "$reply" | python3 -c \
        'import json,sys; print(json.load(sys.stdin).get("seq",""))')"
    [ -n "$seq" ] || { printf '%s\n' "$reply" >&2; return 1; }
    "$H5I" websec show "res_$seq" --session "$session" --raw
}

# last SESSION -> req_N for the newest stored message in the session
last() {
    "$H5I" websec requests --session "$1" --json | python3 -c '
import json, sys
rows = [r for r in json.load(sys.stdin)["requests"] if r.get("addressable")]
print("req_%d" % max(row["seq"] for row in rows))
'
}

# first SESSION -> req_N for the earliest stored message to a lab (127.0.0.1),
# skipping /favicon.ico, which Chromium asks for on its own.
first() {
    "$H5I" websec requests --session "$1" --json | python3 -c '
import json, sys
from urllib.parse import urlsplit
rows = [r for r in json.load(sys.stdin)["requests"]
        if r.get("addressable") and r.get("phase") == "request"
        and urlsplit(r["url"]).hostname == "127.0.0.1"
        and urlsplit(r["url"]).path != "/favicon.ico"]
print("req_%d" % min(row["seq"] for row in rows) if rows else "")
'
}

# open_lab SESSION URL [open flags...] -> sets REQ0 and RES0
#
# The proxy records a request a moment after Chromium sends it, so `first` can
# briefly see nothing right after `open`. Retry for a second before giving up.
open_lab() {
    local session="$1" url="$2"
    shift 2
    "$H5I" browser open "$url" --session "$session" --new "$@" >/dev/null || return 1
    REQ0=""
    for _ in $(seq 1 10); do
        REQ0="$(first "$session")"
        [ -n "$REQ0" ] && break
        sleep 0.2
    done
    [ -n "$REQ0" ] || { echo "open_lab: nothing from $url was stored" >&2; return 1; }
    RES0="res_${REQ0#req_}"
}

# The body of an HTTP message on standard input. Either line ending: h5i
# writes the request half with CRLF, because that half is a file
# `replay --raw-request` can read back, and the response half with LF.
body() {
    python3 -c '
import re, sys
print(re.split(r"\r?\n\r?\n", sys.stdin.read(), maxsplit=1)[-1], end="")
'
}

# The first flag on standard input.
flag() {
    python3 -c '
import re, sys
found = re.search(r"FLAG\{[A-Za-z0-9_.@!-]+\}", sys.stdin.read())
print(found.group(0) if found else "no flag found")
'
}

# jfield NAME — read one top-level field out of a JSON body on standard input.
jfield() {
    python3 -c '
import json, re, sys
raw = re.split(r"\r?\n\r?\n", sys.stdin.read(), maxsplit=1)[-1]
try:
    print(json.loads(raw).get(sys.argv[1], ""))
except Exception:
    print("")
' "$1"
}

# ready URL [SECONDS] — wait until the lab answers at all.
ready() {
    local url="$1" seconds="${2:-20}" waited=0
    while [ "$waited" -lt "$seconds" ]; do
        curl -fsS -o /dev/null --max-time 2 "$url" 2>/dev/null && return 0
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}

# Set $SESSION to a name unique to this run and arrange for it to be closed.
# Call it plainly — `new_session lab01` — not inside `$(...)`: a trap set in a
# subshell fires when the subshell ends, which is before the session exists.
new_session() {
    SESSION="${1:-lab}-$$"
    trap '"$H5I" browser close --session "$SESSION" >/dev/null 2>&1' EXIT
}
