#!/usr/bin/env bash
######################################################################
# .what = run a TRACKED play from `.play/permanent/`, on THIS box
#
# .why  every other way to reach a play is grove-shaped. `git.grove.send
#       --play` sends one down a duct, and `git.grove.play.await` waits on it —
#       so a play whose subject is the LAPTOP had no runner at all, and the
#       only way to drive one was a bare `bash .play/permanent/<x>.play.sh`.
#
#       ⇒ that is an ad-hoc command, and an ad-hoc command is exactly what this
#         repo forbids as a proof: it is unrecorded, unbounded, unaudited, and
#         it names its subject by a path a reader must retype correctly
#         (`rule.require.install-via-procedures`).
#
# 🛑 .why it refuses a play that WRITES
#       `rule.forbid.repair-plays` allows exactly two write shapes, and one of
#       them (`rollback.*`) lives in the GITIGNORED `.play/temporary/` — a
#       separate dir, so it is not reachable from `.play/permanent/` by
#       construction. the other is a discrimination probe, which is a `prove.*`.
#
#       ⇒ so this runner accepts the READ verbs plus `prove.*`, and refuses
#         `repair.*` by name. the verb is not decoration here; it is the
#         contract that says what the play may do to the box.
#
# ⚠️ .why the play is named by SLUG and not by path
#       a path is a second declaration of where plays live, retyped at every
#       call site. the dir is the inventory; this reads a slug against it, so a
#       moved dir breaks one line rather than every caller
#       (`rule.require.bundle-as-sole-declaration`).
#
# guarantee:
#   - the play must be a PATH THIS REPO PUBLISHES: under `.play/permanent/`, and
#     in git's INDEX. a path that escapes the dir is refused, so this cannot be
#     turned into a general shell; an untracked file in the dir is refused too,
#     so a pulled tree cannot plant one
#
#     🛑 and the word is PATH, never BYTES. this asks whether git tracks the
#        path; it does not ask whether the disk matches the index, so a MODIFIED
#        tracked play still runs — the block at the `--error-unmatch` check
#        carries the measurement, and the residue that word leaves open
#   - every run is BOUNDED. a play that hangs is stopped at --within and reads as a
#     timeout, exit 2; it never waits forever
#   - it runs the play in a subshell, so a `set -e`/`exit` inside it cannot
#     take this runner's own report with it
#
# usage:
#   rhx play.run --list
#   rhx play.run --play prove.nvim-fetches-no-unpinned-plugin
#   rhx play.run --play prove.git-alias-seam --within 600
#   rhx play.run --all
#
# options:
#   --play SLUG    the play to run. the `.play.sh` suffix is optional
#   --list         name every play this box can run, then exit
#   --all          run every play --list names, one verdict line each.
#                  it names its own set, so it takes no --play. it writes:
#                    .log/role=mechanic/skill=play.run/what=all/<stamp>.stdout.log
#                      the verdict tree; its last line is the tally
#                    .log/role=mechanic/skill=play.run/what=all/<stamp>/
#                      one log per play, its full output
#   --within SECS  bound per play, in seconds (default 900)
#   --skill NAME   absorbed + ignored — rhachet injects this when invoked as
#                  `rhx play.run …`. same for --repo / --role
#   -h, --help     show this header
#
# exit:
#   0 = passed
#         --play: the play passed
#         --all:  every play passed
#   1 = failed
#         --play: the play failed, or malfunctioned
#         --all:  at least one play failed
#         --all:  the runner could not read the index or write a log; no tally lands
#   2 = a constraint
#         any:    bad args, no such play, a forbidden verb
#         --play: the play declined, or ran past --within
#         --all:  none failed, and at least one declined or ran past --within
#         --all:  no log written — the index tracks no play, or a .play.sh sits outside it
######################################################################

set -uo pipefail

######################################################################
# 🛑 the checkout is derived from THIS FILE, never from the cwd
#    `rhx` guarantees no cwd, and `dox.verify` measured what that costs: three
#    runs of one command reported three different subjects, each with a ✔
######################################################################
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
PLAYDIR="$ROOT/.play/permanent"

