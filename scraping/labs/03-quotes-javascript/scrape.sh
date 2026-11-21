#!/usr/bin/env bash
# Lab 03 — Quotes to Scrape (JavaScript): what the server sent vs what a script built.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

PAGE="https://quotes.toscrape.com/js/"
SCHEMA='{"quote": ["div.quote span.text"], "author": ["div.quote small.author"]}'

session quotes03 "$PAGE"

# Two readings of one page. The captured response is what the server sent; the
# DOM is what Chromium built from it after the page's scripts ran.
html="$(response "$PAGE")" || exit 1
echo "# in the response: $(printf '%s' "$html" | grep -c 'class="quote"') quote elements," \
     "and a 'var data = [' literal: $(printf '%s' "$html" | grep -c 'var data = \[')" >&2
echo "# in the DOM:      $(extract "$SCHEMA" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["quote"]))') quote elements" >&2

# The rows the render shows. Selectors against the DOM work, because Chromium
# ran the script. NOTES.md is about why the literal is the better source.
extract "$SCHEMA" | rows quote author

# The same ten quotes, straight from the response: no render involved.
printf '%s' "$html" | python3 -c '
import json, re, sys
m = re.search(r"var data = (\[.*?\]);", sys.stdin.read(), re.S)
data = json.loads(m.group(1)) if m else []
print("# parsed from the literal: %d quotes, tags and author slug included" % len(data), file=sys.stderr)
' 
