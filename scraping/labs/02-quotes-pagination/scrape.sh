#!/usr/bin/env bash
# Lab 02 — Quotes to Scrape: quote, author, tags, across pages.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

SITE="https://quotes.toscrape.com"
PAGES="${PAGES:-2}"

session quotes02 "$SITE/"

# Tags are the interesting column: a quote has zero or more of them, so the
# flat read `["div.tags a.tag"]` returns thirty values for ten quotes and lines
# up with nothing. Two ways out are shown here, side by side:
#
#   tags      the page's own `<meta itemprop="keywords">`, one per quote,
#             already joined for a machine to read.
#   tag_list  a list read *inside* the row, which keeps each quote's tags with
#             their quote. `fields` is what makes that possible.
SCHEMA='{"quotes": [{"selector": "div.quote", "fields": {
  "quote":    "span.text",
  "author":   "small.author",
  "about":    {"selector": "span a", "attr": "href"},
  "tags":     {"selector": "div.tags meta[itemprop=keywords]", "attr": "content"},
  "tag_list": ["div.tags a.tag"]
}}], "next": {"selector": "li.next a", "attr": "href"}}'

url="$SITE/"
header=1
for n in $(seq 1 "$PAGES"); do
    answer="$(extract "$SCHEMA" --url "$url")" || exit 1
    printf '%s' "$answer" | python3 -c '
import csv, json, sys
page = json.load(sys.stdin)
out = csv.writer(sys.stdout, lineterminator="\n")
if sys.argv[1] == "1":
    out.writerow(["quote", "author", "about", "tags"])
for q in page["quotes"]:
    # The two routes must agree. If they ever do not, the page changed shape
    # and this is the line that says so, instead of a quietly wrong column.
    if (q["tags"] or "") != ",".join(q["tag_list"]):
        sys.exit("tags disagree for %r: %r vs %r" % (q["quote"][:40], q["tags"], q["tag_list"]))
    out.writerow([q["quote"], q["author"], q["about"], q["tags"] or ""])
' "$header" || exit 1
    header=0

    url="$(printf '%s' "$answer" | python3 -c 'import json,sys; print(json.load(sys.stdin)["next"] or "")')"
    [ -n "$url" ] || break
    pace
done
