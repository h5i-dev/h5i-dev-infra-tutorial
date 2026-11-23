# h5i — tutorial

[h5i](https://github.com/h5i-dev/h5i) is an Axum-based Rust web framework whose
application kernels can be formally verified with Lean 4. Alongside the
framework it ships development infrastructure: browser sessions that capture
their own traffic, an HTTP workbench for red-teaming, security regression tests,
and sandboxes for AI agents.

This repository covers **only that infrastructure**. Neither course uses
`h5i-app` or Lean, and you need neither to follow them. The parts the courses
use are framework-independent, so they work against any web application.

Both courses rely on one feature of an h5i browser session. h5i doesn't ship its
own browser. A session is Chromium, driven by
[agent-browser](https://www.npmjs.com/package/agent-browser) and pointed at a
capture proxy that h5i runs for that session. Every request the page made, and
every response, is kept with a stable id. You can list it, read it, and replay
it later.

One course uses that record to bend requests. The other uses it to read pages.
They share the tool and one habit, *know exactly what you sent and what came
back*, and nothing else. Start with either.

| | | |
| --- | --- | --- |
| **[`websec/`](websec/)** | 42 labs, 5 chapters | Web application security, using `h5i browser` and the `websec` plugin. Every target is a small, deliberately vulnerable app that runs on `127.0.0.1` and ships in this repository. IDOR, injection, SSRF, smuggling, races, and a five-step chain as the final exam. |
| **[`scraping/`](scraping/)** | 10 labs, 5 chapters | Web scraping, using `h5i browser` only. Every target is a public sandbox its operator published to be scraped. Pagination, forms, AJAX, infinite scroll, and the argument that you should find the data before writing a selector. |

```bash
cd websec   && ./solve.sh 01     # start a lab, run its proof of concept, check the flag
cd scraping && ./run.sh   01 -   # run a scraper, print the CSV
```

Both need **Python 3.11+**, the `h5i` CLI, and agent-browser for the Chromium
side of a session. `websec` also needs the `websec` plugin. Each course's
README has its own setup section.

```bash
curl -fsSL https://h5i.dev/install.sh | sh -s -- --websec      # h5i and the websec plugin
npm install -g agent-browser && agent-browser install         # Chromium for h5i browser sessions
```

If you came for the framework itself (`h5i app new`, `extract`, `prove`), this
isn't the place. Start with the
[`h5i-app` README](https://github.com/h5i-dev/h5i/blob/main/crates/h5i-app/README.md).

---

## Which one first

**`websec/`** if you want to learn to test applications. It's the longer
course, each lab assumes you've done the one before, and it needs no network
because every target is in the repository.

**`scraping/`** if you want to get data out of pages. It's shorter and stands
alone. It runs against ten real sites, so it needs the network, and it only
touches hosts that asked to be scraped.

---

## The line between them

`websec/` attacks. Every one of its targets binds `127.0.0.1` and ships here, on
purpose. What you learn there applies to systems you own or have written
authorisation to test, and to nothing else.

`scraping/` touches real hosts, so it only touches hosts whose operators
published them for exactly this. Each lab quotes the site saying so, fetches two
or three pages, and paces itself.

The rule underneath is the same: **the target's consent is what makes the
difference, and knowing you have it is your job.** See
[`websec/docs/04-reporting-and-scope.md`](websec/docs/04-reporting-and-scope.md)
and [`scraping/docs/04-etiquette-and-scope.md`](scraping/docs/04-etiquette-and-scope.md).

---

Apache-2.0, like h5i.
