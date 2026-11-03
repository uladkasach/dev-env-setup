#!/usr/bin/env bash
######################################################################
# .what = block until a grove's duct falls idle, then print its tail
#
# .why  = `git.grove.send --play` RETURNS IMMEDIATELY. a duct is tmux, so the
#         send drops a line into a pane and hands control straight back. a play
#         that takes ten minutes therefore looks finished the instant it starts,
#         and the caller is left to invent a wait.
#
# ⚠️ .why a SKILL and not a poll loop retyped at the prompt
#         the ad-hoc form, `for f in 1 2 3 …; do rhx git.grove.read …; done`, is
#         wrong in four ways every time a human retypes it:
#           1. it has NO DELAY — the interval is whatever the network round trip
#              happens to be, so it burns forty calls in two minutes and answers
#              a question nobody asked
#           2. it reads the RENDER, not the state. tmux repaints the same
#              scrollback, so an unchanged tail means neither "done" nor "busy"
#           3. it prints on every iteration, so the real answer is buried under
#              its own noise — or, piped to `tail -1`, prints not one line at all
#           4. it never terminates on its own; the human decides when to stop,
#              which is the exact judgment the wait was supposed to remove
#         each of those is a wait that cannot answer, which is worse than no wait
#         (`rule.require.wrap-cli-in-skills`).
#
# .how it knows the play is done
#         ⇒ WITH `--play <name>`, it asks whether THAT play's process is alive.
#           `git.grove.send --play` guarantees the FILENAME `<name>.play.sh`, so
#           the play is nameable on the box: `pgrep -f '<name>.play.sh'`.
#           that probe answers the caller's actual question — "is MY play still
#           at work" — and it is the accurate one.
#
#           ⚠️ the DIRECTORY is no part of the pattern. it moved once already,
#              and this probe did not move with it — see the 🛑 block at
#              `__grove_play_pids`
#
#         ⇒ WITHOUT it, it falls back to "is the pane back at a shell", which is
#           ductwork's `__duct_pane_is_idle`, sourced rather than copied
#           (`rule.forbid.two-writers-on-one-artifact`).
#
# ⚠️ .why the fallback is COARSE, and why that is ductwork's rightness not its bug
#         the two callers ask different questions of the same tmux field:
#
#           duct.send          "would a send EXECUTE here?"   bash ⇒ yes, idle
#           git.grove.play.await   "did MY PLAY finish?"          bash ⇒ cannot tell
#
#         a play runs as `bash /tmp/grove.play.<name>.play.sh`, so
#         `pane_current_command` reports `bash` for its whole life — and `bash` is
#         in ductwork's idle set, correctly, because a nested bash sat at a prompt
#         WOULD execute what it is sent.
#
#         measured 2026-08-06 on grove-1, whose login shell is zsh: a 136-repo
#         clone was declared "✔ idle after 0s — the pane is back at 'bash'" three
#         times while it was still cloning. the probe was truthful and answered a
#         question no caller had asked (`term=probe` — a probe must be able to
#         FAIL the way the defect fails).
#
#         so the fallback stays: a box whose shell is bash and whose plays are
#         unnamed cannot be told apart by tmux alone. and it SAYS it is a guess,
#         never a verdict (`rule.forbid.failhide`).
#
# ⚠️ .always pass --play. a bare await is a GUESS, and it reads like an answer
#
#      measured 2026-08-08, over a whole session: `rhx git.grove.play.await grove-1
#      --lines 40` was called ~30 times with no `--play`. each took the coarse
#      path, returned mid-run with a partial pane, and twice led a reader to
#      conclude a healthy 40-second suite had STALLED — which cost a round of
#      process forensics on a box that was fine.
#
#      the skill said so itself, every time, in the 🌙 block it prints. a caution
#      that is correct, prominent, and ignored ~30 times names an ERGONOMIC
#      problem: the wrong call was the shorter call.
#
#      ⇒ so `--play` is documented first here, and the coarse form is listed last
#        and labelled. see `gotcha.a-check-that-cries-wolf-gets-silenced`
#
# usage:
#   rhx git.grove.play.await grove-1 --play <name>               # ✔ accurate — names the play, an answer
#   rhx git.grove.play.await grove-1 --play <name> --within 3600 # a longer bound
#   rhx git.grove.play.await grove-1 --play <name> --lines 80    # how much tail to print
#   rhx git.grove.play.await grove-1 --play <name> --quiet       # exit code only; errors still print
#   rhx git.grove.play.await --grove grove-2 --play <name>       # --grove still works
#   rhx git.grove.play.await grove-1                             # 🌙 coarse — names no play, a guess
#
# guarantee:
#   - READ-ONLY on the grove. per poll, with `--play`, it runs two ssh asks — a
#     reachability `true`, then one `pgrep` — and without it, one pane read. it
#     types no key into the pane and changes no state
#   - BOUNDED. `--within` caps the polls, each ssh is capped at 30s, and a
#     malformed flag refuses at once rather than loop
#   - it prints ONE progress line per state CHANGE, so a long wait is legible
#
# exit:
#   0 = a verdict: the play finished (or, coarse, the pane is back at a non-bash
#       shell); tail printed
#   1 = a malfunction: the grove could not be asked, or this checkout lacks the
#       ductwork the ask rides on — either way, no state was observed
#   2 = the call was malformed — an absent value, an unknown flag, two groves
#   3 = no verdict: `--within` elapsed with the play still busy, or the coarse
#       read saw `bash` and cannot tell done from busy. the tail is printed anyway
#
# ⚠️ .how to see this skill BITE, after any change to how it decides busy
#         this skill's whole job is to report BUSY, and the one verdict it can
#         reach by accident is "finished". so a run against a play that is
#         already done proves only that the await ran (`term=probe`, hazard 3).
#
#         so the subject must be SLOW on purpose. write a scratch play that
#         sleeps 90s and prints at both ends, then:
#           rhx git.grove.send <g> --detach --play <it>
#           rhx git.grove.play.await <g> --play <it>
#
#         the await must report BUSY first and finished second. a probe's first
#         run answered "✔ the play finished after 0s" against exactly that
#         subject — the false ✔ a slow fixture catches
#         (`rule.require.clamp-edge-cases`).
#
#         🛑 AND after any change to how `git.grove.send` handles a play. that
#            trigger's absence let a false ✔ live four days, to 2026-08-14: the
#            send moved the path it lands a play at, this skill kept the stale
#            one, and the clamp never ran, since THIS file had not changed.
#
#            ⇒ a clamp over a convention TWO components share must fire when
#              EITHER moves. a trigger that names only its own file guards half
#              the seam (`rule.require.exemptions-name-their-trigger`, applied
#              to a trigger rather than an exemption)
######################################################################

