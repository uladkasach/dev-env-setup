#!/usr/bin/env bash
######################################################################
# prove: an rc's `chpwd` hooks cannot pour bytes into a command substitution
#
# .what = two properties of `2.5.zsh/zshrc.sh`, which are one defect seen
#         from its two ends:
#
#           1. every OSC emitter writes to the TERMINAL, never to stdout
#           2. every `cd` inside a `$( )` or `( )` passes `-q`
#
# 🛑 .why a clamp and not a rule alone — measured 2026-09-14
#
#    the rc registered two `chpwd` hooks that `printf`ed their escape bytes to
#    STDOUT, and one line later `eval`ed a capture that ran `cd "$HOME"`. so the
#    hooks fired INSIDE the capture and their bytes were glued onto the front of
#    `pnpm completion zsh`'s output. the human saw this on every new terminal:
#
#      ✋ (eval):1: command not found: ^[]7
#      ✋ (eval):1: no such file or directory: file://<host>/<home>^G^[]2
#      ✋ (eval):1: command not found: ~^G#compdef
#
#    read the payloads and the cause is on the page: the OSC 7 body is the cwd
#    url, the OSC 2 title is `~`, and `#compdef` is pnpm's first line. three
#    unrelated producers, one string, RUN in the human's shell.
#
#    ⇒ a rule cannot hold this, because NEITHER HALF LOOKS WRONG ALONE. a hook
#      that prints to stdout is ordinary. a `cd` inside a capture is ordinary.
#      the defect exists only where the two meet, and that junction is invisible
#      at each site. so the reader must hold both halves at once — which is what
#      a play does and a paragraph does not.
#
# ⚠️ .the OSC sink is settled ONCE, not probed per emitter
#
#    `-w /dev/tty` is NOT a probe: `access(2)` reads the device node's mode bits,
#    which read `crw-rw-rw-` on a box with no ctty as readily as on one with. an
#    OPEN is the only thing that answers, and the rc opens it once at boot.
#    ⇒ so arm 2 accepts `>$_osc_sink` and `>/dev/tty`, and no third form.
#
# .the arms, and why NO ONE of them alone settles it
#   - arm 1 is a FIXTURE: it builds the defect in a throwaway zsh and watches it
#     reproduce, then watches the repair suppress it. it proves the MECHANISM
#     and says none of what this repo's rc does
#   - arm 2 is a LIVE read: every OSC emitter in the tracked rc names a sink
#   - arm 3 is a LIVE read: every `cd` inside a capture or subshell passes `-q`
#   ⇒ read all three in one run; accept no one of them alone
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q10)
#
# .the rows
#   F   the fixture did not reproduce the defect, so it proves no bite
#   S   an OSC emitter writes somewhere other than the settled sink
#   Q   a `cd` inside a capture or subshell omits `-q`
#
# guarantee:
#   - arm 1 writes ONLY inside its own `mktemp -d`, and removes it on exit
#   - arms 2 and 3 read one tracked file
#   - no network, no privilege, no remote reach — needs no grove, no credential
#   - arm 1 asserts the defect REPRODUCES first, so a fixture that silently
#     stopped to exercise it cannot pass by accident (`term=bite`)
#   - arms 2 and 3 DISCOVER their subjects, so a third emitter or a fifth `cd`
#     is caught the day it is written
#
# usage:
#   rhx play.run --play prove.rc-hooks-never-reach-a-capture
######################################################################
set -uo pipefail

FAILED=0
_fail() { FAILED=1; }

# ⚠️ the root leads with THIS FILE's location, never a hardcoded
#    `$HOME/git/more/dev-env-setup` — that names MAIN on every box, so a run
#    from a worktree would measure a tree under nobody's hand
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.provision._.sh" ]]; then _root="$_self"
elif [[ -f "$PWD/src/grove.provision._.sh" ]];                 then _root="$PWD"
else                                                                _root="$HOME/git/more/dev-env-setup"
fi

SUBJECT="$_root/src/grove.provision/2.shell/2.5.zsh/zshrc.sh"

echo ""
echo "🐢 prove: an rc's chpwd hooks never reach a capture"
echo "   ├─ subject : src/grove.provision/2.shell/2.5.zsh/zshrc.sh"
echo "   └─ root    : $_root"
echo ""

if [[ ! -f "$SUBJECT" ]]; then
  echo "   ✋ the subject is absent from this checkout" >&2
  echo "      looked at: $SUBJECT" >&2
  echo "      ⇒ this play measures a tracked file; an absent one is a defect" >&2
  exit 1
