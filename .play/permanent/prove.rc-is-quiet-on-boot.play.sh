#!/usr/bin/env bash
######################################################################
# prove: an interactive rc prints NOT ONE byte to stdout on boot
#
# .what = one invariant, over every shell rc this repo installs:
#
#           a fresh interactive shell opens on an empty line.
#
#         a boot print is legal at exactly one grade — a human must ACT on the
#         line — and then it goes to `/dev/tty`, never to stdout.
#
# 🛑 .why a clamp and not a rule alone — measured 2026-09-14
#
#    `2.9.emoji/emoji.zsh` closed with five unconditional `print` lines, so
#    every terminal the human opened led with a wall of text they never asked
#    for:
#
#      🐢 emoji loaded
#         ├─ index : …/emoji.tsv (1580 emoji)
#         ├─ tab   : falls through to 'expand-or-complete'
#         …
#
#    ⇒ the author saw it once, at the moment they wrote it, and read it as
#      confirmation the module loaded. every reader after them reads it as
#      noise — and the author is the one reader who cannot see that, because
#      to them it was the point. a rule reaches an author who suspects; a
#      clamp reaches one who does not.
#
# ⚠️ .a delete is NOT the repair, and that is why the rule is about the SINK
#
#    those five lines were the module's only discoverability surface
#    (`rule.require.discoverability`). to delete them trades one defect for
#    another. they moved to `emoji --help`, which is where a human looks
#    (`rule.require.help-on-demand`).
#    ⇒ so this play forbids the BOOT print, never the text.
#
# ⚠️ .a TEST and a BUILD script may speak, and that is the reader's sharpest edge
#
#    `emoji.test.zsh` prints nine lines and `emoji.index.build.sh` prints twelve.
#    both are CORRECT: a human invoked each one and is owed its output. a reader
#    that globbed `*.zsh` would redden on both, and a check that argues against
#    correct code is the half that gets silenced — after which it protects
#    naught (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half).
#
#    ⇒ so the subject is the rc PAYLOAD — a file a shell SOURCES — never every
#      shell file in the dir.
#
# .the arms, and why NO ONE of them alone settles it
#   - arm 0  BOOTS a shell and counts stdout bytes. total reach across writers,
#     and it names no culprit
#   - arm 0b boots the same shell and reads STDERR. a different claim — a boot
#     ERROR, never a boot print — and arm 0 is blind to it by construction
#   - arm 1  is LIVE: no rc payload holds an unconditional stdout print
#   - arm 1b is LIVE: the payload list is COMPLETE — a list cannot report the
#     member nobody added, so the tree is walked and every file accounted for
#   - arm 2  is a FIXTURE: it plants the exact banner the repair removed and
#     watches the reader redden, so the reader is seen to DISCRIMINATE rather
#     than merely agree
#   ⇒ read all five in one run; accept no one of them alone
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q10)
#
# .the rows
#   B   an rc prints to stdout at boot, or the payload list is incomplete
#   F   the fixture's planted banner did not redden, so the reader proves no bite
#
# guarantee:
#   - arms 1 and 1b read tracked files only; they touch no box state
#   - arm 2 writes ONLY inside its own `mktemp -d`, and removes it on exit
#   - no network, no privilege, no remote reach — needs no grove, no credential
#   - arm 1b WALKS the tree, so an rc added tomorrow reddens the day it lands
#     rather than the day somebody remembers to edit a list
#
# usage:
#   rhx play.run --play prove.rc-is-quiet-on-boot
######################################################################
set -uo pipefail

FAILED=0
_fail() { FAILED=1; }

_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.provision._.sh" ]]; then _root="$_self"
elif [[ -f "$PWD/src/grove.provision._.sh" ]];                 then _root="$PWD"
else                                                                _root="$HOME/git/more/dev-env-setup"
fi

echo ""
echo "🐢 prove: an interactive rc is quiet on boot"
echo "   └─ root : $_root"
echo ""