PLAY=""
WITHIN=900
LIST=0
ALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill|--repo|--role)
      # absorb rhachet's injected pair; guard the value shift so a bare
      # `--skill` at the end cannot eat the next real flag
      shift; [[ $# -gt 0 ]] && shift ;;
    --play)
      shift
      [[ $# -gt 0 ]] || { echo "   ✋ ConstraintError: --play needs a value" >&2; exit 2; }
      PLAY="$1"; shift ;;
    --within)
      shift
      [[ $# -gt 0 ]] || { echo "   ✋ ConstraintError: --within needs a value" >&2; exit 2; }
      # ⚠️ whole seconds, at least 1. `timeout` reads 0 as "no bound" and a bad value as its
      #    own fault, which every play would then be blamed for
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || {
        echo "   ✋ ConstraintError: --within takes whole seconds, at least 1 — got '$1'" >&2
        echo "      fix: --within 900" >&2
        exit 2
      }
      WITHIN="$1"; shift ;;
    --list) LIST=1; shift ;;
    --all)  ALL=1; shift ;;
    -h|--help)
      sed -n '/^# usage:/,/^#####/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'
      exit 0 ;;
    # ⚠️ an unknown flag HALTS. a swallowed narrowing flag returns a verdict
    #    about a subject the caller never named
    *)
      echo "   ✋ ConstraintError: unknown flag: $1" >&2
      echo "      valid: --play <slug>  --list  --all  --within <secs>  --help" >&2
      exit 2 ;;
  esac
done

if [[ -z "$ROOT" || ! -d "$PLAYDIR" ]]; then
  # with no checkout, PLAYDIR reads `/.play/permanent` — a path no one asked about
  where="${ROOT:+$PLAYDIR}"
  echo "   ✋ ConstraintError: no tracked play dir at ${where:-<no checkout>}" >&2
  echo "      ⇒ an empty set would report as a pass, so this halts instead" >&2
  exit 2
fi

######################################################################
# the operations --list and --all share
######################################################################
# .what = a path, relative to the checkout, for a human to read
as_repo_path() { printf '%s' "${1#"$ROOT"/}"; }

# .what = the tracked plays, one repo path per line
# .why  = a git that cannot answer is a fault, never an empty suite. `:(glob)` keeps `*` inside
#         one dir — a bare pathspec `*` crosses `/`, and would list a nested play `--play` refuses.
#         `quotePath=off` prints a non-ascii name as it sits on disk; quoted, it would match no
#         file, and a tracked play would count as untracked
# .note = git's own words land UNDER the fault as `git said:`, never above it at column 0: the
#         list goes out on fd 3, the stderr into `said`. a success that warned still says so
get_tracked_plays() {
  local said line
  { said="$(git -C "$ROOT" -c core.quotePath=off ls-files -- ':(glob).play/permanent/*.play.sh' 2>&1 1>&3)"; } 3>&1 \
    && { [[ -z "$said" ]] || while IFS= read -r line; do echo "   git said: $line" >&2; done <<< "$said"; return 0; }
  echo "   💥 MalfunctionError: git could not read the index at $ROOT, so no set of plays can be named" >&2
  while IFS= read -r line; do echo "      git said: $line" >&2; done <<< "$said"
  echo "      read it: git -C $ROOT ls-files .play/permanent" >&2
  exit 1
}

