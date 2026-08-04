#!/usr/bin/env zsh
######################################################################
# .what = the inline TAB widget + the `emoji` command
#
# .why  = this is the hot path, so it is SOURCED, never invoked through
#         rhx. measured: `rhx <skill>` costs ~638 ms of node boot, 72x
#         the 8.8 ms lookup and 6x the 100 ms perceptual threshold. a
#         keystroke cannot pay that. the rhx skills next door
#         (emoji.index.set, emoji.get) serve build + test, not the
#         keystroke path.
#
# usage:
#   source .agent/repo=.this/role=any/skills/emoji.widget.zsh
#
#   :turt<TAB>    -> 🐢     inline, at the cursor, silent on a unique hit
#   :happ<TAB>    -> fzf picker, inserts inline on select
#   :zap:         -> ⚡     the closing colon commits, no TAB needed
#   :zap<Enter>   -> runs `emoji zap`  (':' prefixes the emoji command)
#   emoji         -> fzf over the whole index -> stdout + clipboard
#   emoji rocket  -> 🚀 to stdout, pipe-safe
#
# .trigger = the word under the cursor must MATCH '^:[a-z0-9_+-]+$'.
#            it must BEGIN with the colon, not merely contain one.
#            measured over 20,499 commands of real history: 66 contain
#            a colon, 0 begin a word with one. `npm run test:unit`,
#            `git@github.com:x`, `arn:aws:s3` and `scp host:path` all
#            keep their colon mid-word, so none can fire.
#            ⚠️ relax MATCH to CONTAINS and all 66 become collisions.
#
# .undo = unset -f emoji
#         bindkey '^I' $_EMOJI_PRIOR_TAB
#         bindkey '^M' $_EMOJI_PRIOR_ACCEPT
#         bindkey ':' self-insert
######################################################################

EMOJI_INDEX="${EMOJI_INDEX:-${XDG_DATA_HOME:-$HOME/.local/share}/emoji/emoji.tsv}"

if [[ ! -s $EMOJI_INDEX ]]; then
  print -u2 "✋ no emoji index at $EMOJI_INDEX"
  print -u2 "   run: rhx emoji.index.set"
  return 1
fi

######################################################################
# lookup — index()/substr() only, never a regex on what the human typed
# same rank order as the emoji.get skill; kept in-shell to save a fork
#
# .perf = ONE awk process, and this is the line that matters most —
#         it runs per TAB press. the obvious `awk | sort | cut` costs 3
#         forks; awk buckets by rank and emits in order at END instead.
#         stable within a rank, so CLDR order still breaks ties.
######################################################################
_emoji_lookup() {
  awk -F'\t' -v q="${1:l}" '
    {
      name = tolower($2); kw = tolower($3); rank = 0
      if      (name == q)                                rank = 1
      else if (index(" " kw " ", " " q " ") > 0)         rank = 2
      else if (substr(name, 1, length(q)) == q)          rank = 3
      else if (index(" " kw, " " q) > 0)                 rank = 4
      else if (index(name, q) > 0 || index(kw, q) > 0)   rank = 5
      if (rank) { c[rank]++; o[rank, c[rank]] = $1 "\t" $2 "\t" $3 }
    }
    END {
      for (r = 1; r <= 5; r++)
        for (i = 1; i <= c[r]; i++)
          print o[r, i]
    }
  ' "$EMOJI_INDEX"
}

_emoji_pick() {
  fzf --prompt="${1:-emoji}> " --height=40% --reverse \
      --delimiter='\t' --with-nth=1,2,3 --no-hscroll | cut -f1
}

_emoji_clip() {
  # kitten clipboard — wl-copy is absent on this box, and tmux.conf
  # already carries allow-passthrough + set-clipboard
  command -v kitten >/dev/null && print -rn -- "$1" | kitten clipboard 2>/dev/null
}