set -uo pipefail

GROVE="grove-1"
EVERY=15
WITHIN=1800
LINES=40
QUIET=0
PLAY=""

######################################################################
# ⚠️ the grove may be POSITIONAL, because every sibling takes it that way
#
#      `git.grove.send grove-1 --play x`, `git.grove.read grove-1 --lines 40`,
#      `git.grove.push grove-1 --from src` — the whole family names the grove
#      first and unflagged. this skill took only `--grove`, and its catch-all
#      (`*) shift ;;`) DISCARDED anything else in silence.
#
#      measured 2026-08-08: every call that session read
#      `rhx git.grove.play.await grove-1 --lines 40`. the `grove-1` was swallowed,
#      the default was used, and — because the default IS grove-1 — the answer
#      was right by luck. a call that named grove-2 would have awaited grove-1
#      and said so nowhere (rule.forbid.failhide).
#
# ⚠️ and an UNKNOWN flag now refuses rather than shifts past
#      the same catch-all ate `--timeout 400` for a whole session — a flag this
#      skill does not carry (`--within` is the bound). so a caller who believed
#      they had raised the bound had raised none, and the silence is what let
#      the mistake repeat (rule.require.errors-name-the-fix)
######################################################################
# a value flag with no value refuses. `shift 2` past the last arg fails and
#   shifts naught, so the loop would see the same flag forever
# $1 = what is wrong · $2 = a hint (optional) · $3 = the flags the fix names (optional)
__await_refuse() {
  echo "✋ ConstraintError: git.grove.play.await: $1" >&2
  [[ -n "${2:-}" ]] && echo "   $2" >&2
  echo "   fix: rhx git.grove.play.await <grove> --play <name> ${3:---within 600}" >&2
  exit 2
}
__await_value() {
  [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || __await_refuse "$1 needs a value"
}
GROVE_BARE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --grove)  __await_value "$@"
              [[ -z "$GROVE_BARE" ]] || __await_refuse "two groves named: '$GROVE_BARE' and '$2'"
              GROVE_BARE="$2"; GROVE="$2"; shift 2 ;;
    --play)   __await_value "$@"; PLAY="$2"; shift 2 ;;
    --every)  __await_value "$@"; EVERY="$2"; shift 2 ;;
    --within) __await_value "$@"; WITHIN="$2"; shift 2 ;;
    --lines)  __await_value "$@"; LINES="$2"; shift 2 ;;
    --quiet)  QUIET=1; shift ;;
    --help|-h)
      # usage, guarantee, and exit — the maintainer's notes below them stay out
      sed -n '/^# usage:/,/^# ⚠️ .how to see this skill BITE/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'
      exit 0
      ;;
    # rhx injects --repo/--role/--skill; step over them
    --repo|--role|--skill) shift 2 ;;
    --timeout*)
      __await_refuse "unknown arg '$1'" "the bound is --within, in seconds — there is no --timeout"
      ;;
    -*)
      __await_refuse "unknown arg '$1'" "the flags are --grove --play --every --within --lines --quiet"
      ;;
    *)
      # the first bare word is the grove, as every sibling skill takes it.
      #   a second grove — bare or by --grove — would silently replace it, so it refuses
      [[ -z "$GROVE_BARE" ]] || __await_refuse "two groves named: '$GROVE_BARE' and '$1'"
      GROVE_BARE="$1"; GROVE="$1"; shift ;;
  esac
