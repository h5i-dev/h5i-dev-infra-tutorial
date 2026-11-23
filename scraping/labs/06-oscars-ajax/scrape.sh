#!/usr/bin/env bash
# Lab 06 — Scrape This Site, Oscar Winning Films: click once, take the request
# the click made, and stop clicking.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

SITE="https://www.scrapethissite.com/pages/ajax-javascript/"
YEARS="${YEARS:-2015 2014}"
FIRST="${YEARS%% *}"

# jQuery comes from ajax.googleapis.com, which this session does not grant
# itself. Without `--allow` the script is refused at the proxy, `h5i browser
# requests` says so in as many words, and every click afterwards reads as "the
# site has no data" — which is the worst way for a scraper to fail. Name the
# origin.
session oscars06 "$SITE" --allow https://ajax.googleapis.com

jq="$("$H5I" browser eval 'typeof window.jQuery' --session "$SESSION" 2>/dev/null)"
echo "# typeof jQuery: $jq" >&2

since="$("$H5I" browser requests --session "$SESSION" --json \
    | python3 -c 'import json,sys; print(max([r["seq"] for r in json.load(sys.stdin)["requests"]] or [0]))')"

# Step one: do it the way a person would, once. The year links have numeric
# ids, and `#2015` is not a valid CSS selector (an id selector may not start
# with a digit), so ask for the attribute instead.
if ! err="$("$H5I" browser click "[id=\"$FIRST\"]" --session "$SESSION" 2>&1 >/dev/null)"; then
    echo "$err" >&2; exit 1
fi
"$H5I" browser wait-for --selector 'tr.film' --session "$SESSION" >/dev/null 2>&1 \
    || echo "# no films appeared after the click" >&2
films="$(extract '{"t": ["tr.film td.film-title"]}' 2>/dev/null \
    | python3 -c 'import json,sys
try: print(len(json.load(sys.stdin)["t"]))
except Exception: print(0)')"
echo "# films on the page after the click: $films" >&2

# Step two: what did the click send? The proxy wrote it down before the bytes
# left, with a sequence number. That number is a handle on the exact request
# the page's own code built: its method, headers and cookies included.
seq="$("$H5I" browser requests --session "$SESSION" --since "$since" --json | python3 -c '
import json, sys
hits = [r for r in json.load(sys.stdin)["requests"]
        if r["phase"] == "request" and r["allowed"] and "ajax=true" in r["url"]]
if not hits:
    sys.exit("# the click sent no ?ajax=true request — read the log: h5i browser requests")
print("# the click sent: %s %s  (seq %d)" % (hits[0]["method"], hits[0]["url"], hits[0]["seq"]), file=sys.stderr)
print(hits[0]["seq"])
')" || exit 1

# Step three: stop clicking. `resend` sends that same request again with one
# part changed, through the same proxy and policy, and answers with what came
# back. One request per year, JSON out, no rendering, no 1.5-second delay.
echo "year,title,awards,nominations,best_picture"
for year in $YEARS; do
    pace
    "$H5I" browser resend "$seq" --set "query.year=$year" --session "$SESSION" --json | python3 -c '
import csv, json, sys
reply = json.load(sys.stdin)
res = reply["response"]
if res["status"] != 200:
    sys.exit("year %s: HTTP %s" % (sys.argv[1], res["status"]))
if res["body_truncated"]:
    # `resend` answers with a preview of the body, not all of it. These years
    # are well under the limit; a bigger answer needs `served` instead.
    sys.exit("year %s: the body was truncated at %d bytes" % (sys.argv[1], len(res["body_preview"])))
out = csv.writer(sys.stdout, lineterminator="\n")
for film in json.loads(res["body_preview"]):
    out.writerow([film["year"], film["title"].strip(), film["awards"],
                  film["nominations"], film.get("best_picture", False)])
' "$year" || exit 1
done
