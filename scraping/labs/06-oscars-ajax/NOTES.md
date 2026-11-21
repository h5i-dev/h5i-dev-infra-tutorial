# Lab 06 — writeup

## Failure one: the allowlist

```
DENIED GET https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js
       — origin `https://ajax.googleapis.com` is not in the allowlist
```

A session grants the origin of the URL you opened, and nothing else. In Lab 04
that cost a webfont, which nobody wanted. Here it costs the library the entire
page is written in, and the symptom is not an error. It is a page that renders
its year links and then does nothing when you use them:

```
$ js 'typeof window.jQuery' --session lab06
"undefined"
```

```bash
h5i browser open … --allow https://ajax.googleapis.com
```

**This is the first thing to check whenever a page behaves as though it has no
behaviour.** The request log names the refusal and its reason, and it is
written before the bytes move, so a request that is not in the log did not
happen. There is no ambiguity to reason around: read it.

The same log has DENIED rows you did not cause: `update.googleapis.com`,
`accounts.google.com`, `clients2.google.com`. That is Chromium's own background
traffic, refused by the same policy. Lab 04 shows how to tell the two apart:
the page's refusals are origins its own response mentions.

## The click, and what it proves

With jQuery allowed:

```
# jQuery in the page: "function"
# films after the click: 16
# the data is one GET: https://www.scrapethissite.com/pages/ajax-javascript/?ajax=true&year=2015
```

`{"ok": true}` on a click means the click was dispatched, not that anything
happened as a result. Without `--allow` the click answers exactly the same and
nothing listens to it. What happened next is in two places: the DOM, which now
has sixteen `tr.film` rows, and the request log, which has the call the
handler made:

```
req_26        GET https://www.scrapethissite.com/pages/ajax-javascript/?ajax=true&year=2015
res_26    200 GET https://www.scrapethissite.com/pages/ajax-javascript/?ajax=true&year=2015 (340 bytes, 77ms)
```

The id is different every run. Find it by URL, never by number.

**One case is worth staring at, though this page does not show it**: a fetch in the log and nothing
on screen. That is always a rendering or navigation question (a handler that
threw while drawing, a link that navigated over the table), never a "the site
has no data" question. The log and the DOM disagree, and the log is the one
that was written before anything could go wrong.

On waiting: the site delays the table by 1.5 seconds on purpose. `h5i browser
wait-for --selector tr.film` waits for it, but gives up only after 30 seconds,
and a click that fired nothing makes you sit through all of them. The scraper
polls for five seconds instead, which is enough for a click that worked.

## Finding the request without clicking

The handler is in the response the server sent, and a response is something
you can read without running anything. This is the route that works on a page
whose interaction you cannot reproduce, and on a page you would rather not
execute at all:

```bash
response pages/ajax-javascript/ --session lab06 | grep -A8 'ajax('
```

```js
$.ajax({
    method: "GET",
    url: document.location.pathname,
    data: { ajax: true, year: year },
    success: function(data){ setTimeout(function(){ showFilms(data); }, 1500); }
});
```

That is the whole answer:

```
GET https://www.scrapethissite.com/pages/ajax-javascript/?ajax=true&year=2015
```

It returns JSON (typed numbers, a `best_picture` boolean, no markup to parse)
and costs one request per year. The scraper takes this route when the click
fetched nothing; run it without `--allow` to watch it happen.

## The point

The endpoint is the better target **even when the click works**. It is fewer
requests, no rendering, no 1.5-second artificial delay, no dependence on a
third-party CDN, and it returns data that is already typed. Driving the UI to
produce data the server was willing to hand over directly is the most common
way a scraper ends up slow and fragile at the same time.

And because h5i keeps every response, the click's own call is already
captured: the scraper reads the JSON body with `response` and makes no second
request for it.

The general move, in order:

| | |
| --- | --- |
| 1 | Click it once, and read `h5i browser requests` for what the click fetched. |
| 2 | If nothing was fetched, read the page's `<script>` in the response for the URL it would have fetched. |
| 3 | Call that URL directly, and check the shape of what comes back. |
| 4 | Only then consider whether you needed a browser at all. |

Step 1 answers in five seconds wherever the click works. Step 2 is what you
need on any page whose interaction you cannot reproduce: a hover, a drag, a
widget behind a login you would rather not automate. Knowing both is the
point; one of them is always available.

## Where this stops being reasonable

An endpoint you found in a page's source is still the site's endpoint, subject
to the same terms as the page. Finding it does not make it public and does not
raise your rate limit. This one belongs to a site that published a lesson
telling you to find it, which is not the general case.
[`../../docs/04-etiquette-and-scope.md`](../../docs/04-etiquette-and-scope.md)
applies exactly as much to a JSON endpoint as to an HTML page.
