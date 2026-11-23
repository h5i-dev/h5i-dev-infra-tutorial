# Lab 08 — Infinite scroll

**Site:** [webscraper.io/test-sites/e-commerce/scroll](https://webscraper.io/test-sites/e-commerce/scroll/computers/laptops) · **Skill:** the stop condition that lies · **★** ③

The same catalogue as Lab 07, rendered as an infinite scroll. Also from Web
Scraper's [test sites](https://webscraper.io/test-sites), and carrying the same
notice: it exists to be practised on, and nothing is for sale.

The obvious scraper is: scroll, count, scroll again, stop when the count stops
growing. In the session's Chromium it works. Each scroll fires the page's own
handler, and three more products appear. Keep going and you will reach all 117
in about 39 scrolls.

Then read the request log for what those scrolls fetched, find where the
hundred and seventeen actually were, and count what the scrolling cost you to
see them.

**Goal:** every laptop, and an understanding of why the scroll loop was never
going to get them.

**Start here**

```bash
h5i browser open https://webscraper.io/test-sites/e-commerce/scroll/computers/laptops \
    --session lab08 --new
h5i browser eval 'document.querySelectorAll("div.thumbnail").length' --session lab08
h5i browser scroll 4000 --session lab08
h5i browser eval 'document.querySelectorAll("div.thumbnail").length' --session lab08
h5i browser requests --session lab08 --url-contains webscraper.io
```

**Hint:** the page knows how many products it has. Look at the attributes on
the element that wraps them, not at the elements inside it.

Then: [`NOTES.md`](NOTES.md).