# .what = how many .play.sh files sit in the dir and are NOT in the tracked set
#         ($1, one repo path per line, from get_tracked_plays)
# .why  = the runner refuses each of them, so a set that holds one is not the set it publishes.
#         it reads the set git already answered for, so a git fault cannot pose as "untracked"
count_untracked_plays() {
  local f u=0
  for f in "$PLAYDIR"/*.play.sh; do
    [[ -e "$f" ]] || continue
    grep -qxF -- "$(as_repo_path "$f")" <<< "$1" || u=$(( u + 1 ))
  done
  echo "$u"
}

# .what = name the untracked plays by COUNT, never by name, then halt
emit_untracked_refusal() {
  echo "   ✋ ConstraintError: $1 untracked .play.sh file(s) sit in .play/permanent, outside the index" >&2
  echo "      ⇒ this runner refuses each of them. if one is yours, git add it;" >&2
  echo "        if it is not, read it — a pulled tree can write here" >&2
  echo "      read them: git -C $ROOT status --short .play/permanent" >&2
  exit 2
}

######################################################################
# --list. the DIR is the inventory, so this reads it rather than a list
######################################################################
if [[ "$LIST" -eq 1 ]]; then
  # a second subject would be swallowed silently, and a caller who asked for a run would get a list
  [[ "$ALL" -eq 0 && -z "$PLAY" ]] || { echo "   ✋ ConstraintError: --list names the set and runs none, so it takes no --all or --play; pick one" >&2; exit 2; }
  # ⚠️ the INDEX, to match what --play will accept. a disk glob here would
  #    ADVERTISE a play the runner then refuses — and worse, would print a
  #    grove-authored file beside the repo's own, which is how a human is
  #    invited to run it. a git that cannot answer halts inside get_tracked_plays,
  #    BEFORE the header, so its fault stands alone as --all's does
  tracked="$(get_tracked_plays)" || exit $?
  echo "🎭 play.run --list"
  echo "   ├─ $PLAYDIR"
  echo "   └─ store: git ls-files (the INDEX, not the disk)"
  n=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    printf '      %s\n' "$(basename "$f" .play.sh)"
    n=$(( n + 1 ))
  done <<< "$tracked"
  [[ "$n" -gt 0 ]] || echo "      (none)"
  echo ""
  echo "   $n play(s)"

  # ⚠️ an UNTRACKED play in that dir is absent from the list above, and silence
  #    about it is the failhide: it is either work in progress, or a file
  #    something else put there. say how many, and never which — a name printed
  #    here is the invitation this check exists to withhold
  u="$(count_untracked_plays "$tracked")"
  [[ "$u" -gt 0 ]] && { echo ""; emit_untracked_refusal "$u"; }
  exit 0
fi

######################################################################
# --all. the suite, one verdict per play
#
# ⚠️ .why each play goes back through THIS runner, by slug
#      the index check and the verb check are this file's contract. a loop that
#      ran `bash <file>` would skip both, so it calls `--play` and inherits them
#
# ⚠️ .why a declined play is never folded into "passed"
#      a decline proved no claim. three counts, never two
#
# ⚠️ .why the verdict lands at `what=all/<stamp>.stdout.log`, flat
#      a ship report reads a tree's newest `what=<x>/<ts>.stdout.log` — the shape
#      `git.repo.test` leaves too — and takes its last tally line as the verdict. so the file
#      holds the verdict tree and ENDS at the tally. the coda and the stderr refusals stay on the
#      terminal; a plain tee would end every red run's log on a blank line
#
# 🛑 .why every refusal here halts BEFORE a log, or names the log it could not finish
#      a reader takes the newest log's last line as the verdict. a log that ends short of the
#      tally reads as no verdict, so each fault below is named for its true cause, never
#      folded into a neighbour's — a full disk must never read as "every stamp taken"
######################################################################
LOGROOT="$ROOT/.log/role=mechanic/skill=play.run/what=all"
TRIES=5

# .what = make the log root, or name why it cannot be made or written, then halt
# .why  = two causes, two fixes: a path that cannot be made wants its parents read; a dir that
#         cannot be written wants its mode
gen_logroot() {
  if ! mkdir -p "$LOGROOT" 2>/dev/null; then
    echo "   💥 MalfunctionError: could not make the log dir $(as_repo_path "$LOGROOT"), so no verdict can land" >&2
    echo "      fix: read that path and its parents — a file may hold the name, or a parent be read-only:" >&2
    echo "        ls -ld $LOGROOT $(dirname "$LOGROOT")" >&2
    exit 1
  fi
  [[ -w "$LOGROOT" ]] && return 0
  echo "   💥 MalfunctionError: the log dir $(as_repo_path "$LOGROOT") cannot be written, so no verdict can land" >&2
  echo "      fix: make it writable by $(id -un), then rerun:" >&2
  echo "        chmod u+w $LOGROOT" >&2
  exit 1
}

# .what = a utc stamp, in the shape `git.repo.test` names its logs by
as_stamp_now() { date -u +%Y-%m-%dT%H-%M-%SZ; }

# .what = true if any file, dir, or link holds the name — a broken link included
is_name_held() { [[ -e "$1" || -L "$1" ]]; }

# .what = name a fault of the stamp claim, then halt
emit_claim_fault() {
  local line
  echo "   💥 MalfunctionError: $1" >&2
  # a tool's own words land under the fault, never at column 0 above it
  [[ -n "${2:-}" ]] && while IFS= read -r line; do echo "      rmdir said: ${line#rmdir: }" >&2; done <<< "$2"
  echo "      fix: read the disk, the dir's mode, and the path limit, then rerun:" >&2
  echo "        df -h $LOGROOT; ls -ld $LOGROOT; getconf PATH_MAX $LOGROOT" >&2
  exit 1
}

# .what = claim a free stamp: its per-play dir by `mkdir`, then its log by noclobber. prints it
# .why  = `mkdir` makes the dir or fails, never both, so two runs in one second cannot both
#         win (posix). noclobber then keeps an orphan log — one whose dir was removed — from an
#         overwrite. a refusal is judged by what holds the name: another run's dir or log is a
#         collision, so the next second is tried; no holder means a fault, named at once. the
#         tries are BOUNDED: a window whose every stamp is held is a defect, never a wait
claim_stamp() {
  local try cand dir log made said
  for (( try = 1; try <= TRIES; try++ )); do
    (( try > 1 )) && sleep 1
    cand="$(as_stamp_now)"; dir="$LOGROOT/$cand"; log="$LOGROOT/$cand.stdout.log"
    made=0
    mkdir "$dir" 2>/dev/null && made=1
    if (( made )) && ( set -C; : > "$log" ) 2>/dev/null; then echo "$cand"; return 0; fi
    if (( made )) && ! said="$(rmdir "$dir" 2>&1)"; then emit_claim_fault "could not remove this run's own claim $(as_repo_path "$dir")/" "$said"; fi
    is_name_held "$dir" && continue
    is_name_held "$log" && continue
    (( made )) && emit_claim_fault "could not create $(as_repo_path "$log") after its dir claim won, and no other run holds that name"
    emit_claim_fault "could not claim $(as_repo_path "$dir")/, and no other run holds that name"
  done
  echo "   💥 MalfunctionError: no free stamp under $(as_repo_path "$LOGROOT") after $TRIES tries, one per second" >&2
  echo "      ⇒ every stamp in that window was taken, and a taken log is never overwritten" >&2
  echo "      fix: read that dir, then rerun — a peer run may write there in a loop, or stale logs" >&2
  echo "        with no dir beside them may hold each stamp, and are yours to remove:" >&2
  echo "        ls -la $LOGROOT" >&2
  exit 1
}

# .what = print a verdict line, and append it to the verdict log
# .why  = the log must hold what the human saw. an append that fails would end the log short of
#         its tally, so the run halts and names the log rather than report a verdict it lost
say() {
  local log="$1" line="$2"
  echo "$line"
  { printf '%s\n' "$line" >> "$log"; } 2>/dev/null && return 0
  echo "" >&2
  echo "   💥 MalfunctionError: could not append to $(as_repo_path "$log"), so it ends short of its tally" >&2
  echo "      fix: read the disk and the log's mode, then rerun:" >&2
  echo "        df -h $LOGROOT; ls -l $log" >&2
  exit 1
}

# .what = run one play back through this runner, its output to its own log. prints its exit
# .why  = a log that could not be written is a fault of the run, never a failure of the play.
#         the group's stderr holds only a failed redirect, since the play's own goes to its log;
#         it is named below by the absent log, so bash's raw line is dropped. stdin is
#         /dev/null, so a play that reads it ends at once rather than wait on a human
run_one_play() {
  local slug="$1" log="$2" prc=0
  { bash "${BASH_SOURCE[0]}" --play "$slug" --within "$WITHIN" < /dev/null > "$log" 2>&1; } 2>/dev/null || prc=$?
  if [[ -e "$log" ]]; then echo "$prc"; return 0; fi
  echo "" >&2
  echo "   💥 MalfunctionError: could not write $(as_repo_path "$log"), so $slug never ran" >&2
  echo "      fix: read the disk and the dir's mode, then rerun:" >&2
  echo "        df -h $LOGROOT; ls -ld $(dirname "$log")" >&2
  exit 1
}

# .what = the tally — the LAST line the verdict log gets, which a reader takes as the verdict
as_tally_line() { printf '      └─ %s passed · %s declined · %s failed' "$1" "$2" "$3"; }

if [[ "$ALL" -eq 1 ]]; then
  [[ -z "$PLAY" ]] || { echo "   ✋ ConstraintError: --all and --play name two subjects; pick one" >&2; exit 2; }

  # the set: the index, whole. git that cannot answer halts inside get_tracked_plays
  tracked="$(get_tracked_plays)" || exit $?

  # 🛑 an empty index halts, before any log. a `0 passed · 0 declined · 0 failed` tally reads
  #    green to a reader, and a suite of zero plays proved naught
  if [[ -z "$tracked" ]]; then
    echo "   ✋ ConstraintError: no tracked play under .play/permanent, so --all has no suite to run" >&2
    echo "      ⇒ an empty run would pass and prove no claim" >&2
    echo "      read the index: git -C $ROOT ls-files .play/permanent" >&2
    echo "      fix: git -C $ROOT add .play/permanent/<slug>.play.sh, then rerun" >&2
    exit 2
  fi

  # 🛑 an untracked play halts too, before any log: a green tally beside a play this runner
  #    refuses would report a set it does not publish
  untracked="$(count_untracked_plays "$tracked")"
  [[ "$untracked" -gt 0 ]] && emit_untracked_refusal "$untracked"

  # the set, one play per element. the index is non-empty here, so no blank element
  plays=()
  while IFS= read -r f; do plays+=("$f"); done <<< "$tracked"

  # the suite's logs land in the checkout's gitignored `.log/`, where a ship report reads them
  gen_logroot
  stamp="$(claim_stamp)" || exit $?
  logdir="$LOGROOT/$stamp"
  stdoutlog="$LOGROOT/$stamp.stdout.log"

  say "$stdoutlog" "🎭 play.run --all --within $WITHIN"
  say "$stdoutlog" "   ├─ verdict: $(as_repo_path "$stdoutlog")"
  say "$stdoutlog" "   ├─ plays: $(as_repo_path "$logdir")/"
  say "$stdoutlog" "   └─ verdicts"
  passed=0; declined=0; failed=0
  for f in "${plays[@]}"; do
    slug="$(basename "$f" .play.sh)"
    prc="$(run_one_play "$slug" "$logdir/$slug.log")" || exit $?
    case "$prc" in
      0) passed=$(( passed + 1 ));     say "$stdoutlog" "      ├─ ✔ $slug" ;;
      2) declined=$(( declined + 1 )); say "$stdoutlog" "      ├─ 🌙 $slug — declined or timed out" ;;
      *) failed=$(( failed + 1 ));     say "$stdoutlog" "      ├─ 💥 $slug — failed (exit $prc)" ;;
    esac
  done
  say "$stdoutlog" "$(as_tally_line "$passed" "$declined" "$failed")"
  echo ""
  [[ "$failed" -gt 0 ]] && { echo "   💥 MalfunctionError: $failed play(s) failed — read each log under $(as_repo_path "$logdir")/" >&2; exit 1; }
  [[ "$declined" -gt 0 ]] && { echo "   ✋ ConstraintError: $declined play(s) declined or timed out, so proved no claim — read each log under $(as_repo_path "$logdir")/" >&2; exit 2; }
  echo "🌲 every play passed"
  exit 0
fi

[[ -n "$PLAY" ]] || {
  echo "   ✋ ConstraintError: name a play: rhx play.run --play <slug>   (or --list, or --all)" >&2
  exit 2
}

######################################################################
# 🛑 the slug may not escape the tracked play dir
#
# ⚠️ a `/` in the slug is refused OUTRIGHT rather than stripped. to sanitize is
#    to guess what the caller meant; to refuse is to make them say it. and a
#    stripped `../` is the classic way a guard reads as present and is absent
######################################################################
case "$PLAY" in
  */*|..*|-*)
    echo "   ✋ ConstraintError: a play is named by SLUG, never by path or flag: '$PLAY'" >&2
    echo "      ⇒ every play lives in $PLAYDIR, so a path adds no reach and" >&2
    echo "        would let this runner become a general shell" >&2
    echo "      read what exists: rhx play.run --list" >&2
    exit 2 ;;
