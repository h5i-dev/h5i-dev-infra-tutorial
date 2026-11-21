# 5. Where the tool ends

Every instrument has a shape, and knowing yours is part of testing honestly.
**A payload that fails in h5i has not necessarily failed in the world**, and a
report that does not distinguish the two is wrong.

This chapter is what this book found while building 42 labs.

---

## 5.1 The browser is real; the boundary is the proxy

A session is a real Chromium, driven by agent-browser, behind h5i's capture
proxy. So the page side behaves the way any browser would: `<script>`,
`<img onerror>`, `<svg onload>`, forms, `fetch` with credentials, event
handlers, Canvas, Workers, the single-page-application APIs. If a payload runs
in Chrome, it runs here. The limits worth knowing are not DOM gaps; they are the
proxy and its policy, which is the whole point of the tool.

* **An origin the session did not grant is refused**, and the refusal is
  recorded. `h5i websec requests --denied-only` is how you notice your payload
  never left the browser. Grant a second service or your collector with
  `--allow ORIGIN`.
* **Chromium makes requests of its own** (update checks, which the policy
  refuses, and `/favicon.ico`), so message ids are not numbered from 0. Find the
  one you want by path, not by guessing a number.
* **The page runs real code, so prove the sink when a payload is quiet.** A
  `<script>fetch('/collect?c=alive')</script>` that lands tells you the
  injection point works and the problem is your selector, not the target. The
  difference between "no XSS" and "wrong payload" is an hour.

---

## 5.2 URL parsing happens before the request exists

A parsed URL percent-decodes and resolves `.` and `..` before there is a request
to send. That is true of every HTTP client, not just this one, and it destroys
any payload whose *encoding* is the exploit:

```bash
--set query.file=%252e%252e%252f…     # arrives as %2e%2e%2f — not the payload
--raw-target '/download?file=%252e%252e%252f…'   # arrives as written
```

`--raw-target` for the request-target, `--raw-request` for the whole message
(Labs 27, 30, 38). When a payload behaves oddly, `websec show req_N --raw` says
what actually left.

---

## 5.3 Timing has a floor

A replay measures the whole send, so scheduling and connection setup land on top
of the server's own time. That noise is one-directional: it can make a fast
answer look slow, never a slow answer look fast.

So the rule in Lab 14: **trust every "fast", confirm every "slow"**. The
confirmation is nearly free because the answer it confirms is the fast one. Use
`--repeat N` and read the **median and MAD** rather than one sample, and read
`samples[].total_ms` rather than wrapping the CLI in `time` — process startup is
tens of milliseconds of noise on a signal you are reading at hundreds.

---

## 5.4 The budget is a real constraint

Each page has a bounded network allowance. It exists to contain page code; a
deliberate sweep is the opposite of what it was built for. Without
`--reset-budget`, a long loop stops partway and every later probe reads as a
negative result — which in a blind extraction does not look like an error, it
looks like the secret ending.

**Any loop of more than a handful of replays takes `--reset-budget`.**

---

## 5.5 What h5i does not do at all

By design, and stated in its own documentation:

* **It does not find vulnerabilities.** No scanner, no payload generation, no
  wordlists, no verdicts. It owns the deterministic half — exact capture, stable
  ids, structured edit, resend, diff, timing, scope, audit — and you own the
  judgement half: which request matters, which parameter to bend, what a
  difference means, what to try next. This book is training for that half.
* **It is not a content filter.** It bounds what a persuaded agent can reach; it
  does not classify what a page says.
* **It is not sandboxed by default.** agent-browser and its Chromium run as
  ordinary host processes, and `h5i browser status` says so on every line.
  Containment is a separate choice (`h5i env`), not something a browser session
  turns on for you.

---

## 5.6 When to reach for something else

| Situation | Tool |
| --- | --- |
| a heavy SPA that will not render | Chromium inside an h5i sandbox, or Playwright |
| interactive, exploratory manual work on one request | Burp Suite Repeater |
| large-scale automated scanning | a scanner; that is not what this is |
| protocol work below HTTP/1.1 semantics | raw sockets, `openssl s_client` |
| HTTP/2-specific desync | a client that speaks h2 frames directly |
| single-packet race attacks (microsecond windows) | Turbo Intruder or an equivalent |
| fuzzing binary protocols | a fuzzer |

None of that is a criticism. It is the same judgement as choosing a wrench: the
useful skill is knowing which one is in your hand.

---

## 5.7 If you find a limit this chapter does not list

That is a contribution. Building these labs is what turned up the gaps that got
filed, and some of them became features (`websec socket` exists because a lab
needed it).

A good report of a tool limit looks like a good report of a vulnerability: what
you expected, what happened, the smallest reproduction, and what it cost you.
File it at [github.com/h5i-dev/h5i](https://github.com/h5i-dev/h5i/issues) in
that shape.
