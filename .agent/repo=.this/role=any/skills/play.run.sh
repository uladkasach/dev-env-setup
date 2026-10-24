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
#   - every run is BOUNDED. a play that hangs fails; it never waits forever
#   - it runs the play in a subshell, so a `set -e`/`exit` inside it cannot
#     take this runner's own report with it
#
# usage:
#   rhx play.run --list
#   rhx play.run --play prove.nvim-fetches-no-unpinned-plugin
#   rhx play.run --play prove.linger-reaches-every-seat --within 600
#   rhx play.run --all
#
# options:
#   --play SLUG    the play to run. the `.play.sh` suffix is optional
#   --list         name every play in the index, each refused verb marked, then exit
#   --all          run every tracked play, one at a time, each under its own
#                  --within bound; then name each verdict. exit 0 only if
#                  every play passed
#   --resnap       rewrite each snap a play holds (`__snaps__/<play>/`) from
#                  this run. review the diff before you commit it
#   --within SECS  the bound on each play, in seconds (default 900)
#   -h, --help     show this header
#
# exit:
#   0 = the play passed
#   1 = the play failed, or malfunctioned
#   2 = a constraint: bad args, no such play, a forbidden verb, a decline, or a timeout
######################################################################
# rhachet injects `--skill NAME` (and `--repo` / `--role`) when invoked as
#   `rhx play.run …`; the parser absorbs and ignores each pair

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

# every flag this runner reads, named once for each refusal that must list them
VALID_FLAGS="--play <slug>, --list, --all, --resnap, --within <secs>, --help"

# .what = print a caller-fault header on stderr, then exit 2
_refuse() { echo "   ✋ ConstraintError: $1" >&2; shift; local l; for l in "$@"; do echo "      $l" >&2; done; exit 2; }

# .what = whether this runner drives a play of this verb (the verb is the contract, below)
_is_driven_verb() { case "$1" in prove.*|verify.*|diagnose.*|await.*|hibernate.*) return 0 ;; esac; return 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill|--repo|--role)
      # absorb rhachet's injected pair; guard the value shift so a bare
      # `--skill` at the end cannot eat the next real flag
      shift; [[ $# -gt 0 ]] && shift ;;
    --play)
      shift
      [[ $# -gt 0 ]] || _refuse "--play needs a value" "valid: $VALID_FLAGS"
      PLAY="$1"; shift ;;
    --within)
      shift
      [[ $# -gt 0 ]] || _refuse "--within needs a value" "valid: $VALID_FLAGS"
      WITHIN="$1"; shift ;;
    --list) LIST=1; shift ;;
    --all) ALL=1; shift ;;
    --resnap) export PLAY_RESNAP=1; shift ;;
    -h|--help)
      sed -n '/^# usage:/,/^#####/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'
      exit 0 ;;
    # ⚠️ an unknown flag HALTS. a swallowed narrowing flag returns a verdict
    #    about a subject the caller never named
    *) _refuse "unknown flag: $1" "valid: $VALID_FLAGS" ;;
  esac
done

if [[ -z "$ROOT" || ! -d "$PLAYDIR" ]]; then
  _refuse "no tracked play dir at ${PLAYDIR:-<no checkout>}" \
    "⇒ an empty set would report as a pass, so this halts instead"
fi

