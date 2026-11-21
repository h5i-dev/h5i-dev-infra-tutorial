# Lab 06 — Oscar Winning Films

**Site:** [scrapethissite.com/pages/ajax-javascript](https://www.scrapethissite.com/pages/ajax-javascript/) · **Skill:** the request under the click · **★** ③

Scrape This Site's AJAX lesson. Six year links; clicking one fetches that
year's films and draws them into a table, with a deliberate 1.5-second delay so
you can watch it happen. The site's own brief is the answer key: *"browse
through your network tab to see those AJAX requests and scrape them."*

h5i's request log is that network tab, written before the bytes move.

One thing goes wrong first, in a useful way: a **denied origin**. The page
loads jQuery from `ajax.googleapis.com`, which the session does not grant
itself, so the library never arrives, no handler is ever bound, and the page
looks like a page with no data. The click dispatches onto a link listening to
nothing. The fix is `--allow`, and the request log names the refusal.

With jQuery allowed, the click works: the handler fires its request, and the
films arrive. Then the lab asks the real question, which is the same either
way: *what request did that click make, and why not make it yourself?*

**Goal:** a year of films as CSV, and a clear account of which request
produced them.

**Start here**

```bash
. lib/h5i.sh
h5i browser open https://www.scrapethissite.com/pages/ajax-javascript/ --session lab06 --new
js 'typeof window.jQuery' --session lab06               # look at this answer
h5i browser requests --session lab06 --denied-only      # and this one
h5i browser close --session lab06

h5i browser open https://www.scrapethissite.com/pages/ajax-javascript/ \
    --session lab06 --new --allow https://ajax.googleapis.com
h5i browser snapshot --interactive --session lab06 | grep 2015
h5i browser click @e3 --session lab06
h5i browser requests --session lab06 --url-contains ajax=true   # the lab is in here
```

**Hint:** when a click produces nothing, the question is not "what else can I
click". It is "what request was that click supposed to make", and the page's
own source says. When the click *does* work, ask the same question anyway: the
answer is one request instead of a rendered page, and `h5i browser requests`
hands it to you.

Then: [`NOTES.md`](NOTES.md).
