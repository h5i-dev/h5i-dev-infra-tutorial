#!/usr/bin/env bash
# Lab 04 — Scrape This Site, Countries: 250 rows, one page, one request.
set -uo pipefail
. "$(dirname "$0")/../../lib/h5i.sh"

PAGE="https://www.scrapethissite.com/pages/simple/"

session countries04 "$PAGE"

# There is no pagination, and no script builds the rows. The whole dataset is
# in the markup of one page, and the right number of requests is one. Check that
# number afterwards with `h5i browser requests`: a scraper that fetched more
# pages than the data has is a scraper with a bug.
extract '{
  "country":    ["div.country h3.country-name"],
  "capital":    ["div.country span.country-capital"],
  "population": ["div.country span.country-population"],
  "area_km2":   ["div.country span.country-area"]
}' --session countries04 | rows country capital population area_km2

# Count what was fetched, and attribute what was refused. Chromium labels
# every request `subresource`, the page itself included, so the page is the
# response for its own URL. A refused origin the response mentions is the
# page's; the rest is Chromium's own background traffic.
"$H5I" browser requests --session countries04 --json | python3 -c '
import json, sys
from urllib.parse import urlsplit
page, html = sys.argv[1], open(sys.argv[2]).read()
rows = json.load(sys.stdin)["requests"]
origin = lambda u: "%s://%s" % urlsplit(u)[:2]
got = [r for r in rows if r["phase"] == "response" and r.get("status")]
pages = [r for r in got if r["url"] == page]
denied = set(origin(r["url"]) for r in rows if r["phase"] == "request" and not r["allowed"])
print("# pages fetched: %d (and %d same-origin subresources)" % (len(pages), len(got) - len(pages)), file=sys.stderr)
named = set(o for o in denied if urlsplit(o).netloc in html)
print("# origins refused: %d the page names, %d Chromium background"
      % (len(named), len(denied - named)), file=sys.stderr)
' "$PAGE" <(response "$PAGE")
