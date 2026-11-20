#!/usr/bin/env bash
######################################################################
# .what = prove two alias writes at the same instant both land: the owned ssh file
#         is read, composed, and swapped under one lock, so no write loses another's block
#
# .why  = every writer reads `~/.ssh/config.d/grove.conf` whole and swaps it whole. with no
#         lock, writer A reads, writer B writes its block, and A's swap puts back the file
#         as A read it — B's block is gone, and its crews fail `Permission denied`.
#         crews, boots, and wakes write that file from many shells at once
#
# .how  = deterministic, never a race left to chance. writer A's `awk` is a stub that reads
#         the file, then parks until the play releases it. writer B runs while A is parked:
#           - with the lock, B waits on A, and both blocks land
#           - with the lock cut, B finishes while A is parked, and A's swap drops B's block
#
# .the rows
#   1. the writer      — A parked mid-write; B waits on the lock; both blocks present
#   2. the bite        — the same two writes with the lock cut: B's block is lost
#
# usage:
#   rhx play.run --play prove.alias-writers-lose-no-block
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

echo "🔎 prove.alias-writers-lose-no-block"
echo "   └─ subject: grove_ssh_alias_set (git.grove.ssh.operations.sh)"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
OPS="$ROOT/.agent/repo=.this/role=any/skills/git.grove.ssh.operations.sh"
[[ -f "$OPS" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $OPS" >&2; exit 2; }
command -v flock >/dev/null 2>&1 || { echo "   └─ ✋ ConstraintError: flock is absent" >&2; exit 2; }
REAL_AWK="$(command -v awk)"; REAL_SSH="$(command -v ssh)"

failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}

FIX="$(mktemp -d)" || { echo "   └─ 💥 MalfunctionError: could not build a fixture dir" >&2; exit 1; }
trap 'rm -rf "$FIX"' EXIT
export HOME="$FIX/home"
mkdir -p "$FIX/bin" "$FIX/slow"

# ssh: `-G` goes to the real ssh against the fixture config (it dials naught)
cat > "$FIX/bin/ssh" <<STUB
#!/usr/bin/env bash
exec "$REAL_SSH" -F "\$HOME/.ssh/config" "\$@"
STUB
# awk, for writer A only: the block-drop program reads the file, then parks until released
cat > "$FIX/slow/awk" <<STUB
#!/usr/bin/env bash
if [[ "\$*" == *prevblank* ]]; then
  "$REAL_AWK" "\$@" > "$FIX/a.buf"; rc=\$?
  touch "$FIX/a.read"
  for _ in \$(seq 400); do [[ -e "$FIX/a.go" ]] && break; sleep 0.05; done
  cat "$FIX/a.buf"; exit \$rc
fi
exec "$REAL_AWK" "\$@"
STUB
chmod +x "$FIX/bin/ssh" "$FIX/slow/awk"

# .what = a fresh HOME whose ~/.ssh/config already holds the Include, and one old block
fixture_reset() {
  rm -rf "$HOME" "$FIX"/a.*; mkdir -p "$HOME/.ssh/config.d"
  printf 'Include %s\n\n' "$HOME/.ssh/config.d/grove.conf" > "$HOME/.ssh/config"
  printf 'Host alias-old\n  HostName old.example\n' > "$HOME/.ssh/config.d/grove.conf"
}

# .what = one alias write from a given ops file; PATH names which awk it sees
write_alias() {
  local ops="$1" path="$2" alias="$3"
  PATH="$path" bash -c 'source "$1"; grove_ssh_alias_set alias="$2" host="$2.example" port=22 user=camper identity="$HOME/.ssh/id"' \
    _ "$ops" "$alias" > "$FIX/$alias.out" 2>&1
}

# .what = run A (parked) and B at once; report whether B finished while A was parked
race() {
  local ops="$1" apid bpid i bearly=no
  write_alias "$ops" "$FIX/slow:$FIX/bin:$PATH" alias-a & apid=$!
  for i in $(seq 400); do [[ -e "$FIX/a.read" ]] && break; sleep 0.05; done
  [[ -e "$FIX/a.read" ]] || { echo "   └─ 💥 MalfunctionError: writer A never reached its read" >&2; exit 1; }
  write_alias "$ops" "$FIX/bin:$PATH" alias-b & bpid=$!
  # a bound, not a verdict: long enough for an unlocked B to finish, never a race to win
  for i in $(seq 60); do kill -0 "$bpid" 2>/dev/null || { bearly=yes; break; }; sleep 0.05; done
  touch "$FIX/a.go"
  wait "$apid"; wait "$bpid"
  echo "$bearly"
}

OWN="$HOME/.ssh/config.d/grove.conf"

######################################################################
# row 1 — the writer as shipped
######################################################################
fixture_reset
bearly="$(race "$OPS")"
claim "1a. B waited on the lock while A held it (did not finish early)" [ "$bearly" = "no" ]
claim "1b. writer A's block landed" grep -qxF "Host alias-a" "$OWN"
claim "1c. writer B's block landed" grep -qxF "Host alias-b" "$OWN"
claim "1d. the block both found was kept" grep -qxF "Host alias-old" "$OWN"

######################################################################
# row 2 — the bite: the lock cut, the same two writes
######################################################################
fixture_reset
cp "$OPS" "$FIX/ops.cut.sh"
printf '\ngrove_ssh_config_locked() { "$@"; }\n' >> "$FIX/ops.cut.sh"
bearly="$(race "$FIX/ops.cut.sh")"
claim "2a. without the lock, B finished while A was parked (the fixture took)" [ "$bearly" = "yes" ]
claim "2b. without the lock, A's swap dropped B's block" bash -c '! grep -qxF "Host alias-b" "$1"' _ "$OWN"

echo ""
echo "🌊 $passed held · $failed failed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0
