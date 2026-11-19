#!/usr/bin/env bash
# source env.sh
#
# Non-interactive shells (which is what a solver process's tool calls run in)
# skip ~/.bashrc, so anything exported there never reaches them. Source this
# explicitly at the top of any CTF-related shell call.
#
#   CTF_BOARD_DIR   where the shared board lives (default: ./.board next to this file)
#   WHO             identity written on every board event (default: $USER)
#   CTFD_URL, CTFD_TOKEN   read from ~/.config/ctfd.env if that file exists
#                          (chmod 600; never put the token on a command line)
_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$_HERE/bin:$PATH"
export CTF_BOARD_DIR="${CTF_BOARD_DIR:-$_HERE/.board}"
export WHO="${WHO:-$USER}"
if [ -r "$HOME/.config/ctfd.env" ]; then
  set -a; . "$HOME/.config/ctfd.env"; set +a
fi
unset _HERE