######################################################################
# the RC PAYLOADS — a file an interactive shell SOURCES
#
# ⚠️ this is a SECOND declaration of a set the tree already holds: each bundle's
#    `configure.upsert.sh` copies its payload to a dotfile in `$HOME`, and that
#    copy is the ownership fact. a list beside it is free to drift — m.9, one
#    set and two readers, and the hand-written reader is always the stale one.
#
# ⇒ it is clamped the only way a two-list pair can be: arm 1b below walks EVERY
#   shell file under `2.shell/` and demands each be either an rc named here or a
#   file whose name says it is run rather than sourced. a sixth rc added to the
#   tree and not to this list reddens there.
#
# 🛑 .why a list at all, and not a walk of the `cp` lines
#    `2.5.zsh` copies via a variable — `cp "$rc_src" "$HOME/.zshrc"` — so the
#    source basename is not on the page at the copy site. a reader that walked
#    the `cp` calls would silently skip the one rc that matters most.
######################################################################
RCS=(
  "2.5.zsh/zshrc.sh"          # → ~/.zshrc
  "2.5.zsh/zshenv.sh"         # → ~/.zshenv
  "2.9.emoji/emoji.zsh"       # → ~/.zshrc.emoji.sh
  "2.7.aliases/bash_aliases.sh"   # → ~/.bash_aliases
  "2.7.aliases/ductwork.sh"       # → ~/.bash_aliases.ductwork.sh
  "2.7.aliases/termwork.sh"       # → ~/.bash_aliases.termwork.sh
  "2.7.aliases/brains.auth.sh"    # → ~/.bash_aliases.brains.auth.sh
)

# a file whose NAME says it is run rather than sourced — a bundle phase, a
# human-run test, a build procedure. each may speak, because a human invoked it.
#
# ⚠️ `git-credential-*` is the one row whose trigger is NOT "a human invoked it"
#    (`rule.require.exemptions-name-their-trigger`). git EXECS a credential
#    helper by name and READS ITS STDOUT for the `username=` / `password=`
#    lines, so its stdout is a machine contract rather than a boot print. to
#    hold it to the rc bar would forbid the only output it exists to produce.
#    ⇒ the git convention fixes the name, so the name IS the trigger — the same
#      shape as every other row here.
NOT_AN_RC='(^|/)(_\.sh|configure\.[a-z]+\.sh|provision\.[a-z]+\.sh|git-credential-[a-z-]+\.sh)$|\.test\.|\.build\.sh$'

######################################################################
# arm 0 — the LIVE END-TO-END measure. it has TOTAL reach and names no culprit
#
# 🛑 .why it exists, measured 2026-09-14
#
#    arms 1 and 1b are GREPS, and a grep reaches the shapes its author could
#    see. this play's pattern is `^(print|echo)`, and a third boot writer sat
#    right past it the whole time:
#
#      $ zsh -ic true | wc -c
#      20                        ← `fnm use` names the node version, on stdout
#
#    both static arms read ✔ over that. ⇒ a false ✔, which is the half a reader
#    has no way to distrust (`gotcha.a-check-that-cries-wolf-gets-silenced`,
#    q11 — "in how many forms is this subject written, and which does the
#    pattern match?").
#
# ⇒ this arm asks the SHELL, never the text. it boots a real interactive zsh and
#   counts the bytes on stdout. no pattern gap can hide from a byte count.
#
# ⚠️ .what it measures is the INSTALLED rc, never the checkout
#    that is a feature and a bound at once: it grades the box a human actually
#    types in, and on an unconverged box it grades a file this checkout does not
#    own. `2.5.zsh`'s configure.verify is what ties the two together, so read
#    this arm's ✋ as "THIS BOX is loud", then arms 1/1b to learn WHICH file.
#
# ⚠️ .why the two halves do not merge
#    arm 0 has total reach and names no culprit; arms 1/1b name a culprit and
#    have partial reach. neither is the other's superset, so both are kept
#    (`rule.require.a-cue-is-not-a-claim` — two cues cannot disagree, they can
#    only both miss or one catch).
######################################################################
echo "   arm 0 — a real interactive shell prints ZERO bytes to stdout"

