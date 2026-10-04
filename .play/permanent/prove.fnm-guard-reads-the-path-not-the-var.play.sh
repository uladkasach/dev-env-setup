#!/usr/bin/env bash
######################################################################
# .what = prove `~/.zshenv`'s fnm guard keys on the PATH ENTRY, never on
#         `FNM_MULTISHELL_PATH` alone — and still skips its mint for a
#         shell that genuinely inherits a reachable dir
#
# 🛑 .why a clamp, and not the comment beside the code
#
# 📜 measured 2026-09-30. the guard read the VAR, which is a PROXY for the
#    fact it needs (*is a usable multishell dir reachable?*). the two part
#    company in one reachable state:
#
#      FNM_MULTISHELL_PATH set  ∧  "$FNM_MULTISHELL_PATH/bin" NOT on PATH
#
#    a parent that exports the var and rebuilds PATH without it leaves that.
#    the var-only guard skipped the eval, so the dir never reached PATH, and
#    every `fnm use` thereafter spoke on stderr — at every boot of every
#    nested shell, which is every `$( )` a human writes.
#
# ⚠️ .why the extant clamps cannot see it
#    `prove.rc-is-quiet-on-boot` arm 0b FOUND it and named the wrong subject:
#    it boots a nested shell, so it could not part "the rc is broken" from
#    "my parent half-set the env" until it was taught to re-boot scrubbed
#    (`…cries-wolf`, m.4). that arm reports a SYMPTOM on one box.
#    ⇒ this play reads the GUARD, so it holds on a box whose parent happens
#      to be clean — the state in which the symptom is invisible.
#
# ⚠️ .the direction that matters most is arm 2
#    the var-only guard was not careless; it bought a real property, and the
#    reason is on the page at `zshenv.sh`: `fnm env` mints a FRESH per-shell
#    dir per call, so an unguarded eval forks once per nested shell and
#    litters `/run/user`. a fix that widened the guard into a no-op would
#    close this defect and re-open that one.
#    ⇒ so arm 1 proves the widen and arm 2 proves the BOUND, and neither
#      alone is the claim (`rule.require.a-cue-is-not-a-claim`).
#
# guarantee:
#   - READ-ONLY on this box's state. it sources the CHECKOUT's zshenv inside
#     throwaway subshells with a synthetic env; it writes no dotfile
#   - its one write is a `mktemp -d` fixture for arm 3, removed on EXIT
#   - it DECLINES (exit 2) where zsh or fnm is absent, rather than pass
######################################################################

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$HERE" || exit 1

ZSHENV="$HERE/src/grove.provision/2.shell/2.5.zsh/zshenv.sh"

echo "🌲 prove.fnm-guard-reads-the-path-not-the-var"
echo "   └─ subject: $ZSHENV"
echo ""

_fail=0

####################################################################
# the subject must exist, and the tools it needs must be here
#
# ⚠️ a decline, never a pass. an absent subject proves no claim
####################################################################
if [[ ! -r "$ZSHENV" ]]; then
  echo "   ✋ the checkout holds no zshenv at that path" >&2
  exit 2
fi
if ! command -v zsh >/dev/null 2>&1; then
  echo "   🌙 zsh is absent here, so the guard cannot be driven"
  echo "      ⇒ proves no claim; run this on a box that holds zsh"
  exit 2
fi
####################################################################
# 🛑 read the GUARD's own condition, never `fnm` on THIS shell's PATH
#
# 📜 caught on this play's first roll, 2026-09-30. it asked
#    `command -v fnm` and declined — because a play runs under a
#    NON-INTERACTIVE bash, where the rc that puts fnm on PATH never ran
#    (`gotcha.a-tool-found-by-path-answers-only-a-human`).
#
#    ⇒ and that is the very defect class this play grades: it read a PROXY
#      (fnm reachable from here) for the fact (fnm reachable from the guard).
#      the guard keys on `[ -x "$FNM_BIN_DIR/fnm" ]`, so this asks that
####################################################################
_FNM_BIN="${FNM_DIR:-$HOME/.local/share/fnm}/fnm"
if [[ ! -x "$_FNM_BIN" ]]; then
  echo "   🌙 no fnm binary at $_FNM_BIN, so the guard's own branch never fires"
  echo "      ⇒ proves no claim; run this on a converged box"
  exit 2
fi

####################################################################
# .the reader
#
# ⚠️ it asks the SHELL, never the text. a grep of the `case` line would
#    grade the shape of the guard and say none of what it does — and the
#    defect this play exists for was invisible in exactly that way
#
# 🛑 .`-f` is LOAD-BEARING — zsh reads `~/.zshenv` on EVERY invocation
#
# 📜 measured 2026-09-30, the hour the repaired guard first reached this
#    box. without `-f`, every reader below sources TWO copies of its own
#    subject: the live `~/.zshenv` that zsh reads before `-c` runs, then
#    the file the arm named. so each arm graded the composition, never
#    the subject — and the two agree on a converged box, which is why it
#    read green.
#
#    ⇒ arm 3 is where it SURFACED: the fixture plants the var-only guard
#      and demands a MISS, and the live repaired guard had already put a
#      reachable dir on PATH before the fixture was sourced at all. the
#      fixture reported REACHED, so the clamp said its own arm 1 proves
#      no claim (`…cries-wolf`, m.16 — the discriminator read another
#      subject).
#
#    ⚠️ and the direction matters: BEFORE the repair landed on this box,
#      the live `~/.zshenv` carried the var-only guard too, so it skipped
#      its mint and the contamination was INVISIBLE. a clamp whose reader
#      inherits the live copy of its subject is green exactly while the
#      box and the checkout agree — which is every hour but the one the
#      clamp exists for.
####################################################################
_reached_after_source() {   # $1 = the zshenv to source, $2 = the var value
  env FNM_MULTISHELL_PATH="$2" zsh -f -c "
    source '$1' 2>/dev/null
    case \":\$PATH:\" in
      *\":\$FNM_MULTISHELL_PATH/bin:\"*) echo REACHED ;;
      *) echo MISSED ;;
    esac
  " 2>/dev/null
}

