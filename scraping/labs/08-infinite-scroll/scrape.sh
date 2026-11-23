#!/usr/bin/env bash
# Lab 08 — Web Scraper test site, infinite scroll: what the scroll was hiding.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

PAGE="https://webscraper.io/test-sites/e-commerce/scroll/computers/laptops"
SCROLLS="${SCROLLS:-3}"

session scroll08 "$PAGE"

# The naive loop: scroll, count, scroll again, stop when the count stops
# growing. In a real Chromium the page's own scroll handler runs, and the count
# grows three products at a time. About 39 scrolls would reach the 117 the page
# has. The loop is capped at $SCROLLS, because the point is made by then.
#
# Watch the request log while it runs. Every scroll adds rows to the page and
# fetches nothing for them, because there is nothing left to fetch.
count() {
    extract '{"n": ["div.thumbnail a.title"]}' 2>/dev/null \
        | python3 -c 'import json,sys
try: print(len(json.load(sys.stdin)["n"]))
except Exception: print(0)'
}
last_seq() {
    "$H5I" browser requests --session "$SESSION" --json \
        | python3 -c 'import json,sys; print(max([r["seq"] for r in json.load(sys.stdin)["requests"]] or [0]))'
}
same_origin_since() {
    "$H5I" browser requests --session "$SESSION" --since "$1" --json | python3 -c '
import json, sys
rows = json.load(sys.stdin)["requests"]
print(len([r for r in rows if r["phase"] == "request" and r["allowed"]
           and r["url"].startswith("https://webscraper.io/") and "/images/" not in r["url"]]))'
}

seen="$(count)"
echo "# rendered before scrolling: $seen" >&2
for _ in $(seq 1 "$SCROLLS"); do
    before="$(last_seq)"
    "$H5I" browser scroll 4000 --session "$SESSION" >/dev/null 2>&1
    now="$(count)"
    echo "# after a scroll: $now  (data requests it caused: $(same_origin_since "$before"))" >&2
    [ "$now" -gt "$seen" ] || break
    seen="$now"
done

# So look at what the page actually shipped. This one carries the entire
# dataset in a `data-items` attribute on the product wrapper: the scroll is a
# rendering decision, and the payload arrived in the first response.
extract '{
  "items": {"selector": "[data-items]", "attr": "data-items"},
  "type":  {"selector": "[data-type]",  "attr": "data-type"}
}' | python3 -c '
import csv, json, sys
page = json.load(sys.stdin)
items = json.loads(page["items"])
print("# data-type=%s, and %d items were in the markup all along"
      % (page["type"], len(items)), file=sys.stderr)
out = csv.DictWriter(sys.stdout, ["id", "title", "price", "description"],
                     extrasaction="ignore", lineterminator="\n")
out.writeheader()
for item in items:
    out.writerow(item)
'