######################################################################
# the command
######################################################################
emoji() {
  local pick_forced=0 query="" a
  for a in "$@"; do
    case $a in
      --pick) pick_forced=1 ;;
      *) query="$a" ;;
    esac
  done

  local choice
  if [[ -z $query ]]; then
    choice=$(_emoji_pick emoji < "$EMOJI_INDEX")
  else
    local hits; hits=$(_emoji_lookup "$query")
    if [[ -z $hits ]]; then
      print -u2 "✋ no emoji for '$query'"
      return 2
    fi
    local -a lines; lines=("${(@f)hits}")
    if (( pick_forced || ${#lines} > 1 )) && [[ -t 1 ]]; then
      choice=$(printf '%s\n' "${lines[@]}" | _emoji_pick "emoji $query")
    else
      choice=${lines[1]%%$'\t'*}
    fi
  fi

  [[ -z $choice ]] && return 1
  print -rn -- "$choice"
  [[ -t 1 ]] && print ""        # newline for humans only; pipes stay clean
  _emoji_clip "$choice"
}

######################################################################
# key bindings — interactive shells only
#
# .why guard = zle and bindkey exist only in an interactive zsh. without
#      this, any non-interactive `source emoji.zsh` errors out. that in
#      turn is what lets other callers (emoji.get, the test suite) reuse
#      `_emoji_lookup` from here rather than restate the 5 ranks —
#      one implementation, so TAB and the command cannot disagree.
######################################################################
# `$+functions[zle]` covers the test harness, which stubs zle/bindkey as
# functions to drive the widgets headlessly. without that clause the
# guard would hide the very code the tests exist to check.
if [[ -o interactive ]] || (( $+functions[zle] )); then

# chain to whatever TAB was bound to BEFORE us — never a guessed default.
# guarded so a re-source cannot capture our own widget and self-loop.
if [[ -z ${_EMOJI_PRIOR_TAB:-} ]]; then
  _EMOJI_PRIOR_TAB=$(bindkey '^I' 2>/dev/null | awk '{print $2}')
  if [[ -z $_EMOJI_PRIOR_TAB || $_EMOJI_PRIOR_TAB == (_emoji_tab|undefined-key) ]]; then
    _EMOJI_PRIOR_TAB=expand-or-complete
  fi
fi

_emoji_tab() {
  local word=${LBUFFER##* }

  # the anchor. MATCH, not contains. this line is what buys 0/20,499.
  if [[ $word =~ '^:[a-zA-Z0-9_+-]+$' ]]; then
    local hits; hits=$(_emoji_lookup "${word#:}")

    if [[ -n $hits ]]; then
      local -a lines; lines=("${(@f)hits}")
      local choice

      if (( ${#lines} == 1 )); then
        choice=${lines[1]%%$'\t'*}
      else
        zle -I
        choice=$(printf '%s\n' "${lines[@]}" | _emoji_pick "emoji ${word}")
        zle reset-prompt
      fi

      # %"$word" — quoted so the removal is literal. unquoted, zsh reads
      # the word as a pattern and '+' or '^' in it would mis-strip.
      [[ -n $choice ]] && LBUFFER="${LBUFFER%"$word"}$choice"
      return 0
    fi
  fi

  # every other tab falls through, untouched
  zle "$_EMOJI_PRIOR_TAB"
}

zle -N _emoji_tab
bindkey '^I' _emoji_tab

######################################################################
# gesture 2 — the closing colon: ':zap:' swaps the instant you type it
#
# slack/github muscle memory. no TAB needed; the second colon IS the
# commit. fires only when the word under the cursor already matches
# '^:word$', so the colon you type is closing one you opened.
#
# .safe = every mid-word colon falls through to a literal ':'
#         'arn:aws:s3'  -> at each colon the word is 'arn' / 'arn:aws',
#                          neither begins with ':'
#         'test:unit'   -> word is 'test'
#         'http://'     -> word is 'http'
#         '::'          -> word is ':', and the pattern needs 1+ chars
#                          after the colon
# .paste = zsh routes pastes through `bracketed-paste`, not self-insert,
#          so pasted text with colons never triggers this.
######################################################################
_emoji_colon() {
  local word=${LBUFFER##* }

  if [[ $word =~ '^:[a-zA-Z0-9_+-]+$' ]]; then
    local hits; hits=$(_emoji_lookup "${word#:}")

    if [[ -n $hits ]]; then
      # decisive on purpose: the closing colon means the human committed
      # to a name, so take the top rank rather than open a picker.
      local choice=${${hits%%$'\n'*}%%$'\t'*}
      LBUFFER="${LBUFFER%"$word"}$choice"
      return 0
    fi
  fi

  # not a closing colon, or no such emoji — type a literal ':'
  zle self-insert
}

zle -N _emoji_colon
bindkey ':' _emoji_colon

######################################################################
# gesture 3 — ':' as a command prefix: ':zap<Enter>' runs `emoji zap`
#
# rewrites the buffer to the real command before it accepts, so history
# records `emoji zap` — honest, re-runnable, and greppable.
#
# .safe = only when the WHOLE buffer is ':word' AND that word finds an
#         emoji. otherwise the line executes exactly as it does today.
#         ':qa!'  -> '!' is outside the charset, so no match  (this is
#                    real: 8 such vim-reflex typos in the history)
#         ':qa'   -> matches the shape, but finds no emoji, so it falls
#                    through to the usual 'command not found'
#         ':'     -> the zsh no-op builtin, untouched
######################################################################
if [[ -z ${_EMOJI_PRIOR_ACCEPT:-} ]]; then
  _EMOJI_PRIOR_ACCEPT=$(bindkey '^M' 2>/dev/null | awk '{print $2}')
  if [[ -z $_EMOJI_PRIOR_ACCEPT || $_EMOJI_PRIOR_ACCEPT == (_emoji_accept|undefined-key) ]]; then
    _EMOJI_PRIOR_ACCEPT=accept-line
  fi
fi

_emoji_accept() {
  if [[ $BUFFER =~ '^:[a-zA-Z0-9_+-]+$' ]]; then
    local q=${BUFFER#:}
    if [[ -n $(_emoji_lookup "$q") ]]; then
      BUFFER="emoji $q"
      CURSOR=$#BUFFER
    fi
  fi
  zle "$_EMOJI_PRIOR_ACCEPT"
}

zle -N _emoji_accept
bindkey '^M' _emoji_accept

print "🐢 emoji loaded"
print "   ├─ index : $EMOJI_INDEX ($(wc -l < $EMOJI_INDEX) emoji)"
print "   ├─ tab   : falls through to '$_EMOJI_PRIOR_TAB'"
print "   ├─ enter : falls through to '$_EMOJI_PRIOR_ACCEPT'"
print "   └─ try   : ':turt<TAB>'  ':zap:'  ':zap<Enter>'  'emoji rocket'"

fi  # end interactive-only bindings
