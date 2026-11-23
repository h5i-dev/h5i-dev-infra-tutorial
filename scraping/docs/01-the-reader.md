# 1. The session

> The websec course uses h5i to bend one request at a time. This course uses
> the same session to read pages as data. Its one unusual property is that the
> request log is written by h5i's proxy before the bytes move, so a scraper can
> always answer "what did I actually fetch?"

Read this once before Lab 01, and come back to the tables.

---

## 1.1 What a session is

```bash
h5i browser open https://example.com/ --session s --new
```

That starts two things under one record. One is a **capture proxy** that h5i
runs for this session. The other is a **Chromium**, run by agent-browser and
pointed at that proxy. Chromium does everything a browser does: it renders the
page, runs its JavaScript, keeps its cookies. h5i decides what the browser may
reach, and writes down everything it asked for.

```bash
h5i browser status --session s      # what it is, where it runs, who saw its network
h5i browser list                    # every session on this machine
h5i browser close --session s       # stop the proxy and the browser; the record stays
```

`--session NAME` lets several run at once. Without it, a verb acts on
`$H5I_BROWSER_SESSION`, then on the session `open` made last. A leaked session
is a live proxy and a live Chromium, so the labs close theirs however the
script ends (`lib/h5i.sh`).

## 1.2 Reading a page

h5i gives you three ways to look at the page the session is on:

```bash
h5i browser snapshot    --session s     # the accessibility outline, with @ref handles
h5i browser snapshot -i --session s     # only what can be clicked, typed or chosen
h5i browser eval 'document.title' --session s
h5i browser screenshot  --session s     # a PNG, when a read surprises you
```

| Verb | Reach for it when |
| --- | --- |
| `snapshot` | first contact with a page, and whenever you need to click or type. It is the only one that hands out `@ref` handles. |
| `eval` | you know what you want. It runs JavaScript in the page and prints the result as JSON. |
| `screenshot` | what you read and what you expected disagree, and you want to see the page. |

`eval` is the general tool, and everything this course extracts goes through
it. Writing `querySelectorAll` into every scraper gets old fast, so the course
wraps it in a small helper.

## 1.3 `extract`: the course's schema helper

```bash
export PATH="$PWD/bin:$PATH"            # once, from the scraping/ directory
extract '{"title": "h1"}' --session s
extract '{"title": "h1"}' --url https://example.com/x --session s
```

[`bin/extract`](../bin/extract) is part of this course, not of h5i. It turns a
JSON schema into one `h5i browser eval` call and prints the answer. `--url`
navigates first, so one call is one page.

The schema has **keys you choose, and values that say what to read**:

| Form | Reads | Answers |
| --- | --- | --- |
| `"k": "SELECTOR"` | the first match's text | a string, or `null` |
| `"k": ["SELECTOR"]` | every match's text | a list |
| `"k": {"selector": "S", "attr": "A"}` | the first match's attribute | a string, or `null` |
| `"k": [{"selector": "S", "attr": "A"}]` | every match's attribute | a list |
| `"k": [{"selector": "S", "fields": {…}}]` | one object per match, sub-selectors read inside it | a list of objects |

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

Four things the table does not say:

**Text is `textContent`, trimmed at both ends.** Whitespace inside a value
survives. Text hidden by CSS is still text.

**URLs come back absolute.** `href`, `src`, `action` and `poster` are resolved
against the page, so `href="page-2.html"` answers as
`https://…/catalogue/page-2.html`, and a crawl needs no URL arithmetic.

**`attr` also takes `outerHTML`, `innerHTML` and `text`.** That is the escape
hatch when a row has to be parsed by hand.

**A schema where no key matched anything is refused**, with a sentence, because
an object full of nulls looks like an answer. A schema where *one* key matched
nothing is a normal answer with an empty column. That is a fact about the page
(Lab 07).

## 1.4 Columns, and the rows you can ask for instead

```json
{"title": ["…20 titles…"], "price": ["…20 prices…"]}
```

A flat schema matches every key against the whole document, independently.
Twenty and twenty, so `zip` gives twenty books. It gives twenty *wrong* books
the moment one card lacks a price and the price column is nineteen long. Every
row after the gap pairs a title with its neighbour's price, and no check
downstream can detect it.

**Ask for rows and the question does not arise.** A spec with `fields` reads one
object per match, and each sub-selector is read inside that match:

```json
"books": [{"selector": "article.product_pod",
           "fields": {"title": "h3 a", "price": "p.price_color"}}]
```

A card with no price contributes `"price": null` and keeps its place in the
list. There is nothing to zip, so there is nothing to misalign. Most labs ask
for rows.

The flat form is still shorter to type, and still the one that breaks. When
you use it, **anchor every selector at the element that is one row**, so a
price in a banner or a sidebar cannot join the column:

```json
"price": ["p.price_color"]                       ← every price on the page
"price": ["article.product_pod p.price_color"]   ← only the ones in a card
```

Then check the lengths. `lib/rows.py` refuses to zip columns of unequal length
and prints them.

## 1.5 Served, and rendered

Chromium runs every page's JavaScript. There is no switch to turn it off. So
`eval` and `extract` always read the page **after** its scripts ran, and the
question "was this data in the response, or did a script build it?" needs a
second read:

