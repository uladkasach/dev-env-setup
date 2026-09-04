#!/usr/bin/env zsh
######################################################################
# .what = test the emoji widget's three gestures
#
# .why  = the widget rebinds TAB, ENTER and ':' — three of the most
#         reflexive keys in a shell. a regression there feels like the
#         shell itself broke, with no obvious culprit. so the
#         fall-through paths need as much coverage as the happy paths.
#
# .how  = stub `zle`, then call the widget functions directly with a
#         set LBUFFER. a zpty round-trip was tried first and rejected:
#         the pty echoes its own input, so assertions read the typed
#         keys rather than the result, and every case races on sleeps.
#         branch logic needs no real terminal.
#
# .who drives it
#         `2.9.emoji`'s CONFIGURE VERIFY runs this against the checkout's
#         own widget, so a broken gesture fails the phase rather than
#         land on a human's TAB key
#         (`rule.require.upgrade-entries-verify-themselves`).
#
# usage:
#   zsh src/emoji.test.zsh                # tests the widget beside it
#   zsh src/emoji.test.zsh /path/to/widget
#
# guarantee:
#   - asserts the buffer AND the zle fall-through target, so a "literal
#     colon" case proves the colon came from self-insert rather than
#     from the widget's own write
#   - exit 0 all pass, exit 1 any fail
######################################################################
emulate -L zsh
setopt err_return

######################################################################
# collocated with the widget it tests, per the ehmpathy test convention.
#
# ⚠️ `:A` resolves symlinks, so a symlinked caller would still find
#    emoji.zsh beside the REAL file rather than beside the link.
#
#    that is a property of `:A`, and NOT evidence that such a link
#    exists — one was tried. measured 2026-08-14: rhachet discovers
#    `.sh` only, so a `.agent/…/skills/emoji.test.zsh` symlink answered
#    `no skill "emoji.test" found`, while `emoji.get.sh` — created in
#    the same directory in the same minute — was found at once.
#
#    ⇒ so there is no `rhx emoji.test`. the two ways to run this are
#      the two under `usage`, and `2.9.emoji`'s configure verify is
#      what makes the first of them mandatory
######################################################################
WIDGET="${1:-${0:A:h}/emoji.zsh}"
if [[ ! -f $WIDGET ]]; then
  print -u2 "✋ no widget at $WIDGET"
  exit 2
fi

# stub zle BEFORE the source, so `zle -N` at load time is inert too.
# ZLE_CALL records the fall-through target, which is what must be
# right for TAB to stay trustworthy.
typeset -g ZLE_CALL=""
zle() {
  case "$1" in
    -N|-I) return 0 ;;
    reset-prompt) return 0 ;;
    *) ZLE_CALL="$1" ;;
  esac
}
bindkey() { return 0 }   # never touch the real keymap

typeset -g LBUFFER="" BUFFER="" CURSOR=0
source "$WIDGET" >/dev/null

# fzf needs a tty, so the multi-hit path cannot run headless. stub the
# picker to take the top rank — that still exercises the splice logic,
# which is where the risk is.
_emoji_pick() { read -r line; print -r -- "${line%%$'\t'*}" }

pass=0; fail=0

# .what = type $2 into an empty line, assert the buffer becomes $3
#         and that zle fell through to $4 (empty = handled inline)
check() {
  local name="$1" want="$2" wantzle="${3:-}"
  if [[ $LBUFFER == $want && $ZLE_CALL == $wantzle ]]; then
    print "   ├─ ✅ $name"
    pass=$(( pass + 1 ))   # not (( pass++ )) — that returns the PRE value,
                           # so the first increment exits 1 under err_return
  else
    print "   ├─ ⛔ $name"
    print "   │     buffer want [$want] got [$LBUFFER]"
    print "   │     zle    want [$wantzle] got [$ZLE_CALL]"
    fail=$(( fail + 1 ))
  fi
}

# simulate TAB pressed with $1 already typed
tab() { LBUFFER="$1"; ZLE_CALL=""; _emoji_tab }

# simulate ':' typed after $1 (self-insert stub appends the colon)
colon() {
  LBUFFER="$1"; ZLE_CALL=""
  _emoji_colon
  if [[ $ZLE_CALL == self-insert ]]; then
    LBUFFER="${LBUFFER}:"
  fi
  return 0   # a final `[[ ]] &&` would return 1 and trip err_return
}

# simulate Enter with $1 in the buffer
enter() { BUFFER="$1"; LBUFFER="$1"; ZLE_CALL=""; _emoji_accept; LBUFFER="$BUFFER" }

print "🐢 lets test the gestures"
print ""
print "🐚 widget test"

print "   ├─ gesture 1: tab"
tab ':turt';                check "  ':turt<TAB>' -> turtle"          '🐢'
tab ':zap';                 check "  ':zap<TAB>' -> high voltage"     '⚡'
tab 'echo :boom';           check "  mid-line insert keeps the rest"  'echo 💥'

print "   ├─ gesture 2: the second colon commits"
colon ':zap';               check "  ':zap:' -> high voltage"         '⚡'
colon ':turt';              check "  ':turt:' -> turtle"              '🐢'
colon 'echo :fire';         check "  mid-line, rest preserved"        'echo 🔥'

print "   ├─ gesture 3: enter runs the command"
enter ':zap';               check "  ':zap<Enter>' -> 'emoji zap'"    'emoji zap' 'accept-line'
enter ':turt';              check "  ':turt<Enter>' -> 'emoji turt'"  'emoji turt' 'accept-line'

print "   ├─ safety: these must stay literal"
# a literal colon MUST come from self-insert — that is the fall-through
# proof. an empty ZLE_CALL here would mean the widget wrote the colon
# itself, which would be a different (and unaudited) code path.
colon 'arn:aws';            check "  'arn:aws:' stays literal"        'arn:aws:'      'self-insert'
colon 'npm run test';       check "  'test:' stays literal"           'npm run test:' 'self-insert'
colon 'http';               check "  'http:' stays literal"           'http:'         'self-insert'
colon ':';                  check "  '::' stays literal"              '::'            'self-insert'
colon ':zzzznope';          check "  unknown name stays literal"      ':zzzznope:'    'self-insert'
enter ':qa!';               check "  ':qa!' runs as typed"            ':qa!'      'accept-line'
enter ':zzzznope';          check "  unknown name runs as typed"      ':zzzznope' 'accept-line'
enter 'npm run test:unit';  check "  a real command is untouched"     'npm run test:unit' 'accept-line'

print "   ├─ safety: tab still falls through"
tab 'ech';                  check "  'ech<TAB>' defers to completion" 'ech'  "$_EMOJI_PRIOR_TAB"
tab 'npm run test:un';      check "  mid-word colon defers"           'npm run test:un' "$_EMOJI_PRIOR_TAB"
tab ':zzzznope';            check "  unknown name defers"             ':zzzznope' "$_EMOJI_PRIOR_TAB"
tab '';                     check "  empty buffer defers"             ''     "$_EMOJI_PRIOR_TAB"

print "   └─ $pass passed, $fail failed"
(( fail == 0 ))
