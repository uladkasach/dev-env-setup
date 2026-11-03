#!/usr/bin/env bash
######################################################################
# .what = drive `git.grove.play.await` through every answer it can give, with
#         `ssh` and `rhx` stubbed, and snap what a human reads for each
#
# .why  = the skill's one accidental verdict is "finished". each path below is
#         a way it could reach that verdict before it observed the play:
#           - a value flag with no value, which looped forever
#           - an ssh or pgrep failure, which read as "no such process"
#           - the coarse `bash` read, which exited 0 on a guess
#         so each is driven, its exit code asserted, and its text snapped
#
# guarantee:
#   - HERMETIC. the stubs sit on a temp PATH; no grove is reached, no key read
#   - the real skill runs, sources the real ductwork, and parses the real args
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$HERE/.agent/repo=.this/role=any/skills/git.grove.play.await.sh"

stubs="$(mktemp -d)"
trap 'rm -rf "$stubs"' EXIT

# ssh: the reachability ask ends in `true`, the probe carries `pgrep`, and a
#   pane read carries `tmux`. each answer comes from the case's env
cat > "$stubs/ssh" <<'STUB'
#!/usr/bin/env bash
all="$*"
[[ "$all" == *" true" ]] && exit "${STUB_REACH_RC:-0}"
if [[ "$all" == *pgrep* ]]; then
  # decode the pattern the skill sent, and hold it to the case's wanted one
  b64="${all#*printf %s \'}"; b64="${b64%%\'*}"
  got="$(printf '%s' "$b64" | base64 -d)"
  if [[ -n "${STUB_WANT_PATTERN:-}" && "$got" != "$STUB_WANT_PATTERN" ]]; then
    echo "stub: pattern '$got' != wanted '$STUB_WANT_PATTERN'" >&2
    exit 3
  fi
  [[ "$all" == *"pgrep -u"* ]] || { echo "stub: pgrep not scoped by -u" >&2; exit 3; }
  [[ "${STUB_PGREP_RC:-1}" -eq 0 ]] && echo 4242
  exit "${STUB_PGREP_RC:-1}"
fi
[[ "$all" == *tmux* ]] && printf '%s\n' "${STUB_PANE:-}"
exit 0
STUB
cat > "$stubs/rhx" <<'STUB'
#!/usr/bin/env bash
echo "[stub] rhx $*"
STUB
chmod +x "$stubs/ssh" "$stubs/rhx"

failed=0
transcript=""
say() { echo "$1"; transcript+="$1"$'\n'; }
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

say "🌲 prove.play-await-reads-three-answers"

# one case — $1 = label · $2 = exit code wanted · then `env` assignments, a `--`,
#   and the skill's args. its full output joins the transcript under the label
case_run() {
  local label="$1" want="$2" out rc
  shift 2
  local envs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  out="$(env PATH="$stubs:$PATH" "${envs[@]}" bash "$SKILL" "$@" 2>&1)" && rc=0 || rc=$?
  transcript+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$out"$'\n'
  if [[ "$rc" -eq "$want" ]]; then
    echo "   • $label → rc=$rc ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $label → rc=$rc, expected rc=$want"
  failed=1
  return 1
}

# the help — usage, guarantee, exit; the maintainer's notes stay out
case_run "--help"                             0 -- --help

# the parser — each malformed call refuses at once (rc 2), never loops
case_run "a value flag with no value"         2 -- grove-1 --play
case_run "a zero interval"                    2 -- grove-1 --play x --every 0
case_run "two groves named"                   2 -- grove-1 grove-2 --play x
case_run "a --grove and a bare grove"         2 -- --grove grove-1 grove-2 --play x
case_run "a --timeout, which is no flag"      2 -- grove-1 --timeout 400
case_run "an unknown flag"                    2 -- grove-1 --wait 400

# the accurate path — three answers from pgrep, never two
case_run "--play · pgrep finds none → finished"        0 STUB_PGREP_RC=1   -- grove-1 --play x
# --every 5 past a --within 2: the last nap is cut, so the bound reads 2s, never 5s
case_run "--play · pgrep finds the play → bound hit"   3 STUB_PGREP_RC=0   -- grove-1 --play x --every 5 --within 2
case_run "--play · --quiet → exit code only, no output" 0 STUB_PGREP_RC=1  -- grove-1 --play x --quiet
case_run "--play · --quiet, bound hit → rc 3, no output" 3 STUB_PGREP_RC=0 -- grove-1 --play x --every 1 --within 1 --quiet
case_run "--play · pgrep cannot be asked → no verdict" 1 STUB_PGREP_RC=255 -- grove-1 --play x
case_run "--play · --quiet, cannot be asked → rc 1, the error still prints" 1 STUB_PGREP_RC=255 -- grove-1 --play x --quiet
case_run "--play · the grove does not answer"          1 STUB_REACH_RC=255 -- grove-1 --play x

# the pattern — dots escaped, anchored at both ends, scoped to the ssh user.
#   a mismatch makes the stub fail as pgrep would (rc 3), which the skill reads as rc 1
case_run "--play · the pattern is exact for prove.x"   0 STUB_PGREP_RC=1 'STUB_WANT_PATTERN=(^|/)[p]rove\.x\.play\.sh( |$)' -- grove-1 --play prove.x

# the coarse path — `bash` is a guess and never exits 0
case_run "coarse · pane at bash → a guess"     3 STUB_PANE=bash -- grove-1
case_run "coarse · pane at zsh → idle"         0 STUB_PANE=zsh  -- grove-1
case_run "coarse · pane unreadable"            1 STUB_PANE=     -- grove-1

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.play-await-reads-three-answers.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
