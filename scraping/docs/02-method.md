# 2. Approaching a site you have not scraped

The tool is an afternoon. This chapter is the part that transfers.

---

## 2.1 Find the data before you write a selector

Most scraping tutorials start with "inspect element, copy selector." That is
step four of five, and the three steps before it are cheaper, more durable, and
frequently make step four unnecessary.

The order, and one command each:

| | Look for | Command |
| --- | --- | --- |
| 1 | metadata the page publishes about itself | `response URL \| grep -E 'ld\+json\|og:\|itemprop'` |
| 2 | JSON in a `data-*` attribute | `response URL \| grep -o 'data-[a-z-]*='` |
| 3 | a framework state blob | `response URL \| grep -E '__NEXT_DATA__\|__NUXT__'` |
| 4 | an endpoint the page calls | `h5i browser requests`, after one click; or the URL in the page's script |
| 5 | the rendered DOM | `extract` with anchored selectors |

Steps 1 to 3 read the **response**: what the server sent, before any script ran
(chapter 1, section 1.3). Labs 08 and 10 are step 2 and step 3, and in both the
"hard" page (infinite scroll, hashed class names) turns out to ship its entire
dataset as clean JSON in the first response. Lab 06 is step 4. Lab 03 is a page
where the data is in the response as a script literal, and the DOM is the
easier, less durable place to read it.

The reason to look in this order is not elegance. It is that each step up the
list is more stable than the one below: a `<meta itemprop="price">` was put
there for a machine and will not move, a class name belongs to a stylesheet and
the stylesheet gets rewritten.

## 2.2 First contact, in four commands

```bash
h5i browser open https://site.example/list --session s --new
h5i browser snapshot --session s | head -60          # what is this page?
response site.example/list --session s | grep -c 'a price you can see'   # was it sent?
h5i browser requests --session s                     # what did it fetch?
extract '{"x": ["SELECTOR"]}' --session s            # does my guess match?
```

Four questions in order: what is on the page, did the server send it or did a
script build it, what does the page load, and does my selector find it. Answering them
before writing a loop is twenty seconds against an afternoon.

## 2.3 Find the element that is one row

Everything else follows from this. Look at the markup around a value you can
see on screen and find the smallest element that contains **exactly one
record**: `article.product_pod`, `div.quote`, `tr.team`, `li.product`,
`div.thumbnail`.

Then write every selector inside it. Not because it is tidier, but because
`extract` returns columns and a column is only a table if all the columns have
the same length — and an anchored selector produces exactly one value per row
even when the row is missing the field.

Test it with the count, every time:

```bash
… | python3 -c 'import json,sys; d=json.load(sys.stdin); print({k: len(v) for k,v in d.items()})'
{'title': 20, 'price': 20, 'stock': 20, 'url': 20}
```

Four twenties is a table. Anything else is not, and `lib/rows.py` will refuse
it rather than write a file that is wrong in a way nothing downstream can see.

## 2.4 Prefer identifiers to display text

`Albert Einstein` is what the page renders. `/author/Albert-Einstein` is what
the site routes on. The first changes when a designer decides on
`Einstein, Albert`; the second changes when the site's URLs change, which is a
much rarer and much louder event.

So: keep the href, the slug, the numeric id, the UPC, the SKU. They are the
columns that still join correctly next month, and the columns that let you
deduplicate across runs. Display text is a label, not a key.

## 2.5 Take the stop condition from the site

The three shapes, best first:

| Shape | Example | Why |
| --- | --- | --- |
| a stated total | `"Showing 1–16 of 188 results"`, `"totalCount": 3000` | you can *verify* the crawl, not just end it |
| a next link whose absence is meaningful | `li.next a`, `a.next.page-numbers` | the site asserts there is no more |
| a page count | `"pageCount": 94`, the last pager link | bounded before you start |

And the shape to refuse: **"stop when a page returns fewer rows than the last."**
A page that came back short because it was throttled, because a filter got
mangled, or because an error page was served with a 200, is indistinguishable
from the end of the data. Lab 08 is a scraper whose stop condition was met on
the first iteration and returned three rows out of 117 with no error.

Best practice is both: end on the site's signal, then check the count against
the site's total, and say both numbers when you are done.

## 2.6 A form is a URL, until it is not

Ask the page what the form does, then drive it once and read where it landed:

```bash
js '[...document.forms].map(f => [f.method, f.action])' --session s   # [["get", "…/search"]]
h5i browser type 'input[name=q]' "New York" --session s
h5i browser press Enter --session s
js 'location.href' --session s       # "https://site.example/search?q=New+York"
```

A GET form is a URL template with a human wrapper on it. After one submission
you have the template, and every later query is string construction — faster,
reproducible, and immune to the page re-rendering under your @refs.

A POST form is not, and the form's `method` tells you that before you type.
Then you are either driving the form each time, or looking for the API the form
posts to; `h5i browser requests` shows the POST either way.

Read the pager the same way, rather than guessing: `page_num`, `page`, `p`,
`offset`, `start`, a cursor token. One `extract` of the pagination links
settles it, and usually hands you the last page number as a bonus.

## 2.7 Interaction is a last resort, and a click is not evidence

When a click, a scroll or a widget seems necessary:

1. Do it once, and read `h5i browser requests` for what it fetched. That URL is
   usually the real target.
2. If it fetched nothing, read the page's own `<script>`, in the captured
   response, for the request it *would* have made.
3. Call that directly.
4. Reconsider whether a browser was needed at all.

`✓ Done` from a click means the click was dispatched. Whether anything happened
is a separate question with a separate answer in the request log and the DOM.
Do not retry a click in a loop; look at what it did.

The commonest false conclusion is "the click did nothing, so the site has no
data". On a real browser the usual cause is a script that never arrived,
because the session refused its origin, and the log names it (Lab 06).

## 2.8 Decide what one run costs before you start

Write the number down: pages × requests per page. Then cap it — `PAGES`,
`LIMIT`, `MIN_ROWS` — so the cap is a decision rather than a hope. A crawl on a
site you do not control does not have a natural stopping point; it has a
calendar widget, a session id in a URL parameter, and an infinite supply of
distinct URLs that all render the same page.

Every lab here caps at two or three pages by default and says how to raise it.

## 2.9 When you have it, say what you have

A finished scrape is three numbers and one sentence: rows collected, rows the
site said existed, requests made, and which of the five routes in 2.1 produced
the data. If the first two do not match, that is the finding — not a detail to
fix later.

Next: [`03-cheatsheet.md`](03-cheatsheet.md).
