# Web scraping

A hands-on course in scraping, built around
[h5i](https://github.com/h5i-dev/h5i)'s browser sessions. A session is a real
Chromium, driven through agent-browser and pointed at a capture proxy that h5i
runs for it. The proxy writes down every request the page made, and every
request it refused, before the bytes move. So "what did my scraper actually
fetch?" always has an exact answer.

> One of the two courses in this repository. The other is
> [`../websec/`](../websec/), which uses the same sessions to bend requests
> rather than to read pages. Neither assumes the other.

Ten labs, ten sites, each site published by its operator **so that people would
scrape it**. Every lab is a brief, a scraper that really runs, and a writeup
about the one thing that site teaches. Everything below is run from this
directory:

```bash
cd scraping

./run.sh                 # list the labs
./run.sh 01              # run lab 01, write out/01-books-to-scrape.csv
./run.sh 01 -            # run it, print the CSV instead
PAGES=10 ./run.sh 02     # take more of the site
PACE=3 ./run.sh 09       # go slower
./test-all.sh            # all ten, about thirty requests
cat labs/01-*/README.md  # the brief
cat labs/01-*/NOTES.md   # the writeup
```

Python's standard library, h5i, and agent-browser. No Docker, no accounts, no
keys.

---

## 1. Setup

You need **Python 3.11+**, **h5i 0.5.6 or newer**, and **agent-browser 0.25 or
newer**, which runs the Chromium half of every session. The verbs this course
uses are in the base binary; there is no plugin to install.

```bash
curl -fsSL https://h5i.dev/install.sh | sh
npm install -g agent-browser && agent-browser install
h5i browser eval --help          # if this fails, your h5i predates the Chromium sessions
```

On Linux ARM64 `agent-browser install` has no Chrome to download. Point it at
any Chromium you already have:

```bash
export AGENT_BROWSER_EXECUTABLE_PATH=~/.cache/ms-playwright/chromium-*/chrome-linux-arm64/chrome
```

Where Chromium's own sandbox cannot start (common without root), set
`AGENT_BROWSER_ARGS=--no-sandbox`, and read
[`docs/05-limits.md`](docs/05-limits.md#510-setup-seams) first.

Building from source instead:

```bash
git clone https://github.com/h5i-dev/h5i && cd h5i
cargo build --release --workspace
```

If h5i is not on your `PATH`, point the scripts at it:

```bash
export H5I=~/src/h5i/target/release/h5i
./test-all.sh
```

The labs call two small helpers of the course's own, [`bin/extract`](bin/extract)
and [`bin/served`](bin/served), through `lib/h5i.sh`. To use them by hand while
you work through `docs/` and the briefs:

```bash
export PATH="$PWD/bin:$PATH"
```

Check it works:

```bash
./run.sh 01 - | head -3
title,price,stock,url
A Light in the Attic,£51.77,In stock,https://books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html
```

**This course needs the network**, unlike the one next door. Its ten targets are
public practice sites, and a lab can fail because a site redesigned, went down,
or throttled you — `test-all.sh` says which lab and what it got, and deciding
which of those happened is yours.

Verified end to end against **h5i 0.5.6** with **agent-browser 0.27**. The
course was first written for an older h5i that had its own engine and its own
reader verbs (`read`, `extract`, `markdown`, `--script`). h5i 0.5.0 still had
them; by 0.5.6 the engine had been replaced by Chromium and those verbs were
gone. These labs need a build with `h5i browser eval`, and no longer run on the
older ones. [`docs/05-limits.md`](docs/05-limits.md#512-what-went-away-with-the-old-engine)
lists what went away and what the course uses instead.

---

## 2. How to use this book

**Read `docs/` first.** Five short chapters, and they are the part that makes
the labs mean something:

| | |
| --- | --- |
| [`docs/01-the-reader.md`](docs/01-the-reader.md) | the session: what it is, reading a page, the extract schema, served vs rendered, the request log, `resend` |
| [`docs/02-method.md`](docs/02-method.md) | how to approach a site you have never scraped |
| [`docs/03-cheatsheet.md`](docs/03-cheatsheet.md) | one page: every verb, every schema form, every place data hides |
| [`docs/04-etiquette-and-scope.md`](docs/04-etiquette-and-scope.md) | rate, robots, terms, personal data — and why these ten sites |
| [`docs/05-limits.md`](docs/05-limits.md) | where the session ends: what the proxy sees and does not, what Chromium does unasked, and the probe for each |

**Then work the labs in order.** Each assumes the last. Give the brief a real
attempt before opening `NOTES.md`; unlike the websec course, the writeup here
is the teaching rather than a spoiler, but it lands better after you have been
stuck.

**The argument the whole course is making**, stated once so you can watch it
recur: *find the data before you write a selector.* Selectors are step four of
five, and on four of these ten sites the "hard" page turns out to ship its
entire dataset as clean JSON in the first response.

---

## 3. The curriculum

### Part I — Reading one page

| # | Lab | Site | Teaches | ★ |
| --- | --- | --- | --- | --- |
| 01 | [Books to Scrape](labs/01-books-to-scrape) | [books.toscrape.com](https://books.toscrape.com/) | one page to CSV; anchoring selectors to a row | ① |
| 02 | [Quotes to Scrape](labs/02-quotes-pagination) | [quotes.toscrape.com](https://quotes.toscrape.com/) | a field that repeats, and the three ways out | ① |
| 03 | [Quotes, JavaScript](labs/03-quotes-javascript) | [quotes.toscrape.com/js](https://quotes.toscrape.com/js/) | served vs rendered, and which one to scrape | ② |

### Part II — Pages that are really URLs

| # | Lab | Site | Teaches | ★ |
| --- | --- | --- | --- | --- |
| 04 | [Countries](labs/04-countries-to-csv) | [scrapethissite.com](https://www.scrapethissite.com/pages/simple/) | 250 rows in one request; counting what you fetched | ① |
| 05 | [Hockey Teams](labs/05-hockey-forms) | [scrapethissite.com](https://www.scrapethissite.com/pages/forms/) | a form is a URL; `@ref` vs a durable selector | ② |
| 06 | [Oscar Winning Films](labs/06-oscars-ajax) | [scrapethissite.com](https://www.scrapethissite.com/pages/ajax-javascript/) | a refused CDN, the request under the click, and `resend` | ③ |

### Part III — Crawls, and knowing when they finished

| # | Lab | Site | Teaches | ★ |
| --- | --- | --- | --- | --- |
| 07 | [E-commerce catalogue](labs/07-ecommerce-catalogue) | [webscraper.io](https://webscraper.io/test-sites) | a crawl whose shape comes from the site | ② |
| 08 | [Infinite scroll](labs/08-infinite-scroll) | [webscraper.io](https://webscraper.io/test-sites) | the stop condition that lies; `data-*` payloads | ③ |
| 09 | [ScrapingCourse shop](labs/09-scrapingcourse-shop) | [scrapingcourse.com](https://www.scrapingcourse.com/) | verifying a crawl against the site's own total | ② |

### Part IV — Stop writing selectors

| # | Lab | Site | Teaches | ★ |
| --- | --- | --- | --- | --- |
| 10 | [Oxylabs sandbox](labs/10-oxylabs-next-data) | [sandbox.oxylabs.io](https://sandbox.oxylabs.io/) | `#__NEXT_DATA__`, and the order to look in | ③ |

---

## 4. What each lab contains

```
labs/01-books-to-scrape/
  README.md    the brief — the site, why it is fair game, the goal, one hint
  scrape.sh    a scraper that really runs, commented where it is doing something
  NOTES.md     the writeup — what the page does, what breaks, the general rule
```

`bin/` holds the course's two helpers. `extract` reads named fields by CSS
selector through `h5i browser eval`. `served` prints the body the server sent,
before any script ran. `lib/` holds the rest: `rows.py`, which turns a flat
schema's columns into CSV and **refuses** when they do not line up, and
`h5i.sh`, which opens a session, closes it however the script ends, and paces
every request.

Output goes to `out/`, which is not tracked.

---

## 5. Scope

Every target here is a site whose operator published it to be scraped, and
[`docs/04-etiquette-and-scope.md`](docs/04-etiquette-and-scope.md) quotes each
one saying so. Each lab fetches two or three pages, a second apart, and says how
to raise that.

None of it transfers automatically to a site that did not say so. What transfers
is the method — and the habit of knowing, and being able to state, exactly what
your scraper fetched.

Apache-2.0, like h5i.
