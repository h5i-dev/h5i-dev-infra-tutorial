# Lab 05 — writeup

## What the form sent

```
$ h5i browser requests --session lab05 --url-contains '?q='
req_27     GET https://www.scrapethissite.com/pages/forms/?q=New+York
res_27 200 GET https://www.scrapethissite.com/pages/forms/?q=New+York (5239 bytes, 62ms)
```

That row was written by the proxy as the request left. It is what the server
received, which is a stronger statement than what the address bar says
afterwards. `scrape.sh` notes the last `seq` before typing and reads only the
rows after it, so it reads what *this* submission caused and nothing older.

A `GET` form is a URL template with a human-facing wrapper. Once you have seen
one submission, you have the template, and every later search is a string. No
snapshot, no @ref, no typing, no re-render to lose your place in.

Combine it with the pager, whose links read `?page_num=2&q=New+York`, and the
crawl is:

```bash
for n in 1 2 3; do
    extract "$SCHEMA" --url "$TARGET&page_num=$n" --session lab05
done
```

Three requests, no interaction, and it reruns identically tomorrow.

**A `POST` form is not this**, and the difference is worth checking rather than
assuming. The log row will say `POST`, the URL will not carry your input, and
you are back to driving the form each time. Or you `resend` that row with
`--set form.q=…`, which sends the same POST with one field changed. Or you use
the API that form posts to, if there is one.

## @refs, and why the script does not hard-code one

A snapshot line reads:

```
- textbox "Search for Teams: " [ref=e9]
```

`@e9` names an element in **that reading** of the page. This version of h5i
does not check that it still does. After the page navigates, an old `@e9` is
passed to the browser and clicks or types into whatever answers to it now. So
`scrape.sh` takes the ref out of the snapshot it just took, matching on
`- textbox`, rather than assuming the box is still ninth.

The durable alternative is a CSS selector. The search box is
`<input id="q" name="q">`, so `h5i browser type '#q' "New York"` does the same
thing and survives any re-render that keeps the id. Read it off the served body
(`served | grep -n '<input'`) or off the page
(`extract '{"in": [{"selector": "input", "attr": "outerHTML"}]}'`). `#q` is what
to write down if you are keeping this scraper; a @ref is for the next three
commands only.

## Reading the pager instead of guessing at it

`page_num` is not a convention. It is this site's parameter, read off its own
pagination links. Other sites use `page`, `p`, `offset`, `start`, `from`, a
cursor token, or a POST body. Getting it from the markup takes one `extract`:

```bash
extract '{"pager": [{"selector": "ul.pagination a", "attr": "href"}]}' --session lab05
```

The same read gives you the last page number, which is a stop condition that
does not depend on noticing an empty result.

## The rows

`tr.team` is one row, and `scrape.sh` asks for rows with it:
`[{"selector": "tr.team", "fields": {"team": "td.name", …}}]`. The table also
has a header row, which is a `<tr>` without `class="team"`. That is the reason
the row selector is `tr.team` rather than `tr`, and a reminder that "the
table" and "the data" are not the same set of elements.
