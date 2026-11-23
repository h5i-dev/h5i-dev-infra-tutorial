#!/usr/bin/env bash
# Lab 05 — Scrape This Site, Hockey Teams: drive the form once, then stop
# using it.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

SITE="https://www.scrapethissite.com/pages/forms/"
QUERY="${QUERY:-New York}"
PAGES="${PAGES:-2}"

session hockey05 "$SITE"

# Step one: use the form, once, to find out what the form does.
#
# A @ref comes from a snapshot and names an element in *that* reading of the
# page. Take it from the snapshot you are about to act on, and take it by what
# the element is — `textbox` — rather than by counting lines.
ref="$("$H5I" browser snapshot -i --session "$SESSION" 2>/dev/null \
    | sed -n 's/.*- textbox .*\[ref=\([a-z0-9]*\)\].*/\1/p' | head -1)"
[ -n "$ref" ] || { echo "no search box on $SITE — the page changed" >&2; exit 1; }

# Remember where the log was, so we can read only what the form caused.
since="$("$H5I" browser requests --session "$SESSION" --json \
    | python3 -c 'import json,sys; print(max([r["seq"] for r in json.load(sys.stdin)["requests"]] or [0]))')"

"$H5I" browser type "@$ref" "$QUERY" --session "$SESSION" >/dev/null 2>&1 || exit 1
"$H5I" browser press Enter --session "$SESSION" >/dev/null 2>&1 || exit 1

# What did that submission send? The request log has the answer, method and
# URL, written by the proxy as the bytes left. That is more trustworthy than
# reading the address bar, because it is what the server actually received.
target="$("$H5I" browser requests --session "$SESSION" --since "$since" --json | python3 -c '
import json, sys
page = sys.argv[1]
sent = [r for r in json.load(sys.stdin)["requests"]
        if r["phase"] == "request" and r["allowed"] and r["url"].startswith(page + "?")]
if not sent:
    sys.exit("the form sent nothing to %s" % page)
print("# the form is a %s: %s" % (sent[0]["method"], sent[0]["url"]), file=sys.stderr)
print(sent[0]["url"])
' "$SITE")" || exit 1

# Step two: stop typing. The form put the search into the query string, so
# every later page is a URL you can build. `page_num` is the site's own
# pagination parameter, visible in the pager links.
SCHEMA='{"teams": [{"selector": "tr.team", "fields": {
  "team": "td.name", "year": "td.year", "wins": "td.wins",
  "losses": "td.losses", "pct": "td.pct"}}]}'

header=1
for n in $(seq 1 "$PAGES"); do
    pace
    answer="$(extract "$SCHEMA" --url "$target&page_num=$n" 2>/dev/null)" || break
    printf '%s' "$answer" | python3 -c '
import csv, json, sys
out = csv.DictWriter(sys.stdout, ["team", "year", "wins", "losses", "pct"], lineterminator="\n")
if sys.argv[1] == "1":
    out.writeheader()
out.writerows(json.load(sys.stdin)["teams"])
' "$header"
    header=0
done
