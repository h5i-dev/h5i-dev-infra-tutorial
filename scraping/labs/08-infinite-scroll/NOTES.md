# Lab 08 — writeup

## The loop is correct and the answer is wrong

```
# rendered before scrolling: 3
# after a scroll: 6
# after a scroll: 9
# after a scroll: 12
# requests the scrolls made: 0
```

The scroll works. Chromium fires the page's own handler and three more
products render each time, so the loop grows. It is still the wrong tool:
three per scroll means about **39 round trips** to see a dataset that was
already in your hands. And the request log says so. The scraper takes the log's
cursor before the first scroll and reads it with `--since` afterwards: the
scrolls fetched nothing, because there was nothing left to fetch.

**The stop condition is the part to take away.** A slow network, a lazy-loader
waiting on an intersection observer that never fires because the viewport is
720px tall, a rate limiter that started returning empty pages: all of them
look, from inside the loop, exactly like the end of the data. A stop condition
that cannot distinguish "done" from "broken" will eventually return a short file
and call it a success. Earlier versions of this course ran on an engine whose
scroll fired no event at all, and the loop stopped at three rows with no error.
Same loop, same silence.

Where a real one comes from: a total the page states, a `next` link whose
absence is meaningful, a `pageCount` in a JSON payload. Labs 09 and 10 are both
about having one.

## Where the data was

```bash
response laptops --session lab08 | grep -o "data-items='.\{80\}"
```

```json
[{"id": 60, "title": "Asus VivoBook X441NA-GA190", "price": 295.99, "description": "…"}, …]
```

The attribute is HTML-escaped (`&quot;` for every quote), so unescape it before
parsing; `html.unescape` in the scraper does that. 117 products, as JSON, in an attribute on the wrapper element, in the **first
response**. The scroll is a rendering decision made in JavaScript over data
that had already arrived. One request, no scrolling, and the scraper reads it
from the captured response rather than the DOM, so it is the server's copy and
not whatever the script has done to it since.

The sibling attributes say so out loud: `data-type="scroll"` here, and
`data-pages` on the paginated version of the same catalogue. The page is
configured by attributes, and reading the configuration is faster than
inferring it from behaviour.

## The habit

Before automating an interaction, **look at what the first response already
contains.** Search the captured response for a string you can see on screen
(a product name, a price) and see what surrounds it. If it is inside a JSON
literal rather than inside markup, the interaction was never going to be
necessary.

The places worth searching, roughly in order of how often they pay:

| Where | Looks like |
| --- | --- |
| a `data-*` attribute | `data-items='[{…}]'`, `data-props`, `data-state` |
| a framework state blob | `#__NEXT_DATA__`, `window.__NUXT__`, `__INITIAL_STATE__` |
| a JSON-LD block | `<script type="application/ld+json">` |
| an inline literal | `var data = [{…}]` (Lab 03) |
| an endpoint the page calls | in `h5i browser requests` (Lab 06) |

`response URL` reads the first four, out of the capture. `h5i browser requests`
lists the fifth, with the body one `response` away.