esac

PLAY="${PLAY%.play.sh}"
PLAY="${PLAY%.sh}"
TARGET="$PLAYDIR/$PLAY.play.sh"

if [[ ! -r "$TARGET" ]]; then
  echo "   ✋ ConstraintError: no play named '$PLAY'" >&2
  echo "      looked for: $TARGET" >&2
  echo "      read what exists: rhx play.run --list" >&2
  exit 2
fi

######################################################################
# 🛑 the INDEX decides, never the disk
#
# 📜 measured 2026-09-03, redteam round 23. this file's `guarantee:` block said
#   the play must be TRACKED, and no line here asked git a question — the word
#   appeared three times and was measured zero times. the runner executed DISK
#   bytes while its contract named INDEX bytes
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`, q13: which STORE did this
#   consult, and does the subject have more than one?).
#
# ⚠️ .why the gap is reachable, and not theoretical
#   `.play/temporary` is in `GROVE_BOUNDARY_EXCLUDES`. `.play/permanent` is NOT.
#   so on this repo's own documented round trip — push a tree to a grove, work
#   there, `git.grove.pull` it back — a grove-authored `.play/permanent/*.play.sh`
#   lands in the checkout, prints in `--list` beside the real plays, and runs as
#   the human's uid on the box that holds the keyrack.
#
# 🛑 .the residue, stated rather than hidden — this closes HALF
#   `--error-unmatch` answers *is this PATH in the index*. it never answers
#   *does the index hold what is on DISK*. so a MODIFIED tracked play still
#   runs. the honest claim after this check is "the runner executes only paths
#   this repo publishes", never "only bytes this repo published". the tractable
#   home for the second half is a commit-time gate, not a sweep
#   (`inventory.security-checks.md` reaches the same conclusion).
#
# ⚠️ .and it reddens on a play not yet added, which is the safe direction — so
#   the refusal must NAME the `git add`, or it becomes a false ✋ that gets
#   silenced (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.13)
######################################################################
if ! git -C "$ROOT" ls-files --error-unmatch -- "$TARGET" >/dev/null 2>&1; then
  echo "   ✋ ConstraintError: '$PLAY' is on disk and NOT in this repo's index" >&2
  echo "      ⇒ this runner executes only what the repo PUBLISHES, because a" >&2
  echo "        pulled tree can place a file here — .play/permanent is not in" >&2
  echo "        GROVE_BOUNDARY_EXCLUDES, and .play/temporary is" >&2
  echo "      ⇒ if you just wrote it, that is this check at work:" >&2
  echo "           git add .play/permanent/$PLAY.play.sh" >&2
  echo "      ⇒ if you did NOT write it, read it before you do aught else" >&2
  exit 2
fi

######################################################################
# 🛑 the VERB is the contract. a play may READ, or it may PROVE
######################################################################
case "$PLAY" in
  prove.*|verify.*|diagnose.*|await.*|hibernate.*) : ;;
  repair.*)
    echo "   ✋ ConstraintError: '$PLAY' is a repair play, and this repo has no such verb" >&2
    echo "      ⇒ a play that moves a box FORWARD toward the declared state is" >&2
    echo "        a BUNDLE (rule.forbid.repair-plays)" >&2
    echo "      fix: rhx grove.provision --what <slug> --mode apply" >&2
    exit 2 ;;
  *)
    echo "   ✋ ConstraintError: '$PLAY' does not name a verb this runner drives" >&2
    echo "      ⇒ allowed: prove.* verify.* diagnose.* await.* hibernate.*" >&2
    echo "      ⇒ the verb says what the play may do to the box, so an unnamed" >&2
    echo "        one carries no such promise" >&2
    exit 2 ;;
esac

######################################################################
# drive it
#
# ⚠️ .why `timeout -k` and not `timeout` alone
#      `timeout` sends TERM, and a play blocked on a wedged child may not act
#      on one. the kill-after is what makes the bound real.
#
# ⚠️ .why `bash` and not `source`
#      a play is a program with its own `set -e` and its own `exit`. sourced,
#      its `exit` would end THIS runner before it could report a verdict
######################################################################
echo "🎭 play.run --play $PLAY --within $WITHIN"
echo "   └─ $TARGET"
echo ""

rc=0
timeout -k 15 "$WITHIN" bash "$TARGET" || rc=$?

echo ""
if [[ "$rc" -eq 0 ]]; then
  echo "🌲 $PLAY ✔"
elif [[ "$rc" -eq 124 || "$rc" -eq 137 ]]; then
  echo "   ✋ ConstraintError: $PLAY did not finish within ${WITHIN}s, so it proved no claim" >&2
  echo "      ⇒ a bound that elapses is not a verdict about the subject" >&2
  echo "      read it wider: rhx play.run --play $PLAY --within 3600" >&2
  exit 2
elif [[ "$rc" -eq 2 ]]; then
  echo "   ✋ ConstraintError: $PLAY declined — its subject is absent, so it proved no claim" >&2
  exit 2
else
  echo "   💥 MalfunctionError: $PLAY failed (exit $rc)" >&2
  exit 1
fi
