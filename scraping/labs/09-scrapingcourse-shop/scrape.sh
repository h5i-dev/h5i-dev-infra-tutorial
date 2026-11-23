#!/usr/bin/env bash
# Lab 09 — ScrapingCourse shop: pagination with a stop condition you can trust.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

SITE="https://www.scrapingcourse.com/ecommerce/"
PAGES="${PAGES:-2}"

session shop09 "$SITE"

# The page states its own size: "Showing 1–16 of 188 results". Read it, and you
# have a total to check the crawl against — the difference between "the loop
# ended" and "the loop collected everything" is the whole reliability of a
# scraper, and a count you did not verify is a guess.
total="$(extract '{"count": "p.woocommerce-result-count"}' | python3 -c 'import json,re,sys
text = json.load(sys.stdin)["count"] or ""
m = re.search(r"of\s+([\d,]+)", text)
print(m.group(1).replace(",", "") if m else "?")')"
echo "# the page says there are $total products in all" >&2

SCHEMA='{
  "name":  ["li.product .product-name"],
  "price": ["li.product .product-price"],
  "url":   [{"selector": "li.product a.woocommerce-LoopProduct-link", "attr": "href"}],
  "image": [{"selector": "li.product img.product-image", "attr": "src"}],
  "next":  {"selector": "a.next.page-numbers", "attr": "href"}
}'

url="$SITE"
got=0
for n in $(seq 1 "$PAGES"); do
    answer="$(extract "$SCHEMA" --url "$url")" || exit 1
    table="$(printf '%s' "$answer" | rows name price url image)" || exit 1
    if [ "$n" = 1 ]; then
        printf '%s\n' "$table"
    else
        printf '%s\n' "$table" | tail -n +2
    fi
    got=$((got + $(printf '%s\n' "$table" | tail -n +2 | wc -l)))

    # `a.next.page-numbers` is absent on the last page, and absence is the stop
    # condition. Do not stop on "this page returned fewer rows than the last":
    # a page that is short because a request failed looks exactly the same.
    url="$(printf '%s' "$answer" | python3 -c 'import json,sys; print(json.load(sys.stdin)["next"] or "")')"
    [ -n "$url" ] || { echo "# no next link: this was the last page" >&2; break; }
    pace
done

echo "# collected $got of $total (PAGES=$PAGES of the crawl)" >&2