```bash
served --session s | head -40           # the body the server sent, before any script
served --session s --json               # {url, status, type, bytes, text}
served https://example.com/api --session s
```

[`bin/served`](../bin/served) fetches the URL again from inside the page with
`fetch()`. That is a second request, it goes through the proxy, and it is in
the log. It reads same-origin URLs only.

The difference between the two reads tells you where the data comes from. It
also decides which route a scraper should take (Lab 03):

| served | rendered | the data is |
| --- | --- | --- |
| in the markup | in the markup | plain HTML. Any route works |
| in a `<script>` literal or a `data-*` attribute | in the markup | shipped as JSON and drawn by a script. Read the JSON |
| absent | in the markup | fetched after load. Find the request (Lab 06) |

## 1.6 The request log

```bash
h5i browser requests --session s                  # every request, refusals included
h5i browser requests --session s --since 42       # only what came after seq 42
h5i browser requests --session s --denied-only
h5i browser requests --session s --url-contains ajax=true
h5i browser requests --session s --json
h5i browser audit    --session s                  # verbs, requests and lifecycle, in order
```

Every request the session's Chromium sends goes through h5i's proxy, and the
proxy writes the row before the bytes move. A refusal is a row too, with its
reason. Three uses in scraping:

**Counting.** Did the crawl make the number of page requests you expected? The
log also holds the page's stylesheets and images, its refused third parties,
and Chromium's own background traffic. So count by URL and by origin, not by
row (Lab 04, and [`05-limits.md`](05-limits.md#51-the-log-holds-the-browser-not-just-the-page)).

**Diagnosing a page that does nothing.** A refused CDN script leaves no trace
inside the page. No console error, a click that "works", and no data. The log
is the one place the refusal is written down (Lab 06).

**Finding the endpoint.** Note the last `seq`, do the click once, then read
`--since` that number. The XHR the page's own code built is in there, and it is
usually the thing you should have been fetching all along.

Each row has a `seq`. That number is a handle on the stored request:

```bash
h5i browser resend 25 --set query.year=2014 --session s --json
```

`resend` sends that exact request again, with the same headers and cookies and
one part changed, through the same policy, and answers with the response.
`--set` takes `query.NAME=`, `header.NAME=`, `form.NAME=`, `json.NAME=` and
`path=`. The body comes back as a preview of at most 4 KiB. Check
`body_truncated` before parsing it.

## 1.7 The allowlist

A session grants **the origin of the URL you opened, and nothing else**, plus
loopback. Every other fetch (fonts, analytics, CDN scripts, Chromium phoning
home) is refused at the proxy and written to the log.

```bash
h5i browser open https://site.example/ --session s --new --allow https://cdn.example
```

`--allow` is repeatable, and it is fixed when the session opens. Asking for it
on an `open` that would reuse a session is refused rather than ignored.

For a scraper this is mostly a gift: you did not want the analytics beacon. It
becomes a problem exactly once, when the refused thing is the page's own
JavaScript library. Then the page looks like a page with no data, and only the
log says otherwise.

## 1.8 Driving a page

```bash
h5i browser snapshot -i --session s            # -> - textbox "Search" [ref=e9]
h5i browser type  @e9 "New York" --session s
h5i browser press Enter --session s
h5i browser click @e3 --session s
h5i browser click 'a.next' --session s         # a CSS selector works too
h5i browser select @e5 express --session s     # by the option's value
h5i browser set-checked @e4 true --session s
h5i browser scroll 4000 --session s
h5i browser wait-for --selector tr.film --session s
h5i browser wait-for --text 'Results' --session s
h5i browser navigate https://site.example/next --session s
```

**Take a `@ref` from the snapshot you just took.** It names an element in that
reading of the page, and this version does not check that it still does. For a
scraper you will run again, keep a CSS selector. Every page verb that takes a
`@ref` takes one.

**`✓ Done` means dispatched, not effective.** What happened next is in the log
(`requests --since`) and in the page (`eval`). A click that "worked" on a page
whose library was refused did nothing at all.

**`wait-for` gives up after 30 seconds** and says only that. It cannot tell "not
yet" from "never". When it times out, read the log since the action that should
have caused the change.

**A scroll is a real scroll.** Chromium fires the page's own handlers, so a
lazy-loading page loads as you go. Read the log before deciding the gesture was
necessary: Lab 08 scrolls, renders more rows, and fetches nothing, because the
data was in the first response.

## 1.9 A worked minute

```bash
export PATH="$PWD/bin:$PATH"
h5i browser open https://books.toscrape.com/ --session bk --new
h5i browser snapshot --session bk | head -40
extract '{"title": ["h3 a"]}' --session bk

extract '{"books": [{"selector": "article.product_pod", "fields": {
  "title": {"selector": "h3 a", "attr": "title"},
  "price": "p.price_color"}}]}' --session bk

extract '{"next": {"selector": "li.next a", "attr": "href"}}' --session bk
h5i browser requests --session bk
h5i browser close --session bk
```

Look at the page, name the fields, ask for rows, take the next link from the
site, check what you fetched. Every lab in this course is those five steps with
different selectors in them.

Next: [`02-method.md`](02-method.md).
