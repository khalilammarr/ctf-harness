#!/usr/bin/env bash
# Smoke test for bin/board and bin/submit-flag. No network, no CTFd.
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export CTF_BOARD_DIR="$T/board"
. "$HERE/env.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

WHO=a board claim web1 a >/dev/null
if WHO=b board claim web1 b >/dev/null 2>&1; then fail "second claim on a held challenge succeeded"; fi

# Two simultaneous claims on a fresh challenge: exactly one may win.
( WHO=c board claim web2 c >"$T/c.out" 2>&1 || true ) &
( WHO=d board claim web2 d >"$T/d.out" 2>&1 || true ) &
wait
wins=$(grep -l '^claimed' "$T/c.out" "$T/d.out" | wc -l)
[ "$wins" -eq 1 ] || fail "expected exactly one winner of a concurrent claim, got $wins"

WHO=a board kill web1 "sqli does not work" >/dev/null
board tried web1 | grep -q "sqli does not work" || fail "dead end not listed"

board flag web1 'flag{example}' >/dev/null
board status | grep -q '^\[SOLVED\] web1' || fail "flag did not mark challenge solved"

# submit-flag must refuse to resubmit a solved challenge, without touching the network.
submit-flag web1 1 'flag{example}' | grep -q '^SKIP' || fail "submit-flag resubmitted a solved challenge"

echo "ok"