if ! command -v zsh >/dev/null 2>&1; then
  echo "      🌙 zsh is absent here, so no shell can be booted"
  echo "         ⇒ arms 1, 1b and 2 are static and still hold below"
else
  _boot_bytes="$(zsh -ic true 2>/dev/null | wc -c)"
  if [[ "$_boot_bytes" -eq 0 ]]; then
    echo "      ✔ an interactive zsh opened on an empty line (0 bytes)"
  else
    echo "      ✋ B: an interactive zsh wrote $_boot_bytes byte(s) to stdout at boot" >&2
    echo "         what it said:" >&2
    zsh -ic true 2>/dev/null | sed 's/^/           /' >&2
    echo "         ⇒ every terminal the human opens leads with that, and any" >&2
    echo "           'cd' inside a \$( ) pours it into the capture" >&2
    echo "         fix: sink it to \$_osc_sink — it addresses a human at a" >&2
    echo "              terminal, and a capture is not one" >&2
    _fail
  fi
fi

echo ""

######################################################################
# arm 0b — the SAME boot, read on STDERR
#
# 🛑 .why a SECOND stream, measured 2026-09-14 — arm 0 above went GREEN on it
#
#    the repair for the `fnm use` writer put `>$_osc_sink` on that hook, and
#    left `_osc_sink` declared inside the rc's `[[ -t 1 ]]` block. under a pipe
#    that block is skipped, so the variable was unset and the redirect took an
#    EMPTY filename:
#
#      $ zsh -ic true | wc -c
#      _grove_fnm_use_on_cd:2: no such file or directory:
#      0
#
#    ⇒ the byte count read `0` and reported ✔. the shell spoke on the one
#      stream arm 0 discards, so a clamp authored the same day as the defect
#      let the defect straight through. that is q11 a second time, on a second
#      axis: arm 0's reach is total across WRITERS and partial across STREAMS.
#
# ⚠️ .it is a SEPARATE claim, never a widened arm 0
#    arm 0 forbids a boot PRINT — a line a human never asked for, on the stream
#    a capture swallows. this forbids a boot ERROR — a line the shell itself
#    emitted because the rc is broken. the two take OPPOSITE repairs (sink it
#    vs repair it), so one merged arm would redden correctly and then name the
#    wrong remedy for half its cases (`rule.require.a-cue-is-not-a-claim`).
#
# ⚠️ .an empty stderr is the bar, and it is deliberately strict
#    a converged box boots silent on both streams. a tool that warns here is
#    an exemption to argue for out loud, never one to grant by a loose pattern
#    (`rule.require.exemptions-name-their-trigger`).
######################################################################
echo "   arm 0b — that same shell writes no ERROR to stderr"

if ! command -v zsh >/dev/null 2>&1; then
  echo "      🌙 zsh is absent here, so no shell can be booted"
else
  _boot_err="$(zsh -ic true 2>&1 >/dev/null)"
  if [[ -z "$_boot_err" ]]; then
    echo "      ✔ an interactive zsh booted with no error on stderr"
  else
    echo "      ✋ B: an interactive zsh wrote to stderr at boot" >&2
    printf '%s\n' "$_boot_err" | sed 's/^/           /' >&2
    echo "         ⇒ the rc is broken, and arm 0 above cannot see it — a byte" >&2
    echo "           count on stdout reads ✔ while the shell says this" >&2
    echo "         fix: repair the line the message names. do NOT sink it —" >&2
    echo "              a sink hides a defect rather than repairs it" >&2
    _fail
  fi
fi

echo ""

echo "   arm 1 — the rc payloads are quiet"

