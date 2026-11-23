# Lab 03 — Quotes to Scrape, JavaScript

**Site:** [quotes.toscrape.com/js/](https://quotes.toscrape.com/js/) · **Skill:** served vs rendered · **★** ②

The publisher's own JavaScript exercise: the same hundred quotes as Lab 02,
served by a page whose HTML contains none of them. They are written into the
DOM on load by an inline `<script>` holding a `data` array.

A session's Chromium runs that script, the way any browser would, so the quotes
are simply *there* when you read the page. That is convenient, and it hides the
question this lab is about. **Was the data in the response, or did a script
build it?** The answer decides how fragile your scraper is, how much it costs,
and whether you needed a browser at all.

**Goal:** the same page read twice (as the server sent it, and as the browser
built it), an account of the difference, and a CSV.

**Start here**

```bash
h5i browser open https://quotes.toscrape.com/js/ --session lab03 --new
extract '{"quote": ["div.quote span.text"]}' --session lab03     # what the browser built
served --session lab03 | grep -c 'class="quote"'                 # what the server sent
served --session lab03 | grep -n 'var data'
```

**Hint:** ten and zero are both right. Decide what each one is a fact about
before you choose which to scrape.

Then: [`NOTES.md`](NOTES.md).
