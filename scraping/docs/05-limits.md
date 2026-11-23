# 5. Where the session ends

An h5i browser session is two processes under one record: a real Chromium,
driven by [agent-browser](https://www.npmjs.com/package/agent-browser), and a
capture proxy that h5i runs for that session and points the Chromium at. h5i
does not render anything. It owns the policy, the request log and the stored
messages. Chromium owns the page.

That split decides what this chapter is about. Chromium renders like the
browser it is, so the page-level gaps an earlier edition of this chapter
listed are gone: jQuery 1.x initialises, scroll handlers fire, `href="#"`
behaves. What remains are the edges of the arrangement itself. What the proxy
sees and what it does not, what Chromium does that you did not ask for, and
what the course's own helpers cannot do for you.

Every section below says what you will observe, how this course checked it,
and what to do about it. A limit is still a fact about a version, so the
probes are written to be re-run. Everything here was observed on **h5i 0.5.6**
with **agent-browser 0.27**.

| | | |
| --- | --- | --- |
| [5.1](#51-the-log-holds-the-browser-not-just-the-page) | the log holds Chromium's own traffic, not just the page's | count by origin, not by row |
| [5.2](#52-a-refusal-is-invisible-from-inside-the-page) | a refused script leaves no trace in the page | read the log first |
| [5.3](#53-every-page-runs-its-javascript) | there is no script-off switch | read the served body, or use a box |
| [5.4](#54-unconfined-and-blind-to-certificates) | Chromium is unconfined, and accepts every certificate | `status` says so; a box changes the first |
| [5.5](#55-what-the-record-does-not-cover) | a request that bypasses the proxy is not in the record | let h5i launch the browser |
| [5.6](#56-resend-answers-with-a-preview) | `resend` returns at most 4 KiB of body | check `body_truncated` |
| [5.7](#57-wait-for-waits-it-does-not-diagnose) | `wait-for` times out after 30 s and says nothing more | read the log, not the clock |
| [5.8](#58-a-ref-is-not-checked-against-its-snapshot) | a `@ref` is not checked against the snapshot it came from | snapshot, then act |
| [5.9](#59-decoded-page-text-is-raw-page-text) | page text is escaped in h5i's output, and raw once you parse it | clean what you write |
| [5.10](#510-setup-seams) | agent-browser, Chromium and their flags | the probes below |
| [5.11](#511-what-a-verb-costs) | about 0.2 s per verb | `rpc` for tight loops |
| [5.12](#512-what-went-away-with-the-old-engine) | the old reader verbs are gone | what the course uses instead |
| [5.13](#513-what-this-is-not-for) | where to reach for something else | |

---

## 5.1 The log holds the browser, not just the page

Open `https://books.toscrape.com/` and read the log:

```
—   DENIED GET http://clients2.google.com/time/1/current?cup2key=…
—   DENIED POST https://accounts.google.com/ListAccounts?gpsia=1&source=ChromiumBrowser…
req_1        GET https://books.toscrape.com/
—   DENIED POST https://update.googleapis.com/service/update2/json?cup2key=…
—   DENIED GET https://www.google.com/async/folae?async=_fmt:pb…
—   DENIED GET https://redirector.gvt1.com/edgedl/chrome/dict/en-us-10-2.bdic
```

The page asked for none of those. Chromium did: clock sync, component updates,
the account probe, the new-tab page, a spell-check dictionary. Typing into a
form adds more (`content-autofill.googleapis.com`, on Lab 05). They go through
the same proxy as everything else, so the allowlist refuses them and the log
records them. That is the proxy doing its job. It also means **a raw row count
is not a page count.**

There is no `navigation` label to filter on either. Every row this version
writes has `"initiator": "subresource"`, the page and Chromium's background
traffic alike. So count the way Lab 04 does: by URL and by origin.

```python
documents   = [r for r in sent if r["allowed"] and r["url"] == page]
same_origin = [r for r in sent if r["allowed"] and urlsplit(r["url"]).netloc == own]
denied      = {urlsplit(r["url"]).netloc for r in sent if not r["allowed"]}
```

On Lab 04 that reads 1 page, 3 same-origin subresources, and 15 refused
origins. Ten of the fifteen are the page's third parties (fonts, analytics,
CDNs). The other five are Chromium's own.

Chromium's switches for its background traffic can be passed through
`AGENT_BROWSER_ARGS` (see [5.10](#510-setup-seams)). This course does not rely
on them. In testing, the obvious set did not silence it, and a set that did
only worked through an accident of argument splitting. Filtering by origin is
the version you can explain.

## 5.2 A refusal is invisible from inside the page

Open Lab 06's page **without** `--allow https://ajax.googleapis.com` and ask the
page what happened:

```bash
h5i browser eval 'typeof window.jQuery'                       # "undefined"
h5i browser console                                           # (nothing)
h5i browser eval 'performance.getEntriesByType("resource")
    .filter(e => e.name.includes("jquery")).map(e => e.responseStatus)'   # [0]
h5i browser click '[id="2015"]'                               # ✓ Done
h5i browser eval 'document.querySelectorAll("tr.film").length'           # 0
```

The console is empty. The resource timing says status `0`, which is what any
failed load says. The click succeeds, follows `href="#"`, and produces nothing.
From inside the page, "the CDN refused" and "the site has no data" look the
same.

The proxy saw it, and wrote it down:

```
—   DENIED GET https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js
        — origin `https://ajax.googleapis.com` is not in the allowlist
```

**Read `h5i browser requests --denied-only` before you conclude anything about
a page that does nothing.** It is the one place the refusal is recorded. Then
grant the origin at open time. A session's policy is fixed when its proxy
starts, so `--allow` on an `open` that reuses a session is refused rather than
silently ignored.

## 5.3 Every page runs its JavaScript

The old engine ran page script only when asked, and an earlier edition of this
course leaned on that: *a page that runs no script has no channel through which
to deliver a prompt injection.* There is no such switch now. `h5i browser open`
has no `--script` flag, because Chromium runs every page's JavaScript.

Two things follow.

**"Was the data in the response?" needs a separate read.** `eval` and the
course's `extract` read the DOM after scripts have changed it. `bin/served`
fetches the URL again from inside the page and prints the body as the server
sent it. Lab 03 uses both to show the gap: 0 quote elements served, 10
rendered.

**Containment is a box you ask for.** By default a session's Chromium is an
ordinary process on your machine running a stranger's code. h5i scrubs what it
relays to you (5.9). It does not stop the page from doing what pages do. When
the reader at the end of the pipe is an agent, or the site is one you would not
open in your own browser, run the session inside an h5i box
(`h5i box create NAME --profile browser`, see h5i's manual). Inside a box,
Chromium's own sandbox is disabled and the box's boundary replaces it. That is
a trade h5i documents, not one this course measured.

## 5.4 Unconfined, and blind to certificates

`h5i browser status` says both, every time:

```
placed   : on this machine, unconfined — agent-browser and Chromium run as ordinary host processes
requests : proxy-observed (captured at h5i's proxy; the external browser itself is not confined)
tls      : ignore-https-errors — Chromium accepts every certificate error for this session
```

The third line is the one a scraper should notice. The proxy decrypts HTTPS
with a per-session CA, and Chromium is launched with `--ignore-https-errors` so
that it accepts the proxy's certificates. As a side effect it accepts *every*
certificate error for that session: an expired certificate, a wrong host name,
an interception you did not set up. A scraper running this way cannot tell you
that the site's TLS is broken. If that matters, check it with a client that
verifies (`curl -v` will do), not from inside the session.

## 5.5 What the record does not cover

The request log covers what the session's Chromium sends **through the
session's proxy**. h5i's manual names the two ways to fall outside it:

* driving agent-browser yourself. Its daemon restarts when idle, and a bare
  `agent-browser open` afterwards starts a browser with no proxy;
* a Chromium relaunched by hand without the proxy settings.

Neither shows up as a refusal. They show up as an absence, which is why
`h5i browser status` warns after five minutes in which nothing was captured.
This course did not reproduce either case. It avoids them by only ever
driving the page through `h5i browser` verbs, which pass the session's launch
flags on every call. If you mix in raw `agent-browser` commands, run
`h5i browser proxy` first and export what it prints.

## 5.6 `resend` answers with a preview

`h5i browser resend SEQ` is how Lab 06 stops clicking: it re-sends the exact
request the click made, with one part changed, and answers with the response.
The body in that answer is a **preview**:

```json
"response": {"status": 200, "bytes": 1546, "body_preview": "[{\"title\": …", "body_truncated": false}
```

`body_preview` holds at most 4096 bytes. Lab 06's yearly JSON is about 1.5 KB,
so it fits, and the lab checks `body_truncated` and refuses to parse a
truncated body rather than writing half a year. A bigger answer needs another
route. `bin/served URL` reads it in full from inside the page, for a same-origin
URL. The full message is also kept in the session's owner-only store, which
the `websec` plugin reads.

## 5.7 `wait-for` waits; it does not diagnose

```
$ h5i browser wait-for --selector tr.film       # on a page where jQuery was refused
✗ Wait timed out after 30000ms                  # 33 s later
```

It waits until the element is there, or 30 seconds pass. It cannot tell "not
yet" from "never" for you. On the page above, nothing was ever going to draw a
film, and the answer took half a minute to arrive.

So don't put `wait-for` in a retry loop. When it times out, read the log since
the action that should have caused the change (`requests --since SEQ`):

| the log since the click | what it means |
| --- | --- |
| no request to the data endpoint | the handler never ran. Look for a refusal (5.2) |
| the request, a `200` | the data arrived. The question is rendering or your selector |
| the request, an error status | the site said no. Read the status before retrying |

## 5.8 A `@ref` is not checked against its snapshot

`snapshot` hands out `@e1`, `@e2`, … and every page verb takes them. They name
an element in *that* reading of the page. In this version nothing enforces
that: after navigating away, `click @e9` from the earlier snapshot still
answered `✓ Done`. Whatever it clicked, it was not necessarily what you meant.

Take the ref from a snapshot you just took, as Lab 05 does. For anything you
will run again tomorrow, keep a CSS selector instead. `click`, `type` and
`wait-for --selector` take one directly. That is the durable form, and the
course's scripts use it wherever the page offers a stable one.

## 5.9 Decoded page text is raw page text

h5i treats page output as untrusted, and what it relays arrives as JSON:

```
$ h5i browser eval '"a\u001b[31mRED\u0007b"'
"a\u001b[31mRED\u0007b"
```

The escape sequence is escaped. It cannot rewrite the terminal you print it
into. **The moment your scraper calls `json.loads`, it holds the raw bytes
again**, and a CSV cell holding `ESC[31m` is now your problem. Page text is
text a stranger wrote. Strip control characters from anything you write out,
and treat a scraped string handed to a model as data, never as instructions.

## 5.10 Setup seams

Things that stopped this course's first run, and the probe for each:

* **agent-browser is required**, 0.25 or newer. `h5i browser open` checks for it
  before creating anything, and prints the install command if it is missing.
* **No bundled Chrome on Linux ARM64.** `agent-browser install` answers *"Chrome
  for Testing does not provide Linux ARM64 builds"*. Point it at any Chromium
  you have, for example Playwright's:
  ```bash
  export AGENT_BROWSER_EXECUTABLE_PATH=~/.cache/ms-playwright/chromium-*/chrome-linux-arm64/chrome
  ```
* **`AGENT_BROWSER_ARGS` is comma-separated.** h5i joins it onto its own
  `--args` list with a comma. Space-separated flags arrive as one argument, and
  every flag after the first is lost. A flag whose value itself contains commas
  (`--disable-features=A,B`) is split apart.
* **Where Chromium's own sandbox cannot start**, which is common without root,
  set `AGENT_BROWSER_ARGS=--no-sandbox`. That turns the sandbox off, so use it
  only for a target you trust.
* **"daemon already running" is noise.** Every error from a page verb carries
  *"⚠ --args, --proxy, --ignore-https-errors ignored: daemon already running"*.
  The session's browser was launched with those flags when it opened. The
  warning is about the repeat, not a lost proxy. The line after it is the error.

## 5.11 What a verb costs

Each `h5i browser` verb is a process that talks to agent-browser, which talks
to Chromium. Ten `eval '1'` calls took 2.1 s on the machine this was written
on, so about 0.2 s each. A lab here makes a few dozen calls, so this does not
matter. A loop of a thousand reads would spend minutes on process start-up
alone. `h5i browser rpc --stdio` takes one request per line on stdin and answers
one per line, without a process per verb.

The bigger saving is the course's usual one. A `resend` of the endpoint
(Lab 06), or one read of a `data-*` attribute (Lab 08), replaces dozens of page
verbs.

## 5.12 What went away with the old engine

This course was first written against an h5i that had its own engine and its
own reader verbs. h5i 0.5.0 still shipped them; 0.5.6 does not. For anyone holding an older copy of
these labs:

| old | now | in this course |
| --- | --- | --- |
| `h5i browser extract '{schema}'` | `h5i browser eval '<js>'` | [`bin/extract`](../bin/extract) keeps the schema and runs it through `eval` |
| `h5i browser read URL` | `open` / `navigate`, then `eval` | `extract --url`, `bin/served URL` |
| `--script` | always on | 5.3 |
| `markdown`, `structured` | `snapshot`, or `eval` over `<meta>` / JSON-LD | [`03-cheatsheet.md`](03-cheatsheet.md) |
| `find --role` | `snapshot -i`, then a CSS selector | Lab 05 |
| `submit @ref` | `press Enter`, then read the request log | Lab 05 |
| `caused_requests` on a click | `requests --since SEQ` | Labs 06 and 08 |
| `wait-for` saying "not ever" | a 30 s timeout | 5.7 |

The page-level limits the old engine had (jQuery 1.x, scroll events, the
`href="#"` reload, the allowlist on one-shot reads) belong to that engine, and
none of them reproduce in Chromium. The habit they taught still holds. When a
page seems inert, find out whether the fault is the page's or the tool's before
writing around it. In this version, the place to find out is the request log.

## 5.13 What this is not for

| Situation | Reach for |
| --- | --- |
| tens of thousands of pages | a crawler framework with a scheduler, a store and a politeness policy |
| a site that offers an API or a dump | the API or the dump |
| a site that blocks automation | nothing. A block is an answer. See [`04-etiquette-and-scope.md`](04-etiquette-and-scope.md) |
| reading pages from an untrusted site into an agent | the same, inside an h5i box |
| checking a site's TLS | a client that verifies certificates (5.4) |

What a session buys a scraper is not speed or coverage. It is that the request
log is written by the proxy before the bytes move, so "what did my scraper
actually fetch, and what was refused" has an exact answer, including the
requests your scraper never meant to make. A scraper's commonest failure is
*quietly collecting less than you think*, and that log is what catches it.

## 5.14 If you find a limit this chapter does not list

Reduce it to the smallest page that still shows it. Capture
`h5i browser requests --json`, `h5i browser console` and `h5i browser status`,
and say what you expected, what happened, and what it cost you. Then decide
whose limit it is. Chromium's? agent-browser's? h5i's? The course's helpers'?
Each has its own issue tracker, and the reduction usually says which.

Re-run the probes in this chapter when you upgrade. A limit that goes away
deserves the same reduction as a limit that appears.

Back to [`../README.md`](../README.md).
