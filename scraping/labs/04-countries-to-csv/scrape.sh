#!/usr/bin/env bash
# Lab 04 — Scrape This Site, Countries: 250 rows, one page, one request.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

PAGE="https://www.scrapethissite.com/pages/simple/"

session countries04 "$PAGE"

# There is no pagination here, and nothing on the page depends on a script.
# The whole dataset is in the markup of one page, and the right number of page
# requests is one. A flat schema, anchored at `div.country`, and rows.py to
# refuse it if the columns ever stop lining up.
extract '{
  "country":    ["div.country h3.country-name"],
  "capital":    ["div.country span.country-capital"],
  "population": ["div.country span.country-population"],
  "area_km2":   ["div.country span.country-area"]
}' | rows country capital population area_km2

# Then check what was fetched. Every row of the log is a request the session's
# Chromium sent through h5i's proxy: the page, its stylesheets and images, the
# third parties it tried to reach, and Chromium's own background traffic to
# Google. Sort them by what they are, not by how many there are.
"$H5I" browser requests --session "$SESSION" --json | python3 -c '
import json, sys
from urllib.parse import urlsplit
page = sys.argv[1]
rows = json.load(sys.stdin)["requests"]
sent = [r for r in rows if r["phase"] == "request"]
own = urlsplit(page).netloc
documents = [r for r in sent if r["allowed"] and r["url"] == page]
same_origin = [r for r in sent if r["allowed"] and urlsplit(r["url"]).netloc == own]
denied = {urlsplit(r["url"]).netloc for r in sent if not r["allowed"]}
print("# requests for the page itself: %d" % len(documents), file=sys.stderr)
print("# everything else from %s (css, images): %d" % (own, len(same_origin) - len(documents)), file=sys.stderr)
print("# origins refused: %d (%s)" % (len(denied), ", ".join(sorted(denied))), file=sys.stderr)
' "$PAGE"
