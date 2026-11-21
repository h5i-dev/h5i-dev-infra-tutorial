# Lab 03 — writeup

## Two readings of one page

```
# in the response: 0 quote elements, and a 'var data = [' literal: 1
# in the DOM:      10 quote elements
```

Both are true. The server sent no `div.quote` at all. It sent a `<script>`
holding `var data = [{"tags": ["change", …], "author": {…}, "text": "…"}, …]`
and a loop that turns each entry into markup. Chromium ran the loop, so the DOM
has ten quotes and a selector against it works.

The first number is what an HTTP client sees, what a `curl` sees, and what h5i
captured at its proxy before the browser touched it:

```bash
h5i browser requests --session lab03 --url-contains /js/   # find the res_ id
h5i websec show res_N --session lab03 --body-to -          # the body, as sent
```

The `response` helper in `lib/h5i.sh` does both steps. Look the id up every
time: Chromium's own background traffic takes ids too, so they are not the
same from one run to the next.

## Why the response is the better place to look

The DOM is the easy reading, because it is what you see on screen. The
response is the honest one, for three reasons.

**It is what the server committed to.** A script can reformat, truncate,
localise or drop fields. Here the literal carries the author's slug and
Goodreads link, and the rendered page shows neither. Whatever the render
drew, the response is the superset.

**It does not depend on a timing.** A script-rendered page can render
differently on the same input: a timer, a race between two fetches, a feature
flag. A selector against the DOM is a bet that the script finished the way it
did yesterday. The response is fixed the moment it arrives.

**It tells you whether you need a browser at all.** If the data is in the
response, a plain HTTP client gets it too, on a site where you would rather not
run the page's code. On a site you do not control, with an agent reading the
result, page script is also the delivery channel for prompt injection. Knowing
that the data never needed it is worth knowing.

## Reading the literal

```bash
response quotes.toscrape.com/js/ --session lab03 \
  | python3 -c 'import json,re,sys; …'   # parse the array out of the source
```

The scraper does this and prints the count. It is brittle against a reformat of
the script, and that is a real cost: a selector against the DOM survives a
change to how the array is written, the regex does not. Labs 08 and 10 are the
cases where reading the response is not just honest but obviously right,
because the page ships its data as JSON on purpose.

## When the DOM is the answer

When you have read the response and confirmed the data is not in it: not in
the markup, not in a `<script>` literal, not in a `data-` attribute, not in
`#__NEXT_DATA__` or a JSON-LD block, and not in a JSON endpoint the page
fetched. Then the scripts built it from something else, and the DOM is where
it exists.

The order to try, on any page:

| | |
| --- | --- |
| 1 | JSON-LD, OpenGraph, `<meta>` in the response |
| 2 | a `data-*` attribute holding JSON (Lab 08) |
| 3 | `#__NEXT_DATA__` or another framework's state blob (Lab 10) |
| 4 | a JSON endpoint the page calls, in `h5i browser requests` (Lab 06) |
| 5 | the rendered DOM, with `extract` |
