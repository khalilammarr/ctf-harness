# ctf-harness

Shell and Python glue I used to run several solver processes in parallel against one CTFd instance during CSAW CTF 2026 qualifiers: a shared board so they don't duplicate work, a CTFd API client, a serialized flag-submission wrapper, and a first-look triage script.

The solvers themselves were AI coding agents (several sessions running side by side, each in its own terminal tab). This repository is the plumbing around them, not the agents and not any challenge solutions. I wrote up what it was like to play this way, and what it made me doubt about online CTFs, here: https://khalilammar.me/writeups/csaw-four-minutes-thirty-two-seconds

## What is here

```
bin/board         shared state for parallel solvers (append-only JSONL, no server)
bin/ctfd          CTFd v1 API client: list, inspect, bulk-download files, rank, submit
bin/ctfd-env      loads CTFd credentials from ~/.config/ctfd.env without echoing them
bin/submit-flag   the one sanctioned way to submit: serialized, skips solved challenges
bin/triage        60-second first look at a challenge artifact (ELF, pcap, archive, image...)
templates/exploit.py   pwntools skeleton with notes on mistakes that cost time
env.sh            puts bin/ on PATH and sets the board location and solver identity
tests/board_smoke.sh   claim, concurrent-claim, dead-end and resubmit checks (no network)
```

## How it works

There is no scheduler process. Coordination is a convention that every solver follows through three commands, plus a human who starts the solver sessions and tells them where to focus.

**Board (`bin/board`).** One file, `.board/events.jsonl`. Every write is a single-line JSON append (`claim`, `release`, `note`, `kill`, `flag`) stamped with a UTC time and the writer's `$WHO`. Reads are projections of that file:

- `board status` shows solved and open challenges, the current holder of each, the latest notes and the latest dead ends. Each solver reads this before choosing work.
- `board claim <chal>` is the dispatch step. It is a read-then-append, so it runs under `flock` on `claim.lock`; two simultaneous claims on the same challenge cannot both succeed (`tests/board_smoke.sh` checks this).
- `board note` records a finding (an endpoint, an offset, a leaked credential) so another solver can start from it. `board kill` records a ruled-out hypothesis, `board tried <chal>` lists them.
- `board flag` records a verified flag and releases the claim.

**Intake and ranking (`bin/ctfd`).** A small stdlib-plus-`requests` client for the CTFd v1 API. `challenges` lists the board with solve counts, `files` downloads every attachment of every visible challenge in one pass, and `rank` orders challenges by how many points they would lose if more teams solved them first, using CTFd's dynamic-score decay formula. Calls do not follow redirects (a redirect means CTFd bounced you to the login page), and `submit` makes exactly one attempt and never retries, because a rate-limited attempt is already spent.

**Result collection (`bin/submit-flag`).** Takes the board name, the CTFd id and the flag. It takes a lock, checks `board status` and refuses to resubmit a challenge already marked solved, calls `bin/ctfd submit`, and on a correct result writes the flag to the board so every other solver sees it. This exists because several solvers submitting at once would otherwise race for the same submission slot.

**Triage (`bin/triage <file>`).** Prints what changes the next decision and nothing else: file type, size, hash, entropy, and for ELF files the protections, linkage, language guess (Go, Rust, C++, UPX), risky imports and win-like function names. For other types it gives the first useful commands (`jadx`, `tshark`, `exiftool`, `binwalk`).

## Configure

Nothing in this repository contains a token. Credentials come from the environment:

```bash
mkdir -p ~/.config
read -rsp "CTFd token: " T && printf 'CTFD_URL=https://ctf.example.org\nCTFD_TOKEN=%s\n' "$T" > ~/.config/ctfd.env
chmod 600 ~/.config/ctfd.env && unset T
```

| Variable | Meaning | Default |
|---|---|---|
| `CTFD_URL` | base URL of the CTFd instance | none, required |
| `CTFD_TOKEN` | API token (or set `CTFD_SESSION`, plus `CTFD_CSRF_TOKEN` if needed) | none, required |
| `CTF_BOARD_DIR` | directory holding `events.jsonl` and the lock files | `./.board` next to `env.sh` |
| `WHO` | identity recorded on each board event; give each solver its own | `$USER` |

Use it by sourcing `env.sh` at the top of each shell session. This matters for agents: their tool calls run in non-interactive shells, which skip `~/.bashrc`, so exports kept there never reach them.

```bash
source env.sh
pip install -r requirements.txt     # for bin/ctfd; triage and the template also use pwntools
board status
bin/ctfd challenges --unsolved
WHO=solver2 board claim some-challenge
submit-flag some-challenge 42 'flag{...}'
```

`bin/triage` also calls `file`, `strings`, `binwalk`, `tshark` and `exiftool` when present.

Run `bash tests/board_smoke.sh` to check the board and submit wrapper locally.

## What the board recorded

Aggregates from the event log of CSAW CTF 2026 quals, 18 to 20 September 2026 (the log itself is not published because it contains flags and notes for live challenges): 506 events across 40 challenge keys, from 23 distinct solver identities; 45 claims, 23 releases, 423 notes, 14 flag events and a single `kill`. In practice solvers wrote dead ends into notes far more often than they used `board kill`.

For the wave that is the subject of the post: the log has a note at 04:00 UTC that wave 3 had dropped (5:00 local time), and flag events for four challenges at 04:00:34, 04:02:41, 04:02:46 and 04:04:32 UTC.

## What the harness does not do

- It does not start, schedule or stop solvers, choose which challenge a solver takes, or verify a flag other than by the CTFd response.
- Quality of work was not measured. Several solvers sometimes worked the same hard challenge in parallel on purpose.
- Parallelism did not help every challenge. One web challenge stayed open for most of the event because the solvers kept testing the same family of hypotheses.

## Limits and ethics

- Check each event's rules before you use anything like this. Some CTFs restrict automation, API use during the event, or AI assistance; I have not assumed that any of them allow it. Do not run any of this against a platform whose rules forbid it.
- `ctfd unlock-hint` spends points. `submit-flag` and `ctfd submit` stop after one attempt on purpose; do not wrap them in a retry loop or use them to guess flags, which most events treat as a rules violation and which burns your rate-limit budget.
- Bulk-downloading attachments and polling challenge lists generate load on the organisers' server. Keep requests modest.
- A fast clear is not the same as understanding. The post linked above is about that gap; after an event I go back and work through what the agents did.

## Not included

Per-challenge working directories, downloaded handouts, VPN configuration, teammates' notes, challenge-specific solvers and writeups.
