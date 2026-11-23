#!/usr/bin/env bash
# Lab 01 — Books to Scrape: a list page, the page after it, and one detail page.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

SITE="https://books.toscrape.com"
PAGES="${PAGES:-2}"          # how many list pages to walk. Two is the demo.

session books01 "$SITE/"

# The list page, asked for as rows. `article.product_pod` is the element that
# *is* one book, and every sub-selector is read inside it, so a card that lacks
# a field contributes an empty cell rather than shifting every row after it.
LIST='{"books": [{"selector": "article.product_pod", "fields": {
  "title": {"selector": "h3 a", "attr": "title"},
  "price": "p.price_color",
  "stock": "p.instock.availability",
  "url":   {"selector": "h3 a", "attr": "href"}
}}], "next": {"selector": "li.next a", "attr": "href"}}'

url="$SITE/"
header=1
for n in $(seq 1 "$PAGES"); do
    # `--url` navigates first, so one call is one page.
    answer="$(extract "$LIST" --url "$url")" || exit 1
    printf '%s' "$answer" | python3 -c '
import csv, json, sys
page = json.load(sys.stdin)
out = csv.DictWriter(sys.stdout, ["title", "price", "stock", "url"], lineterminator="\n")
if sys.argv[1] == "1":
    out.writeheader()
out.writerows(page["books"])
' "$header"
    header=0

    # The stop condition is the *absence* of `li.next a`, which the site
    # asserts on its last page. It comes back absolute, so there is no URL
    # arithmetic anywhere in this loop.
    url="$(printf '%s' "$answer" | python3 -c 'import json,sys; print(json.load(sys.stdin)["next"] or "")')"
    [ -n "$url" ] || break
    pace
done

# One detail page, to show what the list page does not carry. The list gives a
# truncated title and a rating in a class name; the detail page gives the UPC,
# the exact stock count, and the category.
pace
extract '{
  "title":    "div.product_main h1",
  "price":    "div.product_main p.price_color",
  "upc":      "table.table-striped tr:nth-child(1) td",
  "stock":    "table.table-striped tr:nth-child(6) td",
  "category": "ul.breadcrumb li:nth-child(3) a"
}' --url "$SITE/catalogue/a-light-in-the-attic_1000/index.html" >&2
