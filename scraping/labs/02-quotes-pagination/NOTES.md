# Lab 02 — writeup

## Ten quotes, thirty tags

```json
{"quote": [ …10 items… ], "tags": [ …30 items… ]}
```

No flat schema fixes this, and it is worth being precise about why. A flat
schema returns columns, and a column is a flat list of every match in document
order. A one-to-many field flattens into that list with nothing marking where
one quote's tags end and the next one's begin. The information needed to
regroup them (the parent each match came from) is exactly what a flat list has
thrown away.

Three ways out, in the order worth trying:

**1. Find where the page already joined them.** This one has:

```html
<div class="tags">
    <meta class="keywords" itemprop="keywords" content="change,deep-thoughts,thinking,world">
```

```json
"tags": [{"selector": "div.quote div.tags meta[itemprop=keywords]", "attr": "content"}]
```

Ten values, comma-separated, one per quote — because a `<meta itemprop>` exists
once per item by construction. Microdata is put there for machines, and you are
a machine. Check for it before writing code.

**2. Read a list inside each row.** With `fields`, a sub-spec in an array is
read inside that one quote:

```json
"quotes": [{"selector": "div.quote", "fields": {"quote": "span.text", "tag_list": ["div.tags a.tag"]}}]
```

Each quote carries its own list of tags, and a quote with none carries `[]`.
This works on any page, whether or not it was kind enough to join the values
for you. `scrape.sh` reads both routes and refuses to write a line where they
disagree, which is the cheapest test there is that the page still has the
shape you think.

**3. Take the whole row's HTML and parse it.** `{"selector": "div.quote",
"attr": "outerHTML"}` in an array gives you one string per quote, and you can
group inside them with whatever you like. This is the escape hatch when a row
is too irregular for selectors, and it gives up everything `extract` was doing
for you.

## The author link is the key you actually want

`{"selector": "div.quote span a", "attr": "href"}` yields
`https://quotes.toscrape.com/author/Albert-Einstein`. Two quotes by Einstein
give the same URL, and the display name does not: `Albert Einstein` today is
`Einstein, Albert` after a redesign. **Prefer the identifier the site routes
on** — a URL, a slug, a numeric id — over the string it renders. It is the
column that will still join correctly next month.

## Pagination

Identical to Lab 01: `li.next a` while it exists, absent on the last page.
`quotes.toscrape.com` has ten pages; `PAGES=10 ./run.sh 02` takes all hundred
quotes and about twenty seconds.

The site also publishes the same corpus at
[`/api/quotes?page=1`](https://quotes.toscrape.com/api/quotes?page=1), which is
the subject of Lab 06's lesson arriving early: when a JSON endpoint exists,
scraping the HTML is a choice, and usually the wrong one.
