# Lab 05 — writeup

## What the form says, and where it lands

```
# the form: [{"action": "https://www.scrapethissite.com/pages/forms/", "fields": ["q"], "method": "get"}]
# the form is a GET: https://www.scrapethissite.com/pages/forms/?q=New+York
```

The first line is the DOM's own account of the form, read with `js` before
anything is typed: its method, where it submits, and the names of its fields.
The second is `location.href` after one search, typed and submitted with Enter
the way a person would. They agree, which is the point of doing both.

A `GET` form is a URL template with a human-facing wrapper. Once you have seen
one submission, you have the template, and every later search is a string —
no snapshot, no @ref, no typing, no re-render to lose your place in.

Combine it with the pager, whose links read `?page_num=2&q=New+York`, and the
crawl is:

```bash
for n in 1 2 3; do
    extract "$SCHEMA" --url "$TARGET&page_num=$n" --session lab05
done
```

Three requests, no interaction, and it reruns identically tomorrow.

**A `POST` form is not this**, and the difference is worth checking rather than
assuming: the form will say `"method": "post"`, the URL will not carry your
input, and you are back to driving the form each time, or to the API that form
posts to, if there is one. `h5i browser requests` shows the POST and its body
either way.

## @refs, and why the script does not hard-code one

A snapshot line reads:

```
- textbox "Search for Teams: " [ref=e9]
```

`@e9` is valid for **that reading**. The next snapshot numbers the page again,
and the same box may get a different handle. So `scrape.sh` takes the ref out
of the snapshot it just took, matching on `- textbox`, rather than assuming the
box is still ninth.

The durable alternative is a CSS selector. Every page verb that takes a `@ref`
takes one too, and the form read above already named the field:

```bash
h5i browser type 'input[name=q]' "New York" --session lab05
```

`input[name=q]` is what to write down if you are keeping this scraper. The
field's `name` is what the server reads, so it is the last thing a redesign
changes. A @ref is for the next three commands only.

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

`tr.team` is one row and every column is anchored to it. The table also has a
header row, which is a `<tr>` without `class="team"` — the reason the selector
is `tr.team td.name` rather than `td.name`, and a reminder that "the table" and
"the data" are not the same set of elements.