done

# a zero or non-numeric interval never advances WAITED, so the bound never bites
[[ "$EVERY" =~ ^[1-9][0-9]*$ ]]  || __await_refuse "--every must be a whole number of seconds ≥ 1, got '$EVERY'" "" "--every 15 --within 600"
[[ "$WITHIN" =~ ^[1-9][0-9]*$ ]] || __await_refuse "--within must be a whole number of seconds ≥ 1, got '$WITHIN'"
[[ "$LINES" =~ ^[1-9][0-9]*$ ]]  || __await_refuse "--lines must be a whole number ≥ 1, got '$LINES'" "" "--within 600 --lines 40"

# --quiet means the exit code alone: stdout goes, stderr (the errors) stays
# --quiet drops stdout — the banner, progress, verdict, and tail. stderr stays, so a
#   malfunction still names its cause and its fix
[[ "$QUIET" -eq 1 ]] && exec 1>/dev/null

######################################################################
# ductwork is the owner of both the uri grammar and the idle definition.
# it is SOURCED rather than reimplemented so this skill cannot answer a
# different question than `duct.send --await` does
######################################################################
_skill_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
_repo_root="$(cd -- "$_skill_dir/../../../.." && pwd)"
_ductwork="$_repo_root/src/grove.provision/2.shell/2.7.aliases/ductwork.sh"

if [[ ! -r "$_ductwork" ]]; then
  echo "💥 MalfunctionError: ductwork is absent from this checkout" >&2
  echo "   looked at: $_ductwork" >&2
  echo "   ⇒ it owns the duct uri grammar and the idle definition, so without" >&2
  echo "     it this skill would have to guess at both" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$_ductwork"

URI="duct://$GROVE/main/mechanic"
if ! __duct_parse_uri "$URI"; then
  echo "💥 MalfunctionError: could not parse $URI" >&2
  exit 1
fi

