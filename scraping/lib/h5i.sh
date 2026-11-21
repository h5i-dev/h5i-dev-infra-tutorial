# Shared helpers for every `scrape.sh`. Source it; do not run it.
#
# Seven functions and one variable. Each is here because of a seam in the tool
# or a courtesy owed to the site, not because the labs have anything in common.
#
#   session   open a named session and close it however the script ends. A
#             leaked session is a live proxy and a live Chromium, and enough of
#             them make `h5i browser list` unreadable.
#   extract   named fields by CSS selector, as one JSON object. h5i dropped its
#             own `extract` verb with its own engine; this is the same schema,
#             run in Chromium through `browser eval`.
#   js        evaluate an expression in the page and print its result as JSON.
#   response  the body of a captured response, exactly as the server sent it,
#             before any script ran. Needs the websec plugin.
#   pace      sleep between requests. The whole course is ten sites and about
#             thirty pages; none of it needs to be fast, and a scraper with no
#             floor on its request rate is the one that gets an IP blocked.
#   rows      `lib/rows.py` under whichever python is here.
#   need      fail with a sentence rather than at the first confusing empty
#             result.

H5I="${H5I:-h5i}"
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Seconds between requests, for every lab. Raise it, never lower it below the
# default without a reason you would be willing to write in a mail to the site.
PACE="${PACE:-1}"

need() {
    if ! "$H5I" browser --help >/dev/null 2>&1; then
        echo "This course needs h5i on your PATH, or H5I= pointed at a build." >&2
        echo "  curl -fsSL https://h5i.dev/install.sh | sh" >&2
        echo "  or: H5I=~/src/h5i/target/release/h5i ./run.sh 01" >&2
        exit 2
    fi
}

# session NAME URL [open flags...] — open it, and close it on the way out.
#
# Every remote origin except the URL's own is refused by this session, and the
# refusal is written to `h5i browser requests` with its reason. That is the
# behaviour, not a misconfiguration: a page that pulls a script from a CDN
# needs that CDN named with `--allow`, and lab 06 is the one where it matters.
# Chromium's own background traffic (update checks, sign-in pings) is refused
# the same way, so expect DENIED rows you did not cause.
session() {
    need
    SESSION="$1"; shift
    local url="$1"; shift
    "$H5I" browser close --session "$SESSION" >/dev/null 2>&1 || true
    trap '"$H5I" browser close --session "$SESSION" >/dev/null 2>&1 || true' EXIT
    "$H5I" browser open "$url" --session "$SESSION" --new "$@" >/dev/null
}

pace() { sleep "$PACE"; }

rows() { python3 "$LIB/rows.py" "$@"; }

# js EXPR [--session S] -> the value of EXPR, as one line of JSON on stdout.
js() {
    local expr="$1"; shift
    local s="${SESSION:-}"
    while [ $# -gt 0 ]; do
        case "$1" in
            --session) s="$2"; shift 2 ;;
            *) echo "js: unknown flag $1" >&2; return 2 ;;
        esac
    done
    "$H5I" browser eval "$expr" ${s:+--session "$s"} --json | python3 -c '
import json, sys
raw = sys.stdin.read()
if not raw.strip():
    sys.exit(1)   # h5i has already said why, on stderr
reply = json.loads(raw)
if not reply.get("ok"):
    sys.exit("js: eval failed: %s" % json.dumps(reply)[:400])
print(json.dumps(json.loads(reply["output"]), ensure_ascii=False))'
}

# response URL_CONTAINS [--session S] -> the body of the newest captured
# response whose URL contains the text. Request ids are not sequential (the
# browser's own traffic takes some), so look them up; never hard-code one.
response() {
    local want="$1"; shift
    local s="${SESSION:-}"
    [ "${1:-}" = "--session" ] && s="$2"
    if ! "$H5I" websec --help >/dev/null 2>&1; then
        echo "response: needs the websec plugin (install.sh --websec)" >&2
        return 2
    fi
    local id
    id="$("$H5I" browser requests ${s:+--session "$s"} --url-contains "$want" --json | python3 -c '
import json, sys
rows = [r for r in json.load(sys.stdin)["requests"]
        if r["phase"] == "response" and r.get("id") and r.get("status")]
print(rows[-1]["id"] if rows else "")')"
    [ -n "$id" ] || { echo "response: nothing captured matching $want" >&2; return 1; }
    "$H5I" websec show "$id" ${s:+--session "$s"} --body-to -
}

