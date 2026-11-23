# 3. One page

Everything in this course, on one screen. Run from `scraping/`, with the
course's helpers on your path:

```bash
export PATH="$PWD/bin:$PATH"
```

---

## Open, close

```bash
h5i browser open URL --session s --new                      # a proxy and a Chromium
h5i browser open URL --session s --new --allow https://cdn.example
h5i browser navigate URL --session s                        # go somewhere else
h5i browser status --session s                              # what it is, how it is placed
h5i browser close --session s                               # the record stays
h5i browser close --all
h5i browser list                                            # what is still running
```

## Read

```bash
h5i browser snapshot    --session s          # outline + @ref handles
h5i browser snapshot -i --session s          # only what you can act on
h5i browser eval 'document.title' --session s
h5i browser screenshot  --session s          # when a read surprises you
extract '{…}' --session s                    # named fields, by selector  (bin/extract)
extract '{…}' --url URL --session s          # navigate, then read
served --session s                           # the body as the server sent it  (bin/served)
served URL --session s --json                # {url, status, type, bytes, text}
```

## The extract schema

| Form | Answers |
| --- | --- |
| `"k": "SEL"` | first match's text, or `null` |
| `"k": ["SEL"]` | every match's text, as a list |
| `"k": {"selector": "SEL", "attr": "A"}` | first match's attribute, or `null` |
| `"k": [{"selector": "SEL", "attr": "A"}]` | every match's attribute, as a list |
| `"k": [{"selector": "SEL", "fields": {…}}]` | one object per match, sub-selectors read inside it |

```json
{
  "title":  "div.product_main h1",
  "prices": ["article.product_pod p.price_color"],
  "next":   {"selector": "li.next a", "attr": "href"},
  "links":  [{"selector": "h3 a", "attr": "href"}],
  "rows":   [{"selector": "article.product_pod", "fields": {
               "title": "h3 a", "price": "p.price_color"}}],
  "js":     ["script"]
}
```

* text is `textContent`, trimmed at the ends, not internally
* `href`, `src`, `action`, `poster` come back absolute
* `attr` also takes `outerHTML`, `innerHTML`, `text`
* no key matched anything → refused; one key matched nothing → an empty column
* **no row grouping without `fields`.** Ask for rows, or anchor every selector
  at the row container

## Turning columns into rows

```bash
extract '{…flat…}' --session s | python3 lib/rows.py col1 col2 col3
```

Refuses unequal columns. Writes CSV with a header. A `fields` schema needs
none of this: it is already rows.

## Where the data hides

| Where | How to look |
| --- | --- |
| JSON-LD | `{"d": ["script[type=\"application/ld+json\"]"]}` |
| OpenGraph, microdata | `{"og": [{"selector": "meta[property^=\"og:\"]", "attr": "content"}], "ip": [{"selector": "[itemprop]", "attr": "itemprop"}]}` |
| a `data-*` attribute | `{"d": {"selector": "[data-items]", "attr": "data-items"}}` |
| Next.js (pages) | `{"d": "#__NEXT_DATA__"}` |
| Next.js (app) | `{"js": ["script"]}`, look for `self.__next_f` |
| Nuxt / Redux SSR | `h5i browser eval 'window.__NUXT__'`, `window.__INITIAL_STATE__` |
| an inline literal | `served`, and read the `<script>` |
| an endpoint | note `seq`, act once, `h5i browser requests --since SEQ` |

## Driving

```bash
h5i browser snapshot -i --session s                # -> [ref=e9]
h5i browser type  @e9 "text" --session s
h5i browser press Enter --session s
h5i browser click @e3 --session s
h5i browser click '[id="2015"]' --session s        # or any CSS selector
h5i browser select @e5 express --session s         # by the option's value
h5i browser set-checked @e4 true --session s
h5i browser scroll 4000 --session s
h5i browser wait-for --selector 'tr.film' --session s
h5i browser wait-for --text 'Results' --session s
```

* take a `@ref` from the snapshot you just took; keep a CSS selector for
  anything you will run again
* `set-checked` sets; a click toggles
* `✓ Done` means dispatched, not effective. The log says what it fetched
* `wait-for` gives up after 30 s and says nothing else
* an id that starts with a digit is `[id="2015"]`, not `#2015`

## What did I actually fetch

```bash
h5i browser requests --session s
h5i browser requests --session s --since 42
h5i browser requests --session s --denied-only
h5i browser requests --session s --url-contains ajax=true
h5i browser requests --session s --json        # seq, phase, method, url, allowed, status, bytes
h5i browser audit    --session s
```

* written by the proxy before the bytes move: not in the log ⇒ not sent
  through this session
* the log includes Chromium's own traffic (`*.google.com`, `*.googleapis.com`,
  `*.gvt1.com`): count by URL and origin, not by row
* `DENIED … not in the allowlist` ⇒ `--allow ORIGIN` on a new `open`
* the page cannot see a refusal. The log is where it is written down

## Sending it again

```bash
h5i browser resend 25 --session s                           # the same request
h5i browser resend 25 --set query.year=2014 --session s --json
h5i browser resend 25 --set form.q=Boston --session s
```

* the same headers and cookies, one part changed, through the same policy
* `--json` answers `response.status`, `response.headers`, `response.body_preview`
* the body is a preview of at most 4 KiB. Check `response.body_truncated`

## Pagination

```bash
next=$(extract '{"n": {"selector": "li.next a", "attr": "href"}}' --session s \
       | python3 -c 'import json,sys; print(json.load(sys.stdin)["n"] or "")')
[ -n "$next" ] || break
```

Stop on the site's signal. Verify against the site's total. Never stop on "this
page had fewer rows."

## This course

```bash
./run.sh                 # list the labs
./run.sh 01              # run lab 01, write out/01-books-to-scrape.csv
./run.sh 01 -            # run it, print the CSV
PAGES=10 ./run.sh 02     # take more of the site
PACE=3 ./run.sh 09       # be slower
./test-all.sh            # all ten, ~30 page requests
cat labs/01-*/README.md  # the brief
cat labs/01-*/NOTES.md   # the writeup
```

Next: [`04-etiquette-and-scope.md`](04-etiquette-and-scope.md).