fi

######################################################################
# arm 1 — the FIXTURE. does the defect reproduce, and does the repair bite?
#
# ⚠️ a repair-only fixture proves obedience and says none of whether the subject
#    it obeyed was ever a hazard. so this asserts the BREAK first: with a bare
#    `cd` and a stdout emitter, the capture MUST hold the escape byte. only then
#    is a clean capture under the repair evidence of anything at all.
######################################################################
echo "   arm 1 — the fixture: reproduce, then repair"

if ! command -v zsh >/dev/null 2>&1; then
  echo "      🌙 zsh is absent here, so the fixture cannot run"
  echo "         ⇒ arms 2 and 3 are static and still hold below"
else
  _tmp="$(mktemp -d)" || { echo "   ✋ could not make a scratch dir" >&2; exit 1; }
  trap 'rm -rf "$_tmp"' EXIT

  # the BROKEN shape: a chpwd hook that prints to stdout, plus a bare `cd`
  broke="$(zsh -c '
    _emit() { printf "\e]7;probe\a" }
    chpwd_functions=(_emit)
    capture=$( cd "'"$_tmp"'"; echo PAYLOAD )
    printf "%s" "$capture"
  ' 2>/dev/null)"

  # the REPAIRED shape: the same hook, sunk to a non-stdout fd, plus `cd -q`
  fixed="$(zsh -c '
    _sink=/dev/null
    _emit() { printf "\e]7;probe\a" >$_sink }
    chpwd_functions=(_emit)
    capture=$( cd -q "'"$_tmp"'"; echo PAYLOAD )
    printf "%s" "$capture"
  ' 2>/dev/null)"

  if [[ "$broke" == "PAYLOAD" ]]; then
    echo "      ✋ F: the fixture did NOT reproduce the defect" >&2
    echo "         the broken shape captured a clean 'PAYLOAD'" >&2
    echo "         ⇒ so its clean run under the repair proves no bite, and this" >&2
    echo "           arm has measured an absent hazard for however long it stood" >&2
    echo "         fix: repair the fixture, never the assertion" >&2
    _fail
  elif [[ "$fixed" != "PAYLOAD" ]]; then
    echo "      ✋ F: the repaired shape still leaked into the capture" >&2
    echo "         captured: $(printf '%q' "$fixed")" >&2
    echo "         ⇒ a sink plus 'cd -q' is not sufficient on this zsh" >&2
    _fail
  else
    echo "      ✔ broken shape leaked $(( ${#broke} - 7 )) stray byte(s); repaired shape captured 'PAYLOAD' clean"
  fi
fi

echo ""