# extract SPEC [--url URL] [--session S]. The schema h5i's old `extract` verb
# took, unchanged; docs/01-the-reader.md has the forms. Exits non-zero when no
# top-level key matched anything, because an object of nulls looks like an answer.
EXTRACT_JS='
(spec) => {
  const clean = (s) => s == null ? null : s.replace(/\s+/g, " ").trim();
  const all = (root, sel) => sel === ":scope" ? [root] : Array.from(root.querySelectorAll(sel));
  const attr = (el, name) => {
    const raw = el.getAttribute(name);
    if (raw == null) return null;
    if (name !== "href" && name !== "src") return raw;
    try { return new URL(raw, document.baseURI).href; } catch (e) { return raw; }
  };
  const read = (root, v) => {
    if (typeof v === "string") { const m = all(root, v)[0]; return m ? clean(m.textContent) : null; }
    if (Array.isArray(v)) {
      const it = v[0];
      if (typeof it === "string") return all(root, it).map((e) => clean(e.textContent));
      let ms = all(root, it.selector);
      if (it.limit != null) ms = ms.slice(0, it.limit);
      if (it.attr) return ms.map((e) => attr(e, it.attr));
      return ms.map((e) => fields(e, it.fields));
    }
    const m = all(root, v.selector)[0];
    return m ? attr(m, v.attr) : null;
  };
  const fields = (root, f) => Object.fromEntries(Object.entries(f).map(([k, v]) => [k, read(root, v)]));
  return fields(document, spec);
}'

extract() {
    local spec="$1"; shift
    local s="${SESSION:-}" url=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --url) url="$2"; shift 2 ;;
            --session) s="$2"; shift 2 ;;
            *) echo "extract: unknown flag $1" >&2; return 2 ;;
        esac
    done
    # Refuse a bad schema here, with the key named, rather than as a JS error.
    python3 -c '
import json, sys
def check(name, v):
    if isinstance(v, str): return
    if isinstance(v, dict):
        if not (v.get("selector") and v.get("attr")):
            sys.exit("extract: `%s` is an object, so it needs a `selector` and an `attr`" % name)
        return
    if isinstance(v, list) and len(v) == 1:
        it = v[0]
        if isinstance(it, str): return
        if isinstance(it, dict) and it.get("selector"):
            if it.get("attr"): return
            if isinstance(it.get("fields"), dict):
                for k, sub in it["fields"].items(): check(k, sub)
                return
            sys.exit("extract: `%s[0]` needs `attr` or `fields`" % name)
    sys.exit("extract: `%s` should be a selector, a one-entry array, or an object spec" % name)
try:
    spec = json.loads(sys.argv[1])
except ValueError as exc:
    sys.exit("extract: the schema is not JSON: %s" % exc)
if not isinstance(spec, dict) or not spec:
    sys.exit("extract: the schema is an object of field names to selectors")
for k, v in spec.items(): check(k, v)' "$spec" || return 2
    if [ -n "$url" ]; then
        "$H5I" browser navigate "$url" ${s:+--session "$s"} --json >/dev/null || return 1
    fi
    js "($EXTRACT_JS)($spec)" ${s:+--session "$s"} | python3 -c '
import json, sys
raw = sys.stdin.read()
if not raw.strip():
    sys.exit(1)   # the eval failed, and said why
answer = json.loads(raw)
if all(v is None for v in answer.values()):
    sys.exit("extract: no selector in this schema matched anything on the page. "
             "Look at what is there with `h5i browser snapshot`, then fix the selectors.")
print(json.dumps(answer, ensure_ascii=False))'
}