######################################################################
# the ACCURATE probe: is this named play's process still alive?
#
# .why it beats the pane read
#      `git.grove.send --play` lands the play under a FILENAME it guarantees —
#      `<name>.play.sh` — so the play is NAMEABLE. that turns a coarse question
#      about the pane into a precise one about the work, and it is the
#      difference between "some bash is alive" and "MY play is alive".
#
# 🛑 .the pattern names the FILE and never its DIRECTORY, and that is the fix
#
#      a pattern that pins the DIRECTORY breaks when `git.grove.send` moves the
#      path it lands at — as it did on 2026-08-10, from
#      `/tmp/grove.play.<n>.play.sh` to
#      `$HOME/.local/state/grove.play/<n>.play.sh`, for two good reasons it
#      documents at length (a shared /tmp collides across seats; /tmp never
#      auto-cleans, so a stale play outlives its session).
#
#      a probe left behind then matches no process at all, so it answers "the
#      play finished" for every play, always.
#
#      📜 measured 2026-08-14 on grove-ahbode-v20260811. `prove.rc-ownership`
#        was sent, and one second later:
#
#          ✔ the play finished after 0s
#          $ pgrep -fa prove.rc-ownership
#          95448 bash /home/camper/.local/state/grove.play/prove.rc-ownership.play.sh
#
#        the one verdict this skill can reach BY ACCIDENT is "finished", which
#        its own ⚠️ above says, so the false ✔ read exactly like a fast play
#        (`rule.forbid.failhide`).
#
#      ⇒ so the DIRECTORY is deliberately absent from the pattern below. it is
#        `git.grove.send`'s private business, and a probe that restates it holds
#        an invisible dependency on another component's convention — one that
#        appears in no argument and breaks in silence when that convention moves
#        (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.2).
#
# ⚠️ .and the CLAMP was pointed at the wrong file
#      `prove.play-await-bites` exists precisely to catch a false "finished",
#      and it did not, because it is run "after ANY change to how THIS SKILL
#      decides busy" — and this skill did not change. `git.grove.send` did.
#
#      ⇒ a convention shared by two skills needs its clamp run when EITHER
#        moves. see that play's own header for the trigger this added
#
# ⚠️ .why it runs over its own ssh rather than through the duct
#      a duct IS tmux, so to ask down the duct would put a command in the very
#      pane whose busyness is the question — it would land in the play's stdin.
#      the ask must go around the pane, never through it.
#
# ⚠️ .the pattern is exact, and belt-and-braces against a self-match
#      - dots are escaped, so `prove.x` never matches `proveax`
#      - it is anchored: a `/` or line start before, a space or line end after,
#        so `x` never matches `prex.play.sh`
#      - `-u` scopes it to the ssh user — the seat that owns the duct — so
#        another account's same-named play never reads as busy
#      - pgrep excludes itself, and the wrapper shell's argv carries base64, not
#        the pattern. the bracket on the first character stays as a guard should
#        a later edit ever put the decoded text on an argv
#
# returns: 0 + the pids = busy · 1 = no such play · 2 = the box was not asked
######################################################################
__grove_play_pids() {
  local name="${1:?}"
  local rest="${name:1}"
  local pattern="(^|/)[${name:0:1}]${rest//./\\.}\\.play\\.sh( |\$)"
  ####################################################################
  # ⚠️ the pattern is base64'd, because ssh takes NO ARGV
  #    it joins its arguments into one string and hands that to a login shell,
  #    so `$pattern` is CODE on the far side. the single quotes around it are
  #    closed by one single quote in a play name. base64's alphabet is
  #    `[A-Za-z0-9+/=]` and holds no shell metacharacter, so they cannot be
  #    (`src/grove.provision/2.shell/2.7.aliases/ductwork.sh`'s `__duct_ssh_tmux` carries the reason in full).
  #
  #    ⇒ a play name is local argv today, so this is the cheap half of the
  #      class rather than a live hole. the seam is retired anyway: a guarantee
  #      that holds only while one caller stays local is one nobody can audit
  #
  # 🛑 `__duct_strip_escapes` — the ANSWER is grove-chosen, and its only reader
  #    is a terminal that obeys escapes. pgrep prints pids on a healthy box;
  #    on a compromised one it prints whatever that box wants
  ####################################################################
  local b64 out rc
  b64="$(printf '%s' "$pattern" | base64 | tr -d '\n')"
  # bounded: a hung ssh would otherwise outlive --within
  out="$(timeout 30 ssh -o BatchMode=yes -o ConnectTimeout=10 "$DUCT_HOST" \
    "pgrep -u \"\$(id -u)\" -f -- \"\$(printf %s '$b64' | base64 -d)\"" 2>/dev/null)"
  rc=$?
  ####################################################################
  # 🛑 three answers, never two. pgrep says 0 = a match, 1 = no match; every
  #    other code — ssh's 255, timeout's 124, pgrep's 2 or 3 — means the box
  #    was NOT asked. read as "no match", that would report a play finished
  #    that was never observed (rule.forbid.failhide)
  ####################################################################
  [[ "$rc" -eq 1 ]] && return 1
  [[ "$rc" -eq 0 ]] || return 2
  printf '%s' "$out" | __duct_strip_escapes
}

echo "⏳ git.grove.play.await --grove $GROVE --every ${EVERY}s --within ${WITHIN}s"
echo "   ├─ duct: $URI"
if [[ -n "$PLAY" ]]; then
  echo "   ├─ play: ${PLAY}.play.sh (matched by its filename)"
  echo "   └─ waits for that play's process to exit"
else
  echo "   └─ waits for the pane to return to a shell"
  echo ""
  echo "   🌙 no --play given, so this is the coarse read: a play runs as"
  echo "      'bash <script>', and 'bash' is indistinguishable from an idle"
  echo "      shell. it may report done while the play still runs."
  echo "      ⇒ for an accurate wait, name it: --play <name>"
fi
echo ""

WAITED=0

