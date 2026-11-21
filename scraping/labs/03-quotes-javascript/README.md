# Lab 03 — Quotes to Scrape, JavaScript

**Site:** [quotes.toscrape.com/js/](https://quotes.toscrape.com/js/) · **Skill:** the response vs the rendered DOM · **★** ②

The publisher's own JavaScript exercise: the same hundred quotes as Lab 02,
served by a page whose HTML contains none of them. They are written into the
DOM on load by an inline `<script>` holding a `data` array.

An h5i session is a real Chromium behind h5i's capture proxy, so the page's
JavaScript always runs. What h5i adds is the other half: every response the
browser received is kept, byte for byte, as the server sent it. So every page
has two readings. **The response is what the server said. The DOM is what the
scripts built from it.** This lab is about reading both and knowing which one
your data lives in.

**Goal:** count the quotes in each reading, and a CSV of quote and author.

**Start here**

```bash
. lib/h5i.sh                                    # extract, js, response
h5i browser open https://quotes.toscrape.com/js/ --session lab03 --new
extract '{"quote": ["span.text"]}' --session lab03          # the DOM
response quotes.toscrape.com/js/ --session lab03 | grep -c 'class="quote"'   # the response
```

**Hint:** the two numbers disagree, and neither is a broken selector. Decide
where the quotes *are* in the response before you trust the DOM.

Then: [`NOTES.md`](NOTES.md).
