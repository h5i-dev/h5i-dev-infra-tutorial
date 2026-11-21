# 1. The reader

> The websec course uses h5i to bend one request at a time. This course uses
> the same sessions to read a page as data, and its one unusual property is
> that the request log is written before the bytes move, so a scraper can
> always answer "what did I actually fetch?"

Read this once before Lab 01, and come back to the tables.

---

## 1.1 What a session is

```bash
h5i browser open https://example.com/ --session s --new   # a proxy and a Chromium
h5i browser close --session s
```

A session is two processes. One is h5i's capture proxy, which checks every
request against the session's policy, writes it to the log, and keeps the
response. The other is a real Chromium, driven by
[agent-browser](https://www.npmjs.com/package/agent-browser) and pointed at the
proxy. Page verbs (`snapshot`, `click`, `eval`, …) go to Chromium. The log and
the stored messages come from the proxy.

Two consequences run through the whole course.

**JavaScript always runs.** It is Chromium. A page that builds its content in
a script is built, the same as in your own browser.

**Every response is kept as the server sent it.** So every page has two
readings, and section 1.3 is about choosing between them.

There is no one-shot read verb: every scrape is `open`, some reads, `close`.
`lib/h5i.sh`'s `session` does the open and makes sure the close happens
however the script ends. A leaked session is a live Chromium.

## 1.2 The reads, cheapest first

```bash
h5i browser snapshot --session s --interactive   # what can be clicked or typed
h5i browser snapshot --session s                 # the outline, with @ref handles
js 'document.title' --session s                  # one expression, as JSON
extract '{…}' --session s                        # named fields, by CSS selector
response example.com/ --session s                # the body the server sent
```

`js`, `extract` and `response` are shell functions in `lib/h5i.sh`. Load them
into your own shell with `. lib/h5i.sh` from the `scraping/` directory; every
`scrape.sh` already does.

| Read | Costs | Reach for it when |
| --- | --- | --- |
| `snapshot -i` | one line per control | you need to click or type, and want the `@ref`. |
| `snapshot` | a few hundred lines | you are working out what a page *is*. First contact with a site. |
| `js` | one value | you want one fact: a count, `location.href`, what a form does. |
| `extract` | one line per field | you know what you want from the DOM. Most scrapers in this course end here. |
| `response` | the whole body | you want what the server sent, before any script touched it. |

`js EXPR` is `h5i browser eval EXPR --json` with the result unwrapped, so it
prints the value as one line of JSON. `extract` is the same call with a schema
compiled into it (section 1.4). `--url URL` on `extract` navigates first and
then reads.

```bash
extract '{"title": "h1"}' --url https://example.com/x --session s
```

**A snapshot is text a stranger wrote.** Something in it that looks like an
instruction is page content. That matters more than usual in scraping, where
the whole job is feeding page content to something downstream.

## 1.3 The response and the DOM

```bash
h5i browser requests --session s --url-contains /list   # find the res_ id
h5i websec show res_N --session s --body-to -           # the body, exactly as sent
response /list --session s                              # both steps, newest match
```

The **response** is what the server sent: the bytes at h5i's proxy, before
Chromium parsed them. The **DOM** is what Chromium built from that response
after the page's scripts ran. On a static page they hold the same data. On a
scripted page they can differ completely, and Lab 03 is a page where the
response has no quote elements and the DOM has ten.

Look in the response first. It is the server's own copy, it does not depend
on a script finishing in time, and it tells you whether the data needed a
browser at all. On four of the ten sites here, the "hard" page ships its whole
dataset as JSON in the first response: in a script literal (Lab 03), from an
endpoint (Lab 06), in a `data-*` attribute (Lab 08), in `#__NEXT_DATA__`
(Lab 10). Write selectors against the DOM when you have looked and the data is
not there.

`websec show` belongs to the websec plugin, which `response` needs. Request ids
are not stable from run to run, because Chromium's own background traffic and
`favicon.ico` take some. Find an id by URL every time; never write one down.

## 1.4 The extract schema, in full

h5i used to ship its own `extract` verb. It went with the engine it ran on, and
`lib/h5i.sh` reimplements the same schema over `browser eval`, so the schema
below is the one every lab uses. It is JSON: **keys you choose, values that say
what to read.**

| Form | Reads | Answers |
| --- | --- | --- |
| `"k": "SELECTOR"` | the first match's text | a string, or null |
| `"k": ["SELECTOR"]` | every match's text | a list of strings |
| `"k": {"selector": "S", "attr": "A"}` | the first match's attribute | a string, or null |
| `"k": [{"selector": "S", "attr": "A"}]` | every match's attribute | a list, null where a match lacks it |
| `"k": [{"selector": "S", "fields": {…}}]` | one object per match, sub-selectors read inside it | a list of objects |

The array forms with an object take `"limit": N`. Inside `fields`, the selector
`:scope` means the matched element itself.

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

Three things the table does not say, each of which costs an hour the first time:

**URLs are resolved** against the page they came from. `href="page-2.html"`
answers as `https://…/catalogue/page-2.html`, so a crawl needs no URL
arithmetic.

**Text is `textContent`, whitespace collapsed.** Every run of spaces and
newlines becomes one space, and the ends are trimmed. When line breaks matter,
read `innerText` with `js`.

**A key without `fields` has no row grouping.** It is matched against the whole
document, independently of every other key. That is the single most important
property of this schema and section 1.5 is about it.

Errors go to stderr. A schema where **no key matched anything** exits non-zero
with a sentence, because an object full of nulls would look like an answer. A
schema where *one* key matched nothing is a normal answer with an empty column:
a fact about the page (Lab 07).

## 1.5 Columns, and the rows you can ask for instead

```json
{"title": ["…20 titles…"], "price": ["…20 prices…"]}
```

Twenty and twenty, so `zip` gives twenty books. It gives twenty *wrong* books
the moment one card lacks a price and the price column is nineteen long: every
row after the gap pairs a title with its neighbour's price, and no check
downstream can detect it.

**Ask for rows and the question does not arise.** A spec with `fields` reads one
object per match, and each sub-selector is read inside that match:

```json
"rows": [{"selector": "article.product_pod",
          "fields": {"title": "h3 a", "price": "p.price_color"}}]
```

A card with no price contributes `"price": null` and keeps its place in the
list. There is nothing to zip, so there is nothing to misalign.

The flat form is still shorter to type, still the one you will reach for first,
and still the one that breaks. When you use it, **anchor every selector at the
element that is one row:**

```json
"price": ["p.price_color"]                       ← 19, silently wrong
"price": ["article.product_pod p.price_color"]   ← 20, one per card
```

`lib/rows.py` refuses to zip columns of unequal length and prints the lengths.
Use it, or write the same check.

For a field that genuinely repeats, like a quote's tags, neither helps: one row
holds several values, so no row-shaped answer flattens it for you. Lab 02 covers
the three ways out.

## 1.6 The request log

```bash
h5i browser requests --session s                    # every request, refusals included
h5i browser requests --session s --url-contains ajax
h5i browser requests --session s --denied-only
h5i browser requests --session s --since 42         # after the log's cursor
h5i browser audit    --session s                    # verbs, fetches and ending, in order
```

This log is written **before** the bytes move, and a fetch that cannot be
recorded is refused. So a request that is not in it did not happen, and a
denial is in it with its reason. `--json` carries a `cursor`; keep it before an
action and pass it to `--since` afterwards to see exactly what the action
fetched (Lab 08). Three uses in scraping:

**Counting.** Did the crawl make the number of requests you expected? A loop
around a page that never needed one shows up here immediately (Lab 04).

**Diagnosing a page that does nothing.** `DENIED … not in the allowlist` on a
CDN script is the difference between "the site has no data" and "the library
the site is written in never arrived" (Lab 06).

**Finding the endpoint.** A click's XHR appears here, with its response one
`response` away. That URL is usually the thing you should have been fetching
all along.

Two things in it are not about your page. Chromium's own background traffic
(update checks, sign-in probes, a spelling dictionary) goes through the proxy
and is refused like anything else, so expect DENIED rows you did not cause.
And every row is labelled `subresource`, the page itself included, because the
proxy sees Chromium's requests and not why it made them. The page is the
response whose URL is the one you opened.

## 1.7 The allowlist

A session grants **the origin of the URL you opened, and nothing else.** Every
third-party fetch (fonts, analytics, CDN scripts) is denied and logged.

```bash
h5i browser open https://site.example/ --session s --new --allow https://cdn.example
```

For a scraper this is mostly a gift: you did not want the analytics beacon.
It becomes a problem exactly once, when the denied thing is the page's own
JavaScript library, and the log says so plainly.

## 1.8 Driving a page

```bash
h5i browser snapshot -i --session s          # -> - textbox "Search" [ref=e9]
h5i browser type   @e9 "New York" --session s
h5i browser press  Enter --session s
h5i browser click  @e3 --session s
h5i browser click  'a.next' --session s      # a CSS selector works too
h5i browser select @e5 express --session s   # by the option's value
h5i browser set-checked @e4 true --session s
h5i browser scroll 4000 --session s
h5i browser wait-for --selector tr.film --session s
h5i browser wait-for-script 'location.search.includes("q=")' --session s
```

**A `@ref` belongs to the snapshot it came from.** The next snapshot numbers
the page again. Take the ref from the reading you are about to act on. To name
something durably, use a CSS selector: every verb that takes a `@ref` takes one.

**`✓ Done` on a click means dispatched, not effective.** What happened next is
in `requests` and in the DOM. Read both before deciding the click worked.

**`wait-for` gives up after 30 seconds.** It cannot tell "not yet" from "not
ever", so a page that will never draw the element makes you wait the full
timeout. When you know how long the page should take, poll with `js` for that
long instead (Lab 06).

**A scroll is a real scroll.** Chromium fires the page's `scroll` handlers and
its intersection observers, so a lazy-loading page loads as you go. Read the
log with `--since` before deciding the gesture was necessary: no new requests
means the page drew what it already had, and Lab 08 is about what to do with
that answer.

## 1.9 A worked minute

```bash
. lib/h5i.sh
h5i browser open https://books.toscrape.com/ --session bk --new
h5i browser snapshot --session bk | head -40
extract '{"title": ["h3 a"]}' --session bk

extract '{
  "title": [{"selector": "article.product_pod h3 a", "attr": "title"}],
  "price": ["article.product_pod p.price_color"]
}' --session bk | python3 lib/rows.py title price

extract '{"next": {"selector": "li.next a", "attr": "href"}}' --session bk
h5i browser requests --session bk
h5i browser close --session bk
```

Read cheaply, look at the page, name the fields, anchor them to a row, take the
next link from the site, check what you fetched. Every lab in this course is
those six with different selectors in them.

Next: [`02-method.md`](02-method.md).