# one nap, never past the bound: the last one is cut to what --within has left
__await_nap() {
  local nap="$EVERY"
  (( WITHIN - WAITED < nap )) && nap=$(( WITHIN - WAITED ))
  sleep "$nap"
  WAITED=$(( WAITED + nap ))
}

# the tail is a courtesy beside a verdict already reached, so a failed read
#   warns and never changes the exit code the verdict earned
__await_tail() {
  [[ "$QUIET" -eq 1 ]] && return 0
  rhx git.grove.read "$GROVE" --lines "$LINES" \
    || echo "   🌙 the tail could not be read; the verdict above stands" >&2
}
LAST=""

while [[ "$WAITED" -lt "$WITHIN" ]]; do
  ####################################################################
  # the accurate path: ask about the PLAY, not about the pane
  ####################################################################
  if [[ -n "$PLAY" ]]; then
    # ⚠️ an ssh that cannot reach the box answers empty, exactly as a finished
    #    play does. so reachability is asked SEPARATELY — to conflate them would
    #    report a play complete that was never observed (rule.forbid.failhide)
    if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$DUCT_HOST" true 2>/dev/null; then
      echo "   💥 MalfunctionError: the grove did not answer, so the play's state is unknown" >&2
      echo "      ⇒ empty output from an unreachable box looks exactly like a" >&2
      echo "        finished play, so this refuses to guess between them" >&2
      echo "      fix: rhx git.grove.wake $GROVE" >&2
      exit 1
    fi

    PIDS_RC=0
    PIDS="$(__grove_play_pids "$PLAY")" || PIDS_RC=$?
    if [[ "$PIDS_RC" -eq 2 ]]; then
      echo "   💥 MalfunctionError: the grove could not be asked whether the play runs" >&2
      echo "      ⇒ ssh, its time bound, or pgrep failed; that is no answer, so this" >&2
      echo "        refuses to call the play finished" >&2
      echo "      fix: rhx git.grove.wake $GROVE, then await again" >&2
      exit 1
    fi
    if [[ "$PIDS_RC" -eq 1 ]]; then
      echo "   ✔ the play finished after ${WAITED}s"
      echo ""
      __await_tail
      exit 0
    fi

    if [[ "$LAST" != "busy" ]]; then
      echo "   • ${WAITED}s — the play runs (pid ${PIDS//$'\n'/ })"
      LAST="busy"
    fi

    __await_nap
    continue
  fi

  ####################################################################
  # the coarse path: ask the pane, and say that it is coarse
  ####################################################################
  RUNNING="$(__duct_pane_command)"

  # ⚠️ an EMPTY answer is not idle. tmux could not be asked — the tunnel is down,
  #    the session is gone — and to read that as "finished" would report a play
  #    complete that never ran (rule.forbid.failhide). ductwork's own read makes
  #    the same distinction at src/grove.provision/2.shell/2.7.aliases/ductwork.sh:533
  if [[ -z "$RUNNING" ]]; then
    echo "   💥 MalfunctionError: tmux did not answer, so the pane's state is unknown" >&2
    echo "      ⇒ the tunnel may be down, or the session gone" >&2
    echo "      fix: rhx git.grove.wake $GROVE" >&2
    exit 1
  fi

  if __duct_pane_is_idle "$RUNNING"; then
    # ⚠️ `bash` is the ambiguous answer: a play runs AS bash, so this cannot tell
    #    "finished" from "still cloning". it is reported as a guess rather than a
    #    verdict — the alternative is the ✔ that lied three times on 2026-08-06
    if [[ "$RUNNING" == "bash" || "$RUNNING" == "-bash" ]]; then
      echo "   🌙 the pane reports '$RUNNING' after ${WAITED}s — this may mean done,"
      echo "      or a play still running, and this probe cannot tell them apart"
      echo "      ⇒ re-run with --play <name> for an answer rather than a guess"
      echo ""
      # a guess is no verdict, so it never exits 0
      __await_tail
      exit 3
    fi
    echo "   ✔ idle after ${WAITED}s — the pane is back at '$RUNNING'"
    echo ""
    __await_tail
    exit 0
  fi

  # one line per poll, and only when the answer CHANGES, so a ten-minute wait
  # reads as a short list of states rather than forty identical lines
  if [[ "$RUNNING" != "$LAST" ]]; then
    echo "   • ${WAITED}s — busy with '$RUNNING'"
    LAST="$RUNNING"
  fi

  __await_nap
done

echo ""
echo "   🌙 still busy after ${WAITED}s — the play may simply need longer"
echo "      ⇒ this is a bound, not a verdict: raise it with --within"
echo ""
__await_tail
exit 3
