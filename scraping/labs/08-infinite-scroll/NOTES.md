# Lab 08 — writeup

## The loop works, and it is the wrong tool

```
# rendered before scrolling: 3
# after a scroll: 6  (data requests it caused: 0)
# after a scroll: 9  (data requests it caused: 0)
# after a scroll: 12  (data requests it caused: 0)
```

The scroll is a real scroll in a real Chromium, the page's handler runs, and
three more products render each time. Three per scroll means about **39 round
trips** to see a dataset that was already in your hands.

The second number is the one to read. `scrape.sh` notes the last `seq` before
each scroll and counts the same-origin requests after it, leaving out product
images. It is zero every time. The page fetched nothing to draw those rows,
because it had nothing left to fetch.

**And the stop condition is still a guess, which is the part to take away.**
*Stop when a scroll adds no items* cannot tell the end of the data from a
mechanism that did not run. A lazy-loader waiting on an intersection observer
that never fires, a script refused at the proxy (Lab 06), a rate limiter that
started returning empty pages: from inside the loop, all of them look exactly
like the end of the data. An earlier h5i, whose scroll fired no events, stopped
this exact loop at three rows out of 117 with no error and no warning. A stop condition that cannot distinguish "done" from "broken" will
eventually return a short file and call it a success.

Where a real one comes from: a total the page states, a `next` link whose
absence is meaningful, a `pageCount` in a JSON payload. Labs 09 and 10 are both
about having one.

## Where the data was

```bash
extract '{"items": {"selector": "[data-items]", "attr": "data-items"}}' --session lab08
```

```json
[{"id": 60, "title": "Asus VivoBook X441NA-GA190", "price": 295.99, "description": "…"}, …]
```

117 products, as JSON, in an attribute on the wrapper element, in the **first
response**. `served | grep -c data-items` finds it in the body the server sent.
The scroll is a rendering decision made in JavaScript over data that had
already arrived. No scrolling needed, one request.

That is why a working scroll changes nothing about the answer. The gesture
works, and it only redraws what the first response delivered.

The sibling attributes say so out loud: `data-type="scroll"` here, and
`data-pages` on the paginated version of the same catalogue. The page is
configured by attributes, and reading the configuration is faster than
inferring it from behaviour.

## The habit

Before automating an interaction, **look at what the first response already
contains.** Search the served HTML for a string you can see on screen — a
product name, a price — and see what surrounds it. If it is inside a JSON
literal rather than inside markup, the interaction was never going to be
necessary.

The places worth searching, roughly in order of how often they pay:

| Where | Looks like |
| --- | --- |
| a `data-*` attribute | `data-items='[{…}]'`, `data-props`, `data-state` |
| a framework state blob | `#__NEXT_DATA__`, `window.__NUXT__`, `__INITIAL_STATE__` |
| a JSON-LD block | `<script type="application/ld+json">` |
| an inline literal | `var data = [{…}]` (Lab 03) |
| an endpoint the page calls | found in the script source (Lab 06) |

`served` reads the fourth. `h5i browser requests --since SEQ`, after doing the
thing once, reads the fifth.
