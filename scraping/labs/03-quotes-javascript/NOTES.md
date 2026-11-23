# Lab 03 — writeup

## Two reads, two answers, both true

```
# served:   0 quote elements, data literal present: True
# rendered: 10 quote elements
```

`extract` reads the live DOM in the session's Chromium, after every script on
the page has run. It finds ten `div.quote` elements because the page's script
wrote them there.

`served` asks the server for the same URL again, from inside the page, and
prints the body before anything ran on it. That body holds no `div.quote` at
all. It holds this:

```js
var data = [
    {
        "tags": ["change", "deep-thoughts", "thinking", "world"],
        "author": {"name": "Albert Einstein", "goodreads_link": "/author/show/9810.Albert_Einstein", …},
        "text": "“The world as we have created it is a process of our thinking. …”"
    },
```

So the quotes were in the response the whole time, in a JavaScript literal
rather than in markup. Nothing was fetched after load to fill them in.
`h5i browser requests` shows the page, two stylesheets, jQuery, a favicon, and
one more `GET /js/` for every `served` you ran, and no data request among them.

## Why the difference matters when the browser renders it anyway

In a real browser you could ignore it, and Chromium renders the page correctly.
Three reasons not to.

**It tells you where the data comes from.** Rendered-but-not-served has three
explanations: a literal in the page (this lab), a `data-*` attribute (Lab 08),
or a request after load (Lab 06). They want three different scrapers, and only
the served body tells them apart.

**It tells you what will break.** A rendered DOM is the output of somebody
else's code, run on a timer, over data that may arrive in any order. The
literal is the input to that code. When the site's template changes, the DOM
changes. The data array usually does not.

**It tells you what you are running.** The session's Chromium executed that
script on your machine. Here it is harmless. On a site you do not control, page
script is the channel through which a page acts on whoever reads it, and when
the reader is an agent that includes prompt injection. There is no switch to
turn script off. Knowing the data was in the served body means you could have
read it without trusting the page's code at all. See
[`../../docs/05-limits.md`](../../docs/05-limits.md#53-every-page-runs-its-javascript).

## Which one to scrape

`scrape.sh` takes the rendered DOM, because on this page it is the shorter road
and the selectors are the same ones Lab 02 used:

```json
"quotes": [{"selector": "div.quote", "fields": {"quote": "span.text", "author": "small.author"}}]
```

The other road is the literal, and it is the one to take when the rendered page
is slow, flaky, or not something you want to execute:

```bash
served --session lab03 | python3 -c '
import json, re, sys
src = sys.stdin.read()
data = json.loads(re.search(r"var data = (\[.*?\]);", src, re.S).group(1))
print(len(data), data[0]["author"]["name"])'
```

That is brittle against a reformat of the script. But it is typed (tags arrive
as a list, the author as an object with a Goodreads link the page never shows),
and it needs nothing from the browser but the body.

## The order to try, on any page

| | Served body | Route |
| --- | --- | --- |
| 1 | JSON-LD, OpenGraph, microdata | read the metadata |
| 2 | a `data-*` attribute holding JSON | parse the attribute (Lab 08) |
| 3 | `#__NEXT_DATA__` or another framework's state blob | parse the blob (Lab 10) |
| 4 | a script literal, as here | parse the literal, or read the rendered DOM |
| 5 | none of the above, but the rendered page has it | find the request that fetched it (Lab 06) |
