#!/usr/bin/env bash
######################################################################
# .what = copy the checkout's widget to ~/.zshrc.emoji.sh
#
# .why a COPY and not a symlink
#   - every config artifact in this repo is copied
#   - ⇒ a `configure.verify` can `cmp` the live file against the checkout
#   - a symlink makes that check vacuous
#   - it would compare a file to itself and pass on every box (`repo.overview.md`)
#
# ⚠️ .why it does NOT go in ~/.bash_aliases
#   - the widget calls `zle` and `bindkey`, which exist in zsh alone
#   - `~/.bash_aliases` is reached by BASH_ENV, so bash sources it non-interactively
#   - ⇒ those two builtins are absent there and every line would error
#   - `src/zshrc.sh` sources this copy after compinit and after fzf
#   - ⇒ our TAB bind lands last
#
# .the seam this bundle does NOT own
#   - the SOURCE LINE lives in `src/zshrc.sh`, which `2.5.zsh` owns
#   - one artifact, one writer (`rule.forbid.two-writers-on-one-artifact`)
#   - the line is guarded by `[[ -f ~/.zshrc.emoji.sh ]]`
#   - ⇒ a grove declines this bundle, sources no widget, and reports no fault
#
# guarantee:
#   - idempotent: a copy that already matches the checkout does no work
######################################################################

grove_provision_2_9_emoji_configure_upsert() {
  local src="$GROVE_SRC/grove.provision/2.shell/2.9.emoji/emoji.zsh"
  local dst="$HOME/.zshrc.emoji.sh"

  if [[ ! -f "$src" ]]; then
    echo "   ✋ the checkout holds no emoji.zsh at $src" >&2
    echo '      ⇒ this seat holds a partial checkout. a push --from src carries' >&2
    echo '        all of src/, so an absent file here means the push predates' >&2
    echo '        this bundle — push again from the current checkout' >&2
    return 1
  fi

  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    echo "   • emoji widget already matches the checkout ✔"
    return 0
  fi

  cp "$src" "$dst"
  echo "   • emoji widget copied to ~/.zshrc.emoji.sh"
}
