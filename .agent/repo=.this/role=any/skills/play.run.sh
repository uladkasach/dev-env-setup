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
#        tracked play still runs. the sentence used to read "must be TRACKED"
#        with no line that asked git anything at all — see the block at the
#        `--error-unmatch` check for the measurement
#   - every run is BOUNDED. a play that hangs fails; it never waits forever
#   - it runs the play in a subshell, so a `set -e`/`exit` inside it cannot
#     take this runner's own report with it
#
# usage:
#   rhx play.run --list
#   rhx play.run --play prove.nvim-fetches-no-unpinned-plugin
#   rhx play.run --play prove.git-alias-seam --within 600
#
# options:
#   --play SLUG    the play to run. the `.play.sh` suffix is optional
#   --list         name every play this box can run, then exit
#   --within SECS  total bound, in seconds (default 900)
#   --skill NAME   absorbed + ignored — rhachet injects this when invoked as
#                  `rhx play.run …`. same for --repo / --role
#   -h, --help     show this header
#
# exit:
#   0 = the play passed
#   1 = the play failed, or malfunctioned
#   2 = a constraint: bad args, no such play, a forbidden verb, or a timeout
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill|--repo|--role)
      # absorb rhachet's injected pair; guard the value shift so a bare
      # `--skill` at the end cannot eat the next real flag
      shift; [[ $# -gt 0 ]] && shift ;;
    --play)
      shift
      [[ $# -gt 0 ]] || { echo "   ✋ --play needs a value" >&2; exit 2; }
      PLAY="$1"; shift ;;
    --within)
      shift
      [[ $# -gt 0 ]] || { echo "   ✋ --within needs a value" >&2; exit 2; }
      WITHIN="$1"; shift ;;
    --list) LIST=1; shift ;;
    -h|--help)
      sed -n '/^# usage:/,/^#####/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'
      exit 0 ;;
    # ⚠️ an unknown flag HALTS. a swallowed narrowing flag returns a verdict
    #    about a subject the caller never named
    *)
      echo "   ✋ unknown flag: $1" >&2
      echo "      valid: --play <slug>  --list  --within <secs>  --help" >&2
      exit 2 ;;
  esac
done

if [[ -z "$ROOT" || ! -d "$PLAYDIR" ]]; then
  echo "   ✋ no tracked play dir at ${PLAYDIR:-<no checkout>}" >&2
  echo "      ⇒ an empty set would report as a pass, so this halts instead" >&2
  exit 2
fi

######################################################################
# --list. the DIR is the inventory, so this reads it rather than a list
######################################################################
if [[ "$LIST" -eq 1 ]]; then
  echo "🎭 play.run --list"
  echo "   ├─ $PLAYDIR"
  echo "   └─ store: git ls-files (the INDEX, not the disk)"
  n=0
  # ⚠️ the INDEX, to match what --play will accept. a disk glob here would
  #    ADVERTISE a play the runner then refuses — and worse, would print a
  #    grove-authored file beside the repo's own, which is how a human is
  #    invited to run it
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    printf '      %s\n' "$(basename "$f" .play.sh)"
    n=$(( n + 1 ))
  done < <(git -C "$ROOT" ls-files -- '.play/permanent/*.play.sh' 2>/dev/null)
  [[ "$n" -gt 0 ]] || echo "      (none)"
  echo ""
  echo "   $n play(s)"

  # ⚠️ an UNTRACKED play in that dir is absent from the list above, and silence
  #    about it is the failhide: it is either work in progress, or a file
  #    something else put there. say how many, and never which — a name printed
  #    here is the invitation this check exists to withhold
  u=0
  for f in "$PLAYDIR"/*.play.sh; do
    [[ -e "$f" ]] || continue
    git -C "$ROOT" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || u=$(( u + 1 ))
  done
  if [[ "$u" -gt 0 ]]; then
    echo "   ⚠️ and $u untracked .play.sh file(s) sit in that dir, unlisted" >&2
    echo "      ⇒ this runner refuses each of them. if one is yours, git add it;" >&2
    echo "        if it is not, read it — a pulled tree can write here" >&2
    echo "      read them:  git -C $ROOT status --short .play/permanent" >&2
    exit 2
  fi
  exit 0
fi

[[ -n "$PLAY" ]] || {
  echo "   ✋ name a play: rhx play.run --play <slug>   (or --list)" >&2
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
    echo "   ✋ a play is named by SLUG, never by path: '$PLAY'" >&2
    echo "      ⇒ every play lives in $PLAYDIR, so a path adds no reach and" >&2
    echo "        would let this runner become a general shell" >&2
    echo "      read what exists: rhx play.run --list" >&2
    exit 2 ;;
esac

PLAY="${PLAY%.play.sh}"
PLAY="${PLAY%.sh}"
TARGET="$PLAYDIR/$PLAY.play.sh"

if [[ ! -r "$TARGET" ]]; then
  echo "   ✋ no play named '$PLAY'" >&2
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
  echo "   ✋ '$PLAY' is on disk and NOT in this repo's index" >&2
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
    echo "   ✋ '$PLAY' is a repair play, and this repo has no such verb" >&2
    echo "      ⇒ a play that moves a box FORWARD toward the declared state is" >&2
    echo "        a BUNDLE (rule.forbid.repair-plays)" >&2
    echo "      fix: rhx grove.provision --what <slug> --mode apply" >&2
    exit 2 ;;
  *)
    echo "   ✋ '$PLAY' does not name a verb this runner drives" >&2
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
  echo "   ✋ $PLAY did not finish within ${WITHIN}s, so it proved no claim" >&2
  echo "      ⇒ a bound that elapses is not a verdict about the subject" >&2
  echo "      read it wider: rhx play.run --play $PLAY --within 3600" >&2
  exit 2
elif [[ "$rc" -eq 2 ]]; then
  echo "   ✋ $PLAY declined — its subject is absent, so it proved no claim" >&2
  exit 2
else
  echo "   ✋ $PLAY failed (exit $rc)" >&2
  exit 1
fi
