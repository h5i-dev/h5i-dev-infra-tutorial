#!/usr/bin/env bash
# Lab 06 — Scrape This Site, Oscar Winning Films: a click that loads a table,
# and the request underneath it.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

SITE="https://www.scrapethissite.com/pages/ajax-javascript/"
YEAR="${YEAR:-2015}"

# jQuery comes from ajax.googleapis.com, which this session does not grant
# itself. Without `--allow` the script never arrives, `h5i browser requests`
# says so in as many words, and every later step reads as "the site has no
# data", which is the worst way for a scraper to fail. Name the origin.
session oscars06 "$SITE" --allow https://ajax.googleapis.com
echo "# jQuery in the page: $(js 'typeof window.jQuery')" >&2

# Step one: try it the way a person would. Click the year, wait for the rows.
ref="$("$H5I" browser snapshot --interactive --session oscars06 2>/dev/null \
    | sed -n "s/.*- link \"$YEAR\" \[ref=\([a-z0-9]*\)\].*/\1/p" | head -1)"
[ -n "$ref" ] || { echo "no link for $YEAR on $SITE" >&2; exit 1; }

"$H5I" browser click "@$ref" --session oscars06 --json >/dev/null
# The site waits 1.5s on purpose. `wait-for` gives up after 30s, so poll
# for five instead: a click that worked has drawn the table by then.
for _ in 1 2 3 4 5; do
    got="$(js 'document.querySelectorAll("tr.film").length')"
    [ "$got" -gt 0 ] && break
    sleep 1
done
echo "# films after the click: $got" >&2

# Step two: ask the request log what the click fetched. That URL, not the
# table, is the thing to scrape.
call="$("$H5I" browser requests --url-contains 'ajax=true' --session oscars06 --json \
    | python3 -c 'import json,sys
rows = [r["url"] for r in json.load(sys.stdin)["requests"] if r["phase"] == "request"]
print(rows[-1] if rows else "")')"

# When the click fetched nothing, the handler is still in the response the
# server sent, and the URL is written there in plain text.
if [ -z "$call" ]; then
    echo "# the click fired no request. The handler is in the page's own script:" >&2
    response "$SITE" | python3 -c '
import re, sys
js = sys.stdin.read()
call = re.search(r"\$\.ajax\(\{.*?\}\);", js, re.S)
for line in (call.group(0) if call else "no $.ajax call in the page").splitlines()[:12]:
    print("#   " + line.strip().replace("\\", ""))
' >&2
    call="$SITE?ajax=true&year=$YEAR"
    pace
    "$H5I" browser navigate "$call" --session oscars06 --json >/dev/null || exit 1
fi
echo "# the data is one GET: $call" >&2

# The endpoint answers JSON, typed, one request per year. The body is already
# in the capture, so reading it costs no second request.
response "ajax=true&year=$YEAR" | python3 -c '
import csv, json, sys
films = json.load(sys.stdin)
out = csv.DictWriter(sys.stdout, ["year", "title", "awards", "nominations", "best_picture"],
                     extrasaction="ignore", lineterminator="\n")
out.writeheader()
for film in films:
    film.setdefault("best_picture", False)
    film["title"] = film["title"].strip()
    out.writerow(film)
'
