#!/usr/bin/env bash
######################################################################
# .what = drive `git.grove.play.stop` through every answer it can give, with
#         `ssh` stubbed to run the far procedure HERE, and snap what a human reads
#
# .why  = the stop's one accidental verdict is "none ran". a pgrep that could
#         not answer left its pid list empty, so the stop printed `stopped: none`
#         and exited 0 over a play it never saw. each path below is driven, its
#         exit code asserted, and its text snapped
#
# guarantee:
#   - HERMETIC. ssh decodes the procedure the skill sent and runs it under a
#     temp HOME, with a stub pgrep first on PATH; no grove is reached
#   - one case stops a real process: a `sleep` this play spawned, TERM'd
#   - the real skill runs, sources the real grove lib, and parses the real args
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$HERE/.agent/repo=.this/role=any/skills/git.grove.play.stop.sh"

stubs="$(mktemp -d)"
home="$(mktemp -d)"
sleeper=""
trap 'rm -rf "$stubs" "$home"; [[ -n "$sleeper" ]] && kill "$sleeper" 2>/dev/null' EXIT

# ssh: decode the far procedure and run it here, or fail as an absent box would
cat > "$stubs/ssh" <<'STUB'
#!/usr/bin/env bash
[[ -n "${STUB_SSH_RC:-}" ]] && exit "$STUB_SSH_RC"
all="$*"
b64="${all#*printf %s \'}"; b64="${b64%%\'*}"
procedure="$(printf '%s' "$b64" | base64 -d)"
if [[ -n "${STUB_WANT_PATTERN:-}" && "$procedure" != *"pat='$STUB_WANT_PATTERN'"* ]]; then
  echo "stub: the procedure does not carry pattern '$STUB_WANT_PATTERN'" >&2
  exit 4
fi
exec bash -c "$procedure"
STUB
# pgrep: `-f` answers the case's roots; `-P` answers no children
cat > "$stubs/pgrep" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == *" -P "* || "$1" == -P ]] && exit 1
[[ "$*" == *"-u "* ]] || { echo "stub: pgrep not scoped by -u" >&2; exit 3; }
[[ -n "${STUB_ROOTS:-}" ]] && { printf '%s\n' $STUB_ROOTS; exit 0; }
exit "${STUB_PGREP_RC:-1}"
STUB
chmod +x "$stubs/ssh" "$stubs/pgrep"

failed=0
transcript=""
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }
fail() { cry "   💥 MalfunctionError: $1"; failed=1; }

echo "🌲 prove.play-stop-reads-three-answers"

# one case — $1 = label · $2 = exit code wanted · then `env` assignments, a `--`,
#   and the skill's args. its output, pids and the disk masked, joins the transcript
case_run() {
  local label="$1" want="$2" out rc
  shift 2
  local envs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  out="$(env PATH="$stubs:$PATH" HOME="$home" "${envs[@]}" bash "$SKILL" "$@" 2>&1)" && rc=0 || rc=$?
  out="$(printf '%s\n' "$out" | sed -E 's/disk after: .*/disk after: <df>/; s/[0-9]{2,}/<pid>/g')"
  transcript+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$out"$'\n'
  if [[ "$rc" -eq "$want" ]]; then
    echo "   • $label → rc=$rc ✔"
    return 0
  fi
  fail "$label → rc=$rc, expected rc=$want"
  return 1
}

# the parser — each malformed call refuses at once (rc 2)
case_run "no --play"                                   2 -- grove-1
case_run "a bare --play, its value absent"             2 -- grove-1 --play
case_run "a --scratch outside .local/state"            2 -- grove-1 --play x --scratch 'git/*'
case_run "a --scratch that climbs"                     2 -- grove-1 --play x --scratch '.local/state/../x'

# three answers from pgrep, never two
case_run "pgrep finds none → none ran, rc 0"           0 STUB_PGREP_RC=1 -- grove-1 --play x
case_run "pgrep cannot answer → no verdict, rc 1"      1 STUB_PGREP_RC=2 -- grove-1 --play x
case_run "the grove does not answer → rc 1"            1 STUB_SSH_RC=255 -- grove-1 --play x

# the pattern — the shared `_play_pattern`, dots escaped and anchored
case_run "the pattern is exact for prove.x"            0 STUB_PGREP_RC=1 'STUB_WANT_PATTERN=(^|/)[p]rove\.x\.play\.sh( |$)' -- grove-1 --play prove.x

# a real stop: a process this play owns is TERM'd, and its scratch removed
sleep 300 & sleeper=$!
mkdir -p "$home/.local/state/proof.abc123" "$home/.local/state/other.keep"
case_run "a found play is stopped, its scratch removed" 0 "STUB_ROOTS=$sleeper" -- grove-1 --play x --scratch '.local/state/proof.*'
sleep 0.5
kill -0 "$sleeper" 2>/dev/null && fail "the found play still runs after the stop"
[[ -e "$home/.local/state/proof.abc123" ]] && fail "the named scratch dir is still there"
[[ -e "$home/.local/state/other.keep" ]] || fail "a scratch dir the glob did not name was removed"
sleeper=""

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.play-stop-reads-three-answers.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
