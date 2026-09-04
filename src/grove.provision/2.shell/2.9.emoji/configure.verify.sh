#!/usr/bin/env bash
######################################################################
# .what = prove the live widget MATCHES the checkout, and its three gestures behave
#
# 🛑 a `cmp` alone is NOT enough here, though it is for every other config artifact
#   - a tmux.conf that matches the checkout is a tmux.conf that works
#   - this file REBINDS TAB, ENTER and ':' — three of the most reflexive keys
#   - ⇒ a regression feels like the shell itself broke
#   - it has no obvious culprit and no error to grep
#   - ⇒ this verify runs the widget's own 20-case suite
#   - `cmp` proves the bytes arrived
#   - the suite proves the bytes still do their job
#   - above all it proves every NON-emoji keystroke falls through
#   - (`arn:aws:`, `npm run test:unit`, `:qa!`)
#
# ⚠️ the suite runs against the CHECKOUT's widget, not the live copy
#   - `cmp` has already proven the two are byte-identical here
#   - ⇒ they cannot disagree
#   - the checkout is the file a human can edit and re-run by hand
#
# .why it is bounded
#   - the suite stubs `zle` and calls the widget functions directly
#   - it has no pty, no sleep, and no wire
#   - ⇒ 20 in-process assertions over one flat file
#   - the bound is generous against that cost
#   - (`rule.require.bounded-probes-in-verifies`)
######################################################################

grove_provision_2_9_emoji_configure_verify() {
  local bundle_dir="$GROVE_SRC/grove.provision/2.shell/2.9.emoji"
  local src="$bundle_dir/emoji.zsh"
  local dst="$HOME/.zshrc.emoji.sh"
  local suite="$bundle_dir/emoji.test.zsh"
  local index out rc=0

  if [[ ! -f "$dst" ]]; then
    echo "   ✋ no emoji widget at ~/.zshrc.emoji.sh" >&2
    echo "      fix: grove.provision --what 2.9.emoji --mode apply" >&2
    return 1
  fi

  if ! cmp -s "$src" "$dst"; then
    echo "   ✋ ~/.zshrc.emoji.sh DIFFERS from the checkout" >&2
    echo "      read why: diff $src $dst" >&2
    echo "      fix: grove.provision --what 2.9.emoji --mode apply" >&2
    return 1
  fi

  ####################################################################
  # the widget needs a zsh AND an index
  #   - both are this bundle's own work
  #   - ⇒ an absence here is a real fault rather than a skip
  ####################################################################
  if ! command -v zsh >/dev/null 2>&1; then
    echo "   ✋ zsh is absent, so the widget's gestures cannot be exercised" >&2
    echo "      fix: grove.provision --what 2.5.zsh --mode apply" >&2
    return 1
  fi

  index="$(grove_provision_2_9_emoji_index_path)"
  if [[ ! -s "$index" ]]; then
    echo "   ✋ no emoji index, so the suite would test a widget that returns early" >&2
    echo "      ⇒ that would be a PASS over a widget nobody exercised, which is" >&2
    echo "        worse than a fail (rule.forbid.failhide)" >&2
    echo "      fix: grove.provision --what 2.9.emoji --mode apply" >&2
    return 1
  fi

  ####################################################################
  # ⚠️ the bound is a TOTAL and a KILL
  #   - a `timeout` with no `-k` sends TERM and waits forever if the child ignores it
  #   - ⇒ that is a request rather than a bound
  #   - (`prove.timeouts-kill-what-they-cut`)
  ####################################################################
  out="$(EMOJI_INDEX="$index" timeout -k 5 60 zsh "$suite" 2>&1)" || rc=$?

  if [[ $rc -eq 124 || $rc -eq 137 ]]; then
    echo "   ✋ the emoji gesture suite did not finish within 60s" >&2
    echo "      ⇒ it stubs zle and reaches no pty and no wire, so a stall there" >&2
    echo "        is a defect in the suite, never a slow box" >&2
    return 1
  fi

  if [[ $rc -ne 0 ]]; then
    echo "   ✋ the emoji widget failed its own gesture suite" >&2
    printf '%s\n' "$out" | grep -E '⛔|buffer want|zle    want' >&2 || true
    echo "      read it all: EMOJI_INDEX=$index zsh $suite" >&2
    return 1
  fi

  echo "   • emoji widget matches the checkout, and all gestures hold ✔"
}