####################################################################
# arm 1 — a var set with its bin dir OFF PATH must be REPAIRED
#
# this is the defect's own state. the guard must notice the dir is
# unreachable and mint one that is
####################################################################
echo "   arm 1 — a half-set env is repaired, not skipped"

_bogus="/nonexistent/fnm-multishell-$$"
_arm1="$(_reached_after_source "$ZSHENV" "$_bogus")"

if [[ "$_arm1" == "REACHED" ]]; then
  echo "      ✔ the guard re-minted, and the dir is on PATH"
else
  echo "      ✋ the guard SKIPPED its mint on a half-set env (got: ${_arm1:-<empty>})" >&2
  echo "         ⇒ every nested shell then carries an unreachable dir, and" >&2
  echo "           every 'fnm use' says so on stderr" >&2
  echo "         fix: key the guard on whether \"\$FNM_MULTISHELL_PATH/bin\" sits" >&2
  echo "              on PATH, never on whether the var is set" >&2
  _fail=1
fi
echo ""

####################################################################
# arm 2 — the BOUND. a var set with its bin dir ON PATH must be LEFT
#
# ⚠️ this is the property the var-only guard bought, and the one a
#    careless widen would spend: a genuinely nested shell inherits a
#    usable dir, so it must not fork `fnm env` again
####################################################################
echo "   arm 2 — a properly nested env is left alone (no re-mint)"

# ⚠️ `-f` for the same reason the reader above carries it: a live `~/.zshenv`
#    read before `-c` would mint first and overwrite the var this arm reads
_seen="$(env FNM_MULTISHELL_PATH="$_bogus" PATH="$_bogus/bin:$PATH" zsh -f -c "
  source '$ZSHENV' 2>/dev/null
  printf '%s' \"\$FNM_MULTISHELL_PATH\"
" 2>/dev/null)"

if [[ "$_seen" == "$_bogus" ]]; then
  echo "      ✔ the var survived, so no second per-shell dir was minted"
else
  echo "      ✋ the guard re-minted for a shell that already had a reachable dir" >&2
  echo "         expected: $_bogus" >&2
  echo "         read:     ${_seen:-<empty>}" >&2
  echo "         ⇒ that forks once per nested shell and litters /run/user" >&2
  echo "         fix: the guard must SKIP when the bin dir is already on PATH" >&2
  _fail=1
fi
echo ""

####################################################################
# arm 3 — the FIXTURE: the OLD guard must FAIL arm 1
#
# 🛑 a clamp never seen to redden is half proven
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, the corollary).
#    so plant the var-only guard into a throwaway copy and demand arm 1's
#    reader report MISSED over it
#
# ⚠️ the fixture dir is `mktemp -d`, never a fixed path in a shared /tmp
#    (`rule.forbid.fixed-paths-in-a-shared-tmp`)
####################################################################
echo "   arm 3 — the fixture: the var-only guard must MISS"

_fix="$(mktemp -d)" || { echo "   ✋ could not mint a fixture dir" >&2; exit 2; }
trap 'rm -rf "$_fix"' EXIT

_old="$_fix/zshenv.old-guard.sh"

# the var-only guard, in the smallest form that reproduces the defect.
# it carries the same two halves the real file does — the binary on PATH,
# then a mint — and differs in the mint's condition alone
{
  echo 'FNM_BIN_DIR="${FNM_DIR:-$HOME/.local/share/fnm}"'
  echo 'if [ -x "$FNM_BIN_DIR/fnm" ]; then'
  echo '  case ":$PATH:" in'
  echo '    *":$FNM_BIN_DIR:"*) ;;'
  echo '    *) export PATH="$FNM_BIN_DIR:$PATH" ;;'
  echo '  esac'
  echo '  if [ -z "${FNM_MULTISHELL_PATH:-}" ]; then'
  echo '    eval "$(fnm env --shell zsh)"'
  echo '  fi'
  echo 'fi'
  echo 'unset FNM_BIN_DIR'
} > "$_old"

_arm3="$(_reached_after_source "$_old" "$_bogus")"

if [[ "$_arm3" == "MISSED" ]]; then
  echo "      ✔ arm 1's reader catches the var-only guard"
else
  echo "      ✋ the fixture went through (got: ${_arm3:-<empty>})" >&2
  echo "         ⇒ arm 1 cannot see the defect it exists for, so its ✔ above" >&2
  echo "           proves no claim" >&2
  _fail=1
fi
echo ""

if [[ "$_fail" -ne 0 ]]; then
  echo "   ✋ the fnm guard does not hold its claim" >&2
  echo "      read why: src/grove.provision/2.shell/2.5.zsh/zshenv.sh, its" >&2
  echo "                'the guard reads the PATH ENTRY' block" >&2
  exit 1
fi

echo "🌲 the fnm guard keys on the dir it can reach, and mints no second one ✔"
