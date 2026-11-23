#!/usr/bin/env bash
# Lab 03 — Quotes to Scrape (JavaScript): the same data, written by a script.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

PAGE="https://quotes.toscrape.com/js/"

session quotes03 "$PAGE"

# Two readings of the same URL, and the gap between them is the lab.
#
# What the server sent: `served` fetches the page again and prints the body
# before any script ran. It holds no `<div class="quote">` at all; the quotes
# are in an inline `<script>`, as a `var data = [...]` literal.
#
# What the browser built: `extract` reads the live DOM in the session's
# Chromium, after that script has run and written ten quotes into it.
pace
served | python3 -c '
import re, sys
html = sys.stdin.read()
print("# served:   %d quote elements, data literal present: %s"
      % (len(re.findall(r"class=\"quote\"", html)), "var data = [" in html), file=sys.stderr)
'
extract '{"n": ["div.quote"]}' | python3 -c '
import json, sys
print("# rendered: %d quote elements" % len(json.load(sys.stdin)["n"]), file=sys.stderr)'

# The CSV comes from the rendered page, because that is the route the page was
# built for. The served literal is the other route, and NOTES.md says when you
# would take it instead.
extract '{"quotes": [{"selector": "div.quote", "fields": {
  "quote": "span.text", "author": "small.author"}}]}' | python3 -c '
import csv, json, sys
out = csv.DictWriter(sys.stdout, ["quote", "author"], lineterminator="\n")
out.writeheader()
out.writerows(json.load(sys.stdin)["quotes"])
'
