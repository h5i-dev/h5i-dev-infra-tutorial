# 3. One page

Everything in this course, on one screen.

---

## Open, read, close

```bash
. lib/h5i.sh                                    # extract, js, response, rows

h5i browser open URL --session s --new          # a proxy and a Chromium
h5i browser open URL --session s --new --allow https://cdn.example
h5i browser navigate URL --session s
h5i browser close --session s
h5i browser list                                # what is still running
```

JavaScript always runs: the session is a real Chromium.

## Reads, cheapest first

```bash
h5i browser snapshot -i --session s             # controls + @ref handles
h5i browser snapshot    --session s             # the whole outline
h5i browser snapshot    --session s --delta     # only what changed since the last one
js 'document.title'     --session s             # one value, as JSON
extract '{…}'           --session s             # named fields from the DOM
extract '{…}' --url URL --session s             # navigate, then read
response URL_PART       --session s             # the body the server sent
h5i browser screenshot  --session s             # when a read surprises you
```

## The response and the DOM

```bash
h5i browser requests --session s --url-contains /list   # -> res_N (never hard-code it)
h5i websec show res_N --session s --body-to -           # the body, exactly as sent
response /list --session s                              # the same, in one step
```

* the response is what the server sent; the DOM is what scripts built from it
* look in the response first; write selectors against the DOM when it is not there
* `response` and `websec show` need the websec plugin

## The extract schema

| Form | Answers |
| --- | --- |
| `"k": "SEL"` | first match's text, as a string |
| `"k": ["SEL"]` | every match's text, as a list |
| `"k": {"selector": "SEL", "attr": "A"}` | first match's attribute, as a string |
| `"k": [{"selector": "SEL", "attr": "A"}]` | every match's attribute, as a list |
| `"k": [{"selector": "SEL", "fields": {…}}]` | one object per match, sub-selectors read inside it |

```json
{
  "title":  "div.product_main h1",
  "prices": ["article.product_pod p.price_color"],
  "next":   {"selector": "li.next a", "attr": "href"},
  "links":  [{"selector": "h3 a", "attr": "href"}],
  "rows":   [{"selector": "article.product_pod", "fields": {
               "title": "h3 a", "price": "p.price_color"}}]
}
```

* `extract` is `lib/h5i.sh`'s, run through `h5i browser eval`
* text is `textContent` with whitespace collapsed and the ends trimmed
* `href` and `src` come back absolute
* `"limit": N` on the array forms; `:scope` inside `fields` is the match itself
* attributes worth knowing: `href`, `src`, `title`, `content`, `value`, `class`,
  `data-*`. For `outerHTML` or `innerText`, use `js`
* no key matched anything → an error; one key matched nothing → an empty column
* **no row grouping without `fields`.** Use it, or anchor every selector at the
  row container.

## Turning columns into rows

```bash
extract '{…}' --session s | python3 lib/rows.py col1 col2 col3
```

Refuses unequal columns. Writes CSV with a header. A `fields` schema needs none of this: it is already rows.

```bash
# the check, by hand
… | python3 -c 'import json,sys; print({k: len(v) for k,v in json.load(sys.stdin).items()})'
```

## Where the data hides

| Where | How to look |
| --- | --- |
| page metadata | `response URL \| grep -E 'og:\|itemprop\|<meta'` |
| a `data-*` attribute | `response URL \| grep -o 'data-[a-z-]*='` |
| Next.js (pages) | `response URL`, look for `id="__NEXT_DATA__"` |
| Next.js (app) | `response URL`, look for `self.__next_f` |
| Nuxt / Redux SSR | `response URL`, look for `__NUXT__`, `__INITIAL_STATE__` |
| JSON-LD | `response URL`, look for `application/ld+json` |
| an inline literal | `response URL`, look for `var data =` and friends |
| an endpoint | click once and read `requests`; or read the URL out of the script |

## Driving

```bash
h5i browser snapshot -i --session s                # -> [ref=e9]
h5i browser type   @e9 "text" --session s
h5i browser type   'input[name=q]' "text" --session s
h5i browser press  Enter --session s
h5i browser click  @e3 --session s
h5i browser click  'a.next' --session s
h5i browser select @e5 express --session s         # by the option's value
h5i browser set-checked @e4 true --session s
h5i browser scroll 4000 --session s
h5i browser wait-for --selector 'tr.film' --session s
h5i browser wait-for --text 'Results' --session s
h5i browser wait-for-script 'location.search.includes("q=")' --session s
js '[...document.forms].map(f => [f.method, f.action])' --session s
```

* a `@ref` is valid for the snapshot it came from; take it fresh
* every verb that takes a `@ref` takes a CSS selector, and the selector is what to keep
* `set-checked` sets; a click toggles
* `✓ Done` means dispatched, not effective; `requests` and the DOM say what happened
* `wait-for` gives up after 30s and cannot say "never"; poll with `js` when you know the delay
* a scroll is real, so lazy loading works; read `requests --since` before believing you needed it

## What did I actually fetch

```bash
h5i browser requests --session s
h5i browser requests --session s --since 42
h5i browser audit    --session s
```

* written before the bytes move: not in the log ⇒ did not happen
* `DENIED … not in the allowlist` ⇒ add `--allow ORIGIN` on `open`, if the page needs it
* DENIED rows for google update and sign-in hosts are Chromium's own traffic
* every row says `subresource`; the page is the response for the URL you opened
* request ids differ every run; find them with `--url-contains`
* count the `200 GET`s against the pages you meant to fetch

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
./test-all.sh            # all ten, ~30 requests
cat labs/01-*/README.md  # the brief
cat labs/01-*/NOTES.md   # the writeup
```

Next: [`04-etiquette-and-scope.md`](04-etiquette-and-scope.md).
