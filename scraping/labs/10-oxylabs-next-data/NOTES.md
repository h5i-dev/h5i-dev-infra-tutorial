# Lab 10 — writeup

## `#__NEXT_DATA__`

A server-rendered Next.js page ships the props it rendered from, as JSON, in a
script tag with a fixed id. Reading it is one selector that will not rot:

```bash
extract '{"blob": "#__NEXT_DATA__"}' --session lab10            # from the DOM
response sandbox.oxylabs.io/products --session lab10 | grep -o '__NEXT_DATA__.\{300\}'
```

The scraper reads it from the response, not the DOM. Both work here, but the
response is the one that is true before any script runs, and on an app router
page the client can rewrite or remove the tag after hydration.

```json
{"props": {"pageProps": {
    "totalCount": 3000, "pageCount": 94, "currentPage": 1, "perPage": 32,
    "products": [{"game_name": "The Legend of Zelda: Ocarina of Time",
                  "meta_score": 99, "user_score": 91, "platform": "['nintendo-64']",
                  "developer": "Nintendo", "rating": "E", "inStock": true, "id": 1}, …]}}}
```

Compare that with what selectors would have given you:

| | selectors | `__NEXT_DATA__` |
| --- | --- | --- |
| product name | `.css-1kz6e5b` — rotates on a CSS edit | `game_name` |
| score | text, `"99"` | `99`, an integer |
| in stock | inferred from a badge's presence | `inStock: true` |
| id | parsed out of an href | `id: 1` |
| total products | not on the page | `totalCount: 3000` |
| pages | counted from the pager | `pageCount: 94` |

Typed values instead of strings. Fields the page does not display. A stop
condition stated as a number. And one selector instead of six.

## Where else to look

Reading the state blob is a general move with a different name on each stack:

| Stack | Where |
| --- | --- |
| Next.js (pages router) | `#__NEXT_DATA__` |
| Next.js (app router) | `self.__next_f.push([…])` chunks in inline scripts |
| Nuxt | `window.__NUXT__` |
| Redux-ish SSR | `window.__INITIAL_STATE__`, `__PRELOADED_STATE__` |
| schema.org | `<script type="application/ld+json">` |
| Angular Universal | `<script id="ng-state" type="application/json">` |
| anything at all | a `data-*` attribute holding JSON (Lab 08) |

A `grep` of the captured response finds any of them in one command, and is
worth running on any page before anything else:

```bash
response sandbox.oxylabs.io/products --session lab10 \
  | grep -oE '__NEXT_DATA__|__next_f|__NUXT__|__INITIAL_STATE__|application/ld\+json|data-[a-z-]+=' \
  | sort | uniq -c
```

## The order this course has been arguing for

1. The response: does the page describe itself (JSON-LD, `<meta>`)?
2. Is the data in a state blob or a `data-*` attribute of the response?
3. Is there an endpoint the page calls? `h5i browser requests` lists it.
4. Only now: selectors, anchored to a row container.
5. Only if the data genuinely is not in any response: selectors against the
   rendered DOM, which is whatever the scripts made of it.

Steps 1 to 3 cost one command each. Step 4 is where most scraping tutorials
start, and it is the most fragile of the five.

## A caveat about state blobs

They are a snapshot of what the server sent that page, which means:

* they can carry fields the site did not mean to publish. Being in the response
  is not permission to redistribute — see
  [`../../docs/04-etiquette-and-scope.md`](../../docs/04-etiquette-and-scope.md);
* they can go stale relative to what the page later fetched and re-rendered;
* they are an internal interface, and change without notice. Which is true of
  the markup too, but a blob changes in bulk when a framework is upgraded.

Check `pageCount` and `totalCount` against the rendered page once, so you know
the blob is describing the page you think it is.