_bad=0
_read=0
for _rel in "${RCS[@]}"; do
  _rc="$_root/src/grove.provision/2.shell/$_rel"
  if [[ ! -f "$_rc" ]]; then
    echo "      ✋ B: this list names '$_rel', which is absent from the tree" >&2
    echo "         ⇒ either it moved and this list did not, or it is gone" >&2
    _bad=1; _fail
    continue
  fi
  _read=$(( _read + 1 ))

  # an unconditional print: `print` or `echo` at column 0, with no redirect
  _hits="$(grep -nE '^(print|echo)\b' "$_rc" | grep -v '>' || true)"
  [[ -z "$_hits" ]] && continue

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "      ✋ B: $_rel prints to stdout at boot" >&2
    echo "         $line" >&2
    echo "         ⇒ every terminal the human opens leads with this" >&2
    echo "         fix: move it behind a '--help', or sink it to /dev/tty if a" >&2
    echo "              human must ACT on the line" >&2
    _bad=1
    _fail
  done <<< "$_hits"
done

if [[ "$_bad" -eq 0 ]]; then
  echo "      ✔ $_read rc payload(s) read, each quiet on boot:"
  printf '         · %s\n' "${RCS[@]}"
fi

echo ""

######################################################################
# arm 1b — is the list above COMPLETE?
#
# ⚠️ arm 1 is only as wide as its list, and a list cannot report the member
#    nobody added. so this walks the tree and demands every shell file be
#    accounted for: an rc named above, or a name that says it is RUN.
######################################################################
echo "   arm 1b — every shell file under 2.shell is accounted for"

_unaccounted=0
while IFS= read -r _f; do
  _rel="${_f#"$_root"/src/grove.provision/2.shell/}"

  # is it named above?
  _named=0
  for _r in "${RCS[@]}"; do [[ "$_rel" == "$_r" ]] && _named=1 && break; done
  [[ "$_named" -eq 1 ]] && continue

  # does its name say it is run rather than sourced?
  [[ "$_rel" =~ $NOT_AN_RC ]] && continue

  echo "      ✋ B: '$_rel' is neither a named rc nor a run-by-name file" >&2
  echo "         ⇒ if a shell SOURCES it, add it to RCS — arm 1 cannot see it" >&2
  echo "         ⇒ if a human RUNS it, its name must say so (*.test.*, *.build.sh)" >&2
  _unaccounted=1
  _fail
done < <(find "$_root/src/grove.provision/2.shell" -type f \( -name '*.sh' -o -name '*.zsh' \) 2>/dev/null | sort)

[[ "$_unaccounted" -eq 0 ]] && echo "      ✔ every shell file is a named rc or a run-by-name file"

echo ""

######################################################################
# arm 2 — the FIXTURE. is the reader seen to DISCRIMINATE?
#
# ⚠️ arm 1 is a grep, and a grep that matches no real shape reports ✔ forever.
#    so this plants the exact banner the repair removed and demands arm 1's
#    pattern find it. a pattern that has stopped to match reddens HERE rather
#    than goes quietly green up there (`term=bite`)
######################################################################
echo "   arm 2 — the fixture: a planted banner must redden"

_tmp="$(mktemp -d)" || { echo "   ✋ could not make a scratch dir" >&2; exit 1; }
trap 'rm -rf "$_tmp"' EXIT

cat > "$_tmp/planted.zsh" <<'PLANT'
if [[ -o interactive ]]; then
  _greet() { print "inside a function — legal, it is not a boot print" }
fi
print "🐢 planted banner"
echo "   └─ a second form, so the reader must catch both"
print "sunk, so legal" > /dev/tty
PLANT

_found="$(grep -nE '^(print|echo)\b' "$_tmp/planted.zsh" | grep -v '>' || true)"
_n="$(printf '%s' "$_found" | grep -c . || true)"

if [[ "$_n" -eq 2 ]]; then
  echo "      ✔ the reader caught both planted banners and spared the sunk line"
else
  echo "      ✋ F: the reader found $_n of the 2 planted banners" >&2
  printf '%s\n' "$_found" | sed 's/^/         /' >&2
  echo "         ⇒ arm 1's ✔ above proves no bite — it has been blind to this" >&2
  echo "           shape for however long it stood" >&2
  echo "         fix: repair arm 1's pattern, never this assertion" >&2
  _fail
fi

echo ""

if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 every rc is quiet on boot ✔"
else
  echo "✋ an rc speaks on boot" >&2
fi

exit "$FAILED"