######################################################################
# --list. the DIR is the inventory, so this reads it rather than a list
######################################################################
if [[ "$LIST" -eq 1 ]]; then
  # ⚠️ the INDEX, to match what --play will accept. a disk glob here would
  #    ADVERTISE a play the runner then refuses — and worse, would print a
  #    grove-authored file beside the repo's own, which is how a human is
  #    invited to run it
  listed=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && listed+=("$(basename "$f" .play.sh)")
  done < <(git -C "$ROOT" ls-files -- '.play/permanent/*.play.sh' 2>/dev/null)
  echo "🎭 play.run --list"
  echo "   ├─ dir: $PLAYDIR"
  echo "   ├─ store: git ls-files (the INDEX, not the disk)"
  echo "   └─ ${#listed[@]} play(s)"
  [[ "${#listed[@]}" -gt 0 ]] || echo "      └─ (none)"
  # a verb this runner never drives is listed, since it IS in the index, and marked so
  for i in "${!listed[@]}"; do
    glyph="├─"; [[ "$i" -eq $(( ${#listed[@]} - 1 )) ]] && glyph="└─"
    note=""; _is_driven_verb "${listed[$i]}" || note="  (✋ refused — a verb this runner never drives)"
    echo "      $glyph ${listed[$i]}$note"
  done

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
    echo "" >&2
    _refuse "$u untracked .play.sh file(s) sit in that dir, unlisted" \
      "⇒ this runner refuses each of them. if one is yours, git add it;" \
      "  if it is not, read it — a pulled tree can write here" \
      "read them: git -C $ROOT status --short .play/permanent"
  fi
  exit 0
fi

######################################################################
# --all. each play runs through THIS runner, one at a time, so every gate
# below (the index, the verb, the bound) holds for each exactly as it does
# for a single --play. the set is the INDEX, the same set --list names
#
# ⚠️ a decline (exit 2) is NOT a pass: its subject was absent, so it proved
#    no claim. it is named on its own row and fails the whole run
######################################################################
if [[ "$ALL" -eq 1 ]]; then
  [[ -z "$PLAY" ]] || _refuse "--all and --play name two subjects; pick one"
  slugs=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && slugs+=("$(basename "$f" .play.sh)")
  done < <(git -C "$ROOT" ls-files -- '.play/permanent/*.play.sh' 2>/dev/null)
  [[ "${#slugs[@]}" -gt 0 ]] || _refuse "the index holds no play, and an empty set would report as a pass"
  passed=(); failed=(); declined=(); refused=()
  for slug in "${slugs[@]}"; do
    # a verb this runner never drives is refused here, by name, and never run
    _is_driven_verb "$slug" || { refused+=("$slug"); continue; }
    one_rc=0
    bash "${BASH_SOURCE[0]}" --play "$slug" --within "$WITHIN" || one_rc=$?
    echo ""
    case "$one_rc" in
      0) passed+=("$slug") ;;
      2) declined+=("$slug") ;;
      *) failed+=("$slug") ;;
    esac
  done

  # .what = one bucket row, its slugs nested beneath it; `$1` = this row's glyph, `$2` = the stem under it
  _bucket() {
    local glyph="$1" stem="$2" mark="$3" label="$4"; shift 4
    echo "   $glyph $label: $#"
    local i=0 n="$#" s g
    for s in "$@"; do
      i=$(( i + 1 )); g="├─"; [[ "$i" -eq "$n" ]] && g="└─"
      echo "   $stem  $g $mark $s"
    done
  }
  echo "🎭 play.run --all --within $WITHIN"
  echo "   ├─ passed: ${#passed[@]} of ${#slugs[@]}"
  _bucket "├─" "│" "💥" "failed" "${failed[@]}"
  _bucket "├─" "│" "✋" "declined or timed out" "${declined[@]}"
  _bucket "└─" " " "✋" "refused — a verb this runner never drives" "${refused[@]}"
  [[ "${#failed[@]}" -eq 0 && "${#declined[@]}" -eq 0 && "${#refused[@]}" -eq 0 ]] && exit 0
  echo "" >&2
  if [[ "${#failed[@]}" -gt 0 ]]; then
    echo "   💥 MalfunctionError: ${#failed[@]} play(s) failed" >&2
    echo "      read one again: rhx play.run --play <slug>" >&2
    exit 1
  fi
  _refuse "not every play passed: none failed, and some proved no claim" \
    "read one again: rhx play.run --play <slug>"
fi

[[ -n "$PLAY" ]] || _refuse "name a play: rhx play.run --play <slug>" "or: rhx play.run --list, rhx play.run --all"

######################################################################
# 🛑 the slug may not escape the tracked play dir
#
# ⚠️ a `/` in the slug is refused OUTRIGHT rather than stripped. to sanitize is
#    to guess what the caller meant; to refuse is to make them say it. and a
#    stripped `../` is the classic way a guard reads as present and is absent
######################################################################
case "$PLAY" in
  */*|..*|-*)
    _refuse "a play is named by SLUG, never by path: '$PLAY'" \
      "⇒ every play lives in $PLAYDIR, so a path adds no reach and" \
      "  would let this runner become a general shell" \
      "read what exists: rhx play.run --list" ;;
esac

PLAY="${PLAY%.play.sh}"
PLAY="${PLAY%.sh}"
TARGET="$PLAYDIR/$PLAY.play.sh"

if [[ ! -r "$TARGET" ]]; then
  _refuse "no play named '$PLAY'" "looked for: $TARGET" "read what exists: rhx play.run --list"
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
  _refuse "'$PLAY' is on disk and NOT in this repo's index" \
    "⇒ this runner executes only what the repo PUBLISHES, because a" \
    "  pulled tree can place a file here — .play/permanent is not in" \
    "  GROVE_BOUNDARY_EXCLUDES, and .play/temporary is" \
    "⇒ if you just wrote it, that is this check at work:" \
    "     git add .play/permanent/$PLAY.play.sh" \
    "⇒ if you did NOT write it, read it before you do aught else"
fi

######################################################################
# 🛑 the VERB is the contract. a play may READ, or it may PROVE
######################################################################
if ! _is_driven_verb "$PLAY"; then
  [[ "$PLAY" == repair.* ]] && _refuse "'$PLAY' is a repair play, and this repo has no such verb" \
    "⇒ a play that moves a box FORWARD toward the declared state is" \
    "  a BUNDLE (rule.forbid.repair-plays)" \
    "fix: rhx grove.provision --what <slug> --mode apply"
  _refuse "'$PLAY' does not name a verb this runner drives" \
    "⇒ allowed: prove.* verify.* diagnose.* await.* hibernate.*" \
    "⇒ the verb says what the play may do to the box, so an unnamed" \
    "  one carries no such promise"
fi

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
  _refuse "$PLAY did not finish within ${WITHIN}s, so it proved no claim" \
    "⇒ a bound that elapses is not a verdict about the subject" \
    "rerun with a wider bound: rhx play.run --play $PLAY --within 3600"
elif [[ "$rc" -eq 2 ]]; then
  _refuse "$PLAY declined — its subject is absent, so it proved no claim"
else
  echo "   💥 MalfunctionError: $PLAY failed (exit $rc)" >&2
  exit 1
fi
