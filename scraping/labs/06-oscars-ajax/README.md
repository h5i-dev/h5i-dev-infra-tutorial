# Lab 06 — Oscar Winning Films

**Site:** [scrapethissite.com/pages/ajax-javascript](https://www.scrapethissite.com/pages/ajax-javascript/) · **Skill:** the request under the click · **★** ③

Scrape This Site's AJAX lesson. Six year links; clicking one fetches that
year's films and draws them into a table, with a deliberate 1.5-second delay so
you can watch it happen. The site's own brief is the answer key: *"browse
through your network tab to see those AJAX requests and scrape them."* The
session's request log is that network tab, written by the proxy.

Two things happen here, in a useful order.

The first is a **refused origin**. The page loads jQuery from
`ajax.googleapis.com`, which the session does not grant itself. The proxy
refuses it, nothing the page wrote in jQuery ever runs, and the page looks like
a page with no data. It also reports nothing about it. The console is empty,
and the click answers `✓ Done`.

The second is the payoff once the origin is granted. The click works, and the
request it made is in the log with a sequence number. That number is a handle:
`h5i browser resend` sends the same request again with the year changed, and
you never need to click again.

**Goal:** two years of films as CSV, from requests you can name, and a clear
account of which step produced them.

**Start here**

```bash
h5i browser open https://www.scrapethissite.com/pages/ajax-javascript/ --session lab06 --new
h5i browser eval 'typeof window.jQuery' --session lab06
h5i browser click '[id="2015"]' --session lab06
h5i browser eval 'document.querySelectorAll("tr.film").length' --session lab06
h5i browser requests --session lab06 --denied-only          # ← the lab starts in here
```

**Hint:** when a click produces nothing, the question is not "what else can I
click". It is "what request was that click supposed to make, and did the code
that makes it ever arrive?" When the click *does* work, ask the first half
anyway. The answer is one request instead of a rendered page.

Then: [`NOTES.md`](NOTES.md).
