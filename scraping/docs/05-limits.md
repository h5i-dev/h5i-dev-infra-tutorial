# 5. Where the reader ends

A page that comes back empty in h5i is not necessarily an empty page, and a
scraper that cannot tell those apart will eventually report the wrong thing
confidently. This chapter is what this course found while running its ten labs
against h5i's current sessions: a capture proxy in front of a real Chromium.
Each item is reduced to the smallest command that still shows it.

**A limit is a fact about a version, not about a tool.** An earlier edition of
this chapter described h5i's own browser engine: `extract` returning columns,
jQuery 1.x failing to initialise, a `scroll` that dispatched no event. That
engine is gone (h5i [#744](https://github.com/h5i-dev/h5i/pull/744)), and every
one of those limits went with it, because Chromium is the browser. What
replaced them is below.

| | Limit | What to do |
| --- | --- | --- |
| [5.1](#51-you-need-a-chromium) | a session needs Node.js, agent-browser and a Chromium | install them once; one env var on Linux arm64 |
| [5.2](#52-the-log-has-traffic-you-did-not-cause) | Chromium's background traffic is in the log, and takes request ids | filter by URL; never hard-code an id |
| [5.3](#53-every-row-says-subresource) | the page and its subresources carry the same label | the page is the response for the URL you opened |
| [5.4](#54-a-click-says-done-and-nothing-else) | a click's reply does not say what it caused | read `requests --since` and the DOM |
| [5.5](#55-wait-for-cannot-say-never) | `wait-for` waits 30 seconds, then fails | poll with `js` when you know the delay |
| [5.6](#56-read-the-log-before-you-close) | a closed session's request log is not listable | read what you need before `close` |
| [5.7](#57-the-reads-that-went-away) | no one-shot `read`, no `extract`, `markdown` or `structured` | `lib/h5i.sh`, and the response |
| [5.8](#58-what-this-is-not-for) | what a scraping session is not for | unchanged, and not a defect |

---

## 5.1 You need a Chromium

A session is h5i's proxy plus a Chromium driven by
[agent-browser](https://www.npmjs.com/package/agent-browser). h5i does not
bundle either:

```bash
npm install -g agent-browser     # needs Node.js
agent-browser install            # downloads a Chromium for it to drive
```

On Linux arm64 there is no Chromium for `agent-browser install` to download.
Point it at one you already have, for example Playwright's:

```bash
export AGENT_BROWSER_EXECUTABLE_PATH=~/.cache/ms-playwright/chromium-*/chrome-linux-arm64/chrome
```

When agent-browser is missing, `h5i browser open` says so and names Node.js.
That is the whole failure: no session is left behind.

## 5.2 The log has traffic you did not cause

```
—          DENIED GET http://clients2.google.com/time/1/current?… — origin
           `http://clients2.google.com` is not in the allowlist
—          DENIED POST https://update.googleapis.com/service/update2/json?… — …
req_3             GET https://books.toscrape.com/
```

Chromium checks for updates, probes for a signed-in account and fetches a
spelling dictionary on its own. All of it goes through the proxy, and the
session's policy refuses it like any other origin it was not granted. That is
correct, and it is noise in two ways.

**Request ids are not predictable.** The page you opened was `req_3` above, and
`favicon.ico` takes another id after it. The next run can differ. Find an id
by URL, `h5i browser requests --url-contains /js/ --json`, and never write a
`req_N` into a script. `lib/h5i.sh`'s `response` does the lookup.

**A refusal is not necessarily the page's.** Lab 04 separates them by asking
the captured response which origins the page mentions. On its page that was
ten refused origins the page named and six that were Chromium's own.

## 5.3 Every row says `subresource`

```bash
h5i browser requests --session s --json | python3 -c \
  'import json,sys; print({r["initiator"] for r in json.load(sys.stdin)["requests"]})'
# {'subresource'}
```

The proxy sees Chromium's requests, not why Chromium made them, so the top-level
document and its stylesheets carry the same label. `--initiator navigation` on
`h5i websec requests` is still accepted and matches nothing. To count pages,
count responses whose URL is one you navigated to (Lab 04).

## 5.4 A click says `Done` and nothing else

```
$ h5i browser click @e3 --session s --json
{"ok": true, "session": "br_…", "verb": "click", "output": "✓ Done\n", …}
```

The reply does not list the requests the click caused, and does not say
whether the page went quiet. Dispatched is all it means. To find out what a
gesture did, take the log's cursor before it and read after it:

```bash
before=$(h5i browser requests --session s --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["cursor"])')
h5i browser click @e3 --session s
h5i browser requests --session s --since "$before"
```

Lab 08 does this around its scrolls and finds that they fetched nothing.

## 5.5 `wait-for` cannot say never

```
$ h5i browser wait-for --selector tr.nope --session s
Error: agent-browser wait failed for session br_…: ⚠ --args, --proxy,
--ignore-https-errors ignored: daemon already running. Use 'agent-browser close'
first to restart with new options.
✗ Wait timed out after 30000ms
```

Two things in that answer. The useful one is the last line: thirty seconds,
then failure, whether the element was about to arrive or never could. A page
whose script never loaded costs you the full thirty. When you know how long a
page takes (Lab 06's site delays 1.5 seconds on purpose), poll with `js` for
that long instead.

The other is the warning above it, which is agent-browser's and is harmless:
the session's Chromium is already running with the flags h5i gave it. It is
printed on every failing page verb, so read past it to the line that starts
with `✗`.

## 5.6 Read the log before you close

```
$ h5i browser requests --session br_deajun
browser session `br_deajun` was closed: closed by the user. It will not be
restarted automatically.
```

`close` keeps the session's record, and `h5i browser audit`, `status` and
`h5i websec show res_N` still answer for it. `h5i browser requests` and
`h5i websec requests` do not, so the id lookup that `response` does needs a live
session. A scraper that wants to count or attribute its requests does it while
the session is open, which is what Lab 04 does, before the `EXIT` trap in
`lib/h5i.sh` closes it.

## 5.7 The reads that went away

h5i used to answer `read URL` with no session, and had `extract`, `markdown`,
`structured`, `find` and `submit` as verbs of its own engine. They went with
the engine. What this course uses instead:

| Was | Now |
| --- | --- |
| `read URL --text` | `open`, then `js 'document.body.innerText'`, or `response URL` for the bytes |
| `extract '{…}'` | `extract '{…}'`, the same schema, from `lib/h5i.sh` |
| `markdown` | `snapshot` |
| `structured` | `response URL`, and grep for `ld+json`, `og:`, `itemprop` |
| `find --role textbox` | `snapshot -i`, then a CSS selector you choose |
| `submit @e9` | `type`, `press Enter`, then `js 'location.href'` |
| `--script` | nothing: JavaScript always runs |
| a local `./saved.html` | `response URL > saved.html`, and parse the file; sessions refuse `file:` URLs |

`lib/h5i.sh`'s `extract` runs in the page through `h5i browser eval`, so it
sees the DOM after the page's scripts ran. Its text values are `textContent`
with whitespace collapsed. When the server's bytes are what you want, that is
`response`, not `extract`.

`h5i browser eval --json` on a script that throws prints the error on stderr
and nothing on stdout, not a JSON envelope with `"ok": false`. `js` in
`lib/h5i.sh` treats empty output as failure for that reason.

## 5.8 What this is not for

| Situation | Reach for |
| --- | --- |
| tens of thousands of pages | a crawler framework with a scheduler and a store |
| a site that offers an API or a dump | the API or the dump |
| a site behind bot protection that does not want you | nothing. That is the site telling you no |
| a site that has told you to stop | nothing. See [`04-etiquette-and-scope.md`](04-etiquette-and-scope.md) |

A heavy single-page app is no longer on this list: the session is Chromium,
and it renders what your own browser renders. What a session costs is a
browser per scrape, about a second to open, which is fine for the ten sites
here and wrong for a crawl of a million pages.

The strength of h5i for scraping is not coverage. It is that the request log is
written before the bytes move and every response is kept, so every question of
the form "what did my scraper actually fetch, what did the server actually
send, and what was refused" has an exact answer. For a job whose commonest
failure is *quietly collecting less than you think*, that is the property worth
having.

## 5.9 If you find a limit this chapter does not list

Reduce it to the smallest page that still shows it. Capture what the server
sent (`response`), what the page built (`js`, `snapshot`), what was fetched
and refused (`requests`), and what the page logged (`h5i browser console`).
Say what you expected, what happened, and what it cost you.

That is not a formality. The first edition of this chapter filed its limits
that way, and five of the six were fixed in the engine. **A limit
that goes away deserves the same reduction as a limit that appears**, which is
why this edition was written by running every lab again rather than by editing
the old one.

Back to [`../README.md`](../README.md).