######################################################################
# arm 2 — LIVE: every OSC emitter names the settled sink
#
# the subjects are DISCOVERED, never listed, so a third emitter added tomorrow
# is read on the day it lands (`gotcha.a-check-that-cries-wolf-gets-silenced`,
# m.9 — one set, two readers, and the second is free to go stale)
######################################################################
######################################################################
# arm 1b — the LIVE box. does a capture with a `cd` in it come back CLEAN?
#
# 🛑 .why a grep cannot stand alone here, measured 2026-09-14
#
#    arm 2 below discovers OSC emitters by `printf .*\e]`, and arm 3 discovers
#    `cd` calls. between them they reached TWO of the rc's three stdout writers.
#    the third was `fnm use`, which is a `chpwd` hook, writes the node version
#    to stdout, and matches neither pattern:
#
#      $ zsh -ic true | wc -c
#      20
#
#    ⇒ both greps read ✔ over it. a pattern reaches the shapes its author could
#      see, and the author of a reader is the one reader who cannot see past it
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`, q11).
#
# ⇒ so this arm runs the INVARIANT rather than reads for its known shapes: a
#   real interactive zsh, a real capture, a real `cd`, and the payload must come
#   back with no byte in front of it. any hook that writes to stdout reddens
#   here whatever it is called and however it prints.
#
# ⚠️ it grades the INSTALLED rc, never the checkout — the same bound arm 1
#    carries. read a ✋ here as "THIS BOX leaks", then arms 2/3 for WHICH line.
######################################################################
echo "   arm 1b — a live capture with a cd in it comes back clean"

if ! command -v zsh >/dev/null 2>&1; then
  echo "      🌙 zsh is absent here, so no shell can be booted"
  echo "         ⇒ arms 2 and 3 are static and still hold below"
else
  # a dir every box holds, and one with no node pin, so this measures the RC's
  # own hooks rather than whatever a pinned tree would make fnm say
  _live="$(zsh -ic 'x=$( cd /tmp && echo PAYLOAD ); printf "%s" "$x"' 2>/dev/null)"

  if [[ "$_live" == *PAYLOAD ]] && [[ "$_live" == PAYLOAD ]]; then
    echo "      ✔ the capture held 'PAYLOAD' and no byte besides"
  else
    echo "      ✋ S: a live capture came back dirty" >&2
    echo "         captured: $(printf '%q' "$_live")" >&2
    echo "         ⇒ some hook in the rc writes to STDOUT, so every \$( ) that" >&2
    echo "           does a 'cd' swallows its bytes — and an eval of that runs" >&2
    echo "           them as commands" >&2
    echo "         fix: sink that hook to \$_osc_sink. arms 2 and 3 below name" >&2
    echo "              the two shapes already known; a third is a new shape" >&2
    _fail
  fi
fi

echo ""

echo "   arm 2 — every OSC emitter writes to the terminal, never stdout"

_osc_lines="$(grep -n "printf .*\\\\e\]" "$SUBJECT" || true)"

if [[ -z "$_osc_lines" ]]; then
  echo "      ✋ S: no OSC emitter found at all" >&2
  echo "         ⇒ this reader matched none, so it can never redden. that is a" >&2
  echo "           reader defect, not a clean rc (q11)" >&2
  _fail
else
  _osc_count=0
  _osc_bad=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    _osc_count=$(( _osc_count + 1 ))
    # the two accepted sinks, and no third form
    if [[ "$line" == *'>$_osc_sink'* || "$line" == *'>/dev/tty'* ]]; then
      continue
    fi
    echo "      ✋ S: an OSC emitter writes to stdout" >&2
    echo "         $line" >&2
    echo "         ⇒ any 'cd' inside a \$( ) pours these bytes into the capture" >&2
    echo "         fix: append '>\$_osc_sink' — the sink the rc settles at boot" >&2
    _osc_bad=1
    _fail
  done <<< "$_osc_lines"

  [[ "$_osc_bad" -eq 0 ]] && echo "      ✔ $_osc_count OSC emitter(s), each sunk to the terminal"
fi

echo ""

######################################################################
# arm 3 — LIVE: every `cd` inside a capture or subshell passes `-q`
#
# 🛑 `-q` suppresses `chpwd` and `chpwd_functions`. measured, never recalled:
#      bare cd  -> fired=1
#      cd -q    -> fired=1     ← the hook did not run
#
# ⚠️ it is the belt to arm 2's brace, and it closes a hazard the sink does NOT
#    reach: `_grove_fnm_use_on_cd` is a chpwd hook that would switch this
#    shell's node version mid-capture, from a `.nvmrc` the cwd chose.
######################################################################
echo "   arm 3 — every cd inside a capture or subshell passes -q"

# a `cd` that is inside `$( … )` or `( … )` — the shapes this rc uses
_cd_lines="$(grep -nE '\(\s*cd |\bcd "\$HOME"|\bcd -q "\$HOME"' "$SUBJECT" || true)"

if [[ -z "$_cd_lines" ]]; then
  echo "      ✋ Q: no 'cd' found at all" >&2
  echo "         ⇒ this reader matched none, so it can never redden (q11)" >&2
  _fail
else
  _cd_count=0
  _cd_bad=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # a comment line that merely QUOTES the banned form is prose, never a call
    _body="${line#*:}"
    [[ "$_body" =~ ^[[:space:]]*# ]] && continue
    _cd_count=$(( _cd_count + 1 ))
    [[ "$_body" == *'cd -q '* ]] && continue
    echo "      ✋ Q: a 'cd' omits -q" >&2
    echo "         $line" >&2
    echo "         ⇒ it re-fires every chpwd hook — the OSC emitters, the fnm" >&2
    echo "           version switch, and (at one site) ITSELF" >&2
    echo "         fix: 'cd -q'. this cwd is CONTAINMENT, never a place a human went" >&2
    _cd_bad=1
    _fail
  done <<< "$_cd_lines"

  [[ "$_cd_bad" -eq 0 ]] && echo "      ✔ $_cd_count cd call(s), each with -q"
fi

echo ""

if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the rc's hooks cannot reach a capture ✔"
else
  echo "✋ the rc's hooks can reach a capture" >&2
fi

exit "$FAILED"
