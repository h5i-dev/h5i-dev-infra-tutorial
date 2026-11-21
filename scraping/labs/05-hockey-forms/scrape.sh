#!/usr/bin/env bash
# Lab 05 — Scrape This Site, Hockey Teams: drive the form once, then stop
# using it.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

SITE="https://www.scrapethissite.com/pages/forms/"
QUERY="${QUERY:-New York}"
PAGES="${PAGES:-2}"

session hockey05 "$SITE"

# Step one: ask the page what the form does, before touching it. The DOM
# knows the method, the action and the field names.
echo "# the form: $(js '[...document.forms].map(f => ({method: f.method, action: f.action,
    fields: [...f.elements].filter(e => e.name).map(e => e.name)}))')" >&2

# Step two: use it once, the way a person would, to confirm. A @ref comes from
# a snapshot and belongs to that snapshot, so take it from the reading you are
# about to act on, and by what the element *is* (`textbox`), not by position.
ref="$("$H5I" browser snapshot --interactive --session hockey05 2>/dev/null \
    | sed -n 's/.*- textbox .*\[ref=\([a-z0-9]*\)\].*/\1/p' | head -1)"
[ -n "$ref" ] || { echo "no search box on $SITE — the page changed" >&2; exit 1; }

# A selector is the durable name: `type 'input[name=q]'` works tomorrow, and
# a @ref does not survive the next snapshot.
"$H5I" browser type "@$ref" "$QUERY" --session hockey05 --json >/dev/null
"$H5I" browser press Enter --session hockey05 --json >/dev/null
"$H5I" browser wait-for-script 'location.search.includes("q=")' --session hockey05 --json >/dev/null
target="$(js 'location.href' | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
echo "# the form is a GET: $target" >&2

# Step three: stop typing. The form put the search into the query string, so
# every later page is a URL you can build. `page_num` is the site's own
# pagination parameter, visible in the pager links.
SCHEMA='{
  "team":   ["tr.team td.name"],
  "year":   ["tr.team td.year"],
  "wins":   ["tr.team td.wins"],
  "losses": ["tr.team td.losses"],
  "pct":    ["tr.team td.pct"]
}'

for n in $(seq 1 "$PAGES"); do
    url="$target&page_num=$n"
    answer="$(extract "$SCHEMA" --url "$url" --session hockey05 2>/dev/null)" || break
    if [ "$n" = 1 ]; then
        printf '%s' "$answer" | rows team year wins losses pct
    else
        printf '%s' "$answer" | rows team year wins losses pct | tail -n +2
    fi
    pace
done
