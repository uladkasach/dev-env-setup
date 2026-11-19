#!/usr/bin/env bash
######################################################################
# .what = prove `git.grove.send` clears O_NONBLOCK on its stdout before it relays
#         a byte, so a large reply reaches its caller whole
#
# .why  = a node parent (rhx, an agent harness) may hand its child a pipe whose
#         open file description carries O_NONBLOCK. the relay sink then meets
#         EAGAIN on a burst and drops the rest:
#           sed: couldn't write 56 items to stdout: Resource temporarily unavailable
#         📜 2026-11-18: a whole-tree plan relayed ~8KB and stopped mid-word,
#         three times, with the command green on the box
#
# .how  = the flag lives on the open file DESCRIPTION, which a parent and its
#         child share. so a perl parent sets O_NONBLOCK on a pipe, hands it to
#         the skill as stdout, waits, and reads the flag back on its own end.
#         `sync` = the flag is clear · `async` = O_NONBLOCK is set. no grove, no network
#
# .the rows
#   0. the fixture  — a child that touches no flag leaves it async
#                     (the harness can see the flag at all)
#   1. the skill    — `git.grove.send --help` leaves it sync
#   2. the bite     — the same skill with its set_sync call cut leaves it
#                     async, so row 1 holds only because of the fix
#
# usage:
#   rhx play.run --play prove.send-sets-its-stdout-sync
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

echo "🔎 prove.send-sets-its-stdout-sync"
echo "   └─ subject: git.grove.send's stdout set_sync"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
SKILLS="$ROOT/.agent/repo=.this/role=any/skills"
ALIASES="$ROOT/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh"
SEND="$SKILLS/git.grove.send.sh"
for f in "$SEND" "$SKILLS/git.grove.ssh.operations.sh" "$ALIASES"; do
  [[ -f "$f" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $f" >&2; exit 2; }
done
command -v perl >/dev/null 2>&1 || { echo "   └─ ✋ ConstraintError: perl is absent; the harness needs fcntl" >&2; exit 2; }

failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}

FIX="$(mktemp -d)" || { echo "   └─ 💥 MalfunctionError: could not build a fixture dir" >&2; exit 1; }
trap 'rm -rf "$FIX"' EXIT

# a hermetic HOME, so the borrows gate reads THIS checkout's aliases
export HOME="$FIX/home"
mkdir -p "$HOME"
cp "$ALIASES" "$HOME/.bash_aliases"
cp "$(dirname "$ALIASES")/ductwork.sh" "$HOME/.bash_aliases.ductwork.sh"

# the gate must pass, else the skill exits before the call under test and row 1
#   reads `async` for a reason that has naught to do with the fix
gate="$(bash -c 'source ~/.bash_aliases; command -v git_alias_grove && command -v __duct_strip_escapes' 2>/dev/null)"
[[ "$gate" == *__duct_strip_escapes* ]] || { echo "   └─ ✋ ConstraintError: the fixture HOME lacks the borrows the skill gates on" >&2; exit 2; }

# .what = run a command with an O_NONBLOCK pipe as its stdout; print the flag
#         state the parent reads back on its own end after the child exits
# .note = the child's output is small (a --help), so it fits the pipe buffer and
#         the parent may wait before it drains
flag_after() {
  perl -MFcntl -e '
    pipe(my $r, my $w) or die "pipe: $!";
    my $f = fcntl($w, F_GETFL, 0) or die "getfl: $!";
    fcntl($w, F_SETFL, $f | O_NONBLOCK) or die "setfl: $!";
    my $pid = fork() // die "fork: $!";
    if ($pid == 0) {
      close $r;
      open(STDOUT, ">&", $w) or die "dup: $!";
      exec @ARGV or die "exec: $!";
    }
    waitpid($pid, 0);
    my $after = fcntl($w, F_GETFL, 0);
    print(($after & O_NONBLOCK) ? "async" : "sync");
  ' "$@" 2>/dev/null
}

# row 0 — the fixture sees the flag
got="$(flag_after true)"
claim "0. a child that touches no flag leaves the pipe async (got: $got)" [ "$got" = "async" ]

# row 1 — the skill clears it
got="$(flag_after bash "$SEND" --help)"
claim "1. git.grove.send leaves its stdout sync (got: $got)" [ "$got" = "sync" ]

# row 2 — the bite: cut the one call, and the flag stays
mkdir -p "$FIX/skills"
cp "$SKILLS/git.grove.ssh.operations.sh" "$FIX/skills/"
grep -vx '__grove_send_stdout_set_sync' "$SEND" > "$FIX/skills/git.grove.send.sh"
claim "2a. the cut copy lacks the call (the fixture took)" \
  bash -c '! grep -qx "__grove_send_stdout_set_sync" "$1"' _ "$FIX/skills/git.grove.send.sh"
got="$(flag_after bash "$FIX/skills/git.grove.send.sh" --help)"
claim "2b. without the call, the stdout stays async (got: $got)" [ "$got" = "async" ]

echo ""
echo "🌊 $passed held · $failed failed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0
