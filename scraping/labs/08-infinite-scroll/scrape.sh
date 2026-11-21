#!/usr/bin/env bash
# Lab 08 — Web Scraper test site, infinite scroll: what the scroll was hiding.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

PAGE="https://webscraper.io/test-sites/e-commerce/scroll/computers/laptops"
SCROLLS="${SCROLLS:-3}"      # the naive loop's cap. About 39 would reach the end.

session scroll08 "$PAGE"

count() { js 'document.querySelectorAll("div.thumbnail a.title").length'; }
cursor() { "$H5I" browser requests --session scroll08 --json \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["cursor"])'; }

# The naive loop: scroll, count, scroll again, stop when the count stops
# growing. Chromium fires the page's handler, and three more products render
# per scroll. The loop works, and it is still the wrong tool.
seen="$(count)"
before="$(cursor)"
echo "# rendered before scrolling: $seen" >&2
for _ in $(seq 1 "$SCROLLS"); do
    "$H5I" browser scroll 4000 --session scroll08 --json >/dev/null
    sleep 0.5
    now="$(count)"
    echo "# after a scroll: $now" >&2
    [ "$now" -gt "$seen" ] || break
    seen="$now"
done

# Ask the request log what those scrolls fetched. Nothing new is the answer:
# the page is drawing rows it already had.
fetched="$("$H5I" browser requests --session scroll08 --since "$before" --json \
    | python3 -c 'import json,sys
print(len([r for r in json.load(sys.stdin)["requests"] if r["phase"] == "request" and r["allowed"]]))')"
echo "# requests the scrolls made: $fetched" >&2

# So look at what the server sent. The response carries the entire dataset in
# a `data-items` attribute on the product wrapper: one request, every row.
response "$PAGE" | python3 -c '
import csv, html, json, re, sys
page = sys.stdin.read()
attr = lambda name: re.search(r"%s=([\"\x27])(.*?)\1" % name, page, re.S)
items = json.loads(html.unescape(attr("data-items").group(2)))
kind = attr("data-type")
print("# data-type=%s, and %d items were in the response all along"
      % (kind.group(2) if kind else "?", len(items)), file=sys.stderr)
out = csv.DictWriter(sys.stdout, ["id", "title", "price", "description"],
                     extrasaction="ignore", lineterminator="\n")
out.writeheader()
for item in items:
    out.writerow(item)
'
