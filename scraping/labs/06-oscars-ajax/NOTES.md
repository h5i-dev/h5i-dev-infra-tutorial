# Lab 06 — writeup

## Step one: a page that does nothing, and says nothing

Without `--allow`, everything the page can tell you is a shrug:

```
$ h5i browser eval 'typeof window.jQuery'
"undefined"
$ h5i browser console
                                     (nothing)
$ h5i browser click '[id="2015"]'
✓ Done
$ h5i browser eval 'location.href + " films=" + document.querySelectorAll("tr.film").length'
"https://www.scrapethissite.com/pages/ajax-javascript/# films=0"
$ h5i browser wait-for --selector tr.film
✗ Wait timed out after 30000ms
```

The click "worked": it followed `href="#"`, because no handler was bound to
stop it. `wait-for` spent thirty seconds finding out that nothing was coming.
From inside the page, "the library never loaded" and "the site has no films
this year" are the same observation.

The proxy knows the difference, and wrote it down before the request could
leave:

```
$ h5i browser requests --denied-only
—   DENIED GET https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js
        — origin `https://ajax.googleapis.com` is not in the allowlist
```

A session grants the origin of the URL you opened, and nothing else. In Lab 04
that cost a webfont, which nobody wanted. Here it costs the library the entire
page is written in. **This is the first thing to check whenever a page behaves
as though it has no behaviour**, because it is the one place the refusal is
recorded. See
[`../../docs/05-limits.md`](../../docs/05-limits.md#52-a-refusal-is-invisible-from-inside-the-page).

The fix is to grant it when the session opens. A session's policy is fixed when
its proxy starts, so this means a new session:

```bash
h5i browser open … --session lab06 --new --allow https://ajax.googleapis.com
```

## Step two: the click, once, and what it sent

With jQuery allowed, the same commands read differently:

```
$ h5i browser eval 'typeof window.jQuery'
"function"
$ h5i browser click '[id="2015"]'
✓ Done
$ h5i browser wait-for --selector tr.film
✓ Done                                            # about 1.6 s: the site's 1.5 s delay
$ h5i browser eval 'document.querySelectorAll("tr.film").length'
16
```

`✓ Done` from the click means the click was dispatched. Whether anything
happened is in the log, and `scrape.sh` reads only what came after the click
by noting the last `seq` first:

```
$ h5i browser requests --since 24
req_25     GET https://www.scrapethissite.com/pages/ajax-javascript/?ajax=true&year=2015
res_25 200 GET https://www.scrapethissite.com/pages/ajax-javascript/?ajax=true&year=2015 (340 bytes, 75ms)
```

That is the URL this lab exists to find. The page's own code built it. The
proxy recorded it with its headers and cookies, and gave it the number 25.

(`[id="2015"]` rather than `#2015`: the year links have numeric ids, and a CSS
id selector may not start with a digit. `click '#2015'` answers *Element not
found*, which is true and unhelpful.)

## Step three: stop clicking

```bash
h5i browser resend 25 --set query.year=2014 --session lab06 --json
```

```json
{"ok": true, "seq": 31, "request_id": "req_31",
 "applied": [...],
 "response": {"status": 200, "bytes": 1546, "body_truncated": false,
              "headers": [["content-type", "application/json"], …],
              "body_preview": "[{\"title\": \"Birdman\", \"year\": 2014, \"awards\": 4, …"}}
```

`resend` sends request 25 again with one part changed, through the same proxy
and the same allowlist, and answers with the response. The replay is itself a
new row in the log (seq 31), so it can be replayed too. What comes back is
JSON, with typed numbers and a `best_picture` boolean. It needs no rendering,
no click and no 1.5-second delay, and costs one request per year.

Two things to check on every answer, and `scrape.sh` checks both:

* `response.status` is `200`;
* `response.body_truncated` is `false`. `resend` answers with a preview of at
  most 4 KiB. A year here is about 1.5 KB. A bigger endpoint needs `served URL`,
  which reads the whole body from inside the page.

## Finding the request without clicking

The handler is in the page's markup, and markup is something you can read
without trusting anything to run. This is the route for a page whose
interaction you cannot reproduce (a hover, a drag, a widget behind a login you
would rather not automate):

```bash
served --session lab06 | grep -n -A15 '\$.ajax'
```

```js
$.ajax({
    method: "GET",
    url: document.location.pathname,
    data: {
        ajax: true,
        year: year
    },
    success: function(data){
        setTimeout( function(){
            showFilms(data);
        }, 1500);  // add intentional delay to emphasize async UI
    },
    …
});
```

That is the whole answer, read from the body the server sent:

```
GET https://www.scrapethissite.com/pages/ajax-javascript/?ajax=true&year=2015
```

`served 'https://www.scrapethissite.com/pages/ajax-javascript/?ajax=true&year=2015'`
reads it directly. That works even with jQuery refused, because the fetch comes
from the page's own origin.

## The point

The endpoint is the better target **even though the click works**. It is fewer
requests, no rendering, no artificial delay, no dependence on a third-party
CDN, and it returns data that is already typed. Driving the UI to produce data
the server was willing to hand over directly is the most common way a scraper
ends up slow and fragile at the same time.

The general move, in order:

| | |
| --- | --- |
| 1 | If the page seems inert, read `requests --denied-only` before anything else. |
| 2 | Note the last `seq`, act once, and read `requests --since` for what the action sent. |
| 3 | If it sent nothing, read the served `<script>` for the request it would have sent. |
| 4 | Call that request directly: `resend SEQ --set …`, or `served URL`. |
| 5 | Only then consider whether you needed a browser at all. |

## Where this stops being reasonable

An endpoint you found in a page's source is still the site's endpoint, subject
to the same terms as the page. Finding it does not make it public and does not
raise your rate limit. This one belongs to a site that published a lesson
telling you to find it, which is not the general case.
[`../../docs/04-etiquette-and-scope.md`](../../docs/04-etiquette-and-scope.md)
applies exactly as much to a JSON endpoint as to an HTML page.
